`include "headers.v"
module d_IBF_Decoding (input clk, reset, Start, input Wr, input [`CellSize-1: 0] IBF_Row, input [`IndexSize:0] Addr, 
			output reg wrDone, output wire Done, output wire [`SetLen-1:0] decodedNum);

reg [`CellSize-1:0] IBF [0: `IBFSize-1];

reg pureListupDone;

parameter S0 = 0, S1 = 1;
reg state, nextState;
reg IBF_Load, pureListDecoding;
wire pureListEmpty;
reg IBF_Empty;

wire [`CRCLength-1:0] CRC_code;
wire pureDone;
integer i;
wire [`CellSize-1:0] currentCell;
reg preStart;
wire crcStart;
wire [`KeyField-1:0] Key;
wire [`SigField-1:0] sigField, inSig;
wire [`CountField-1:0] countField, h1_count, h2_count;

reg [0:`IBFSize-1] pureList, pureListPre;
reg [`IndexSize-1:0] pureIndex;
wire [`IndexSize-1:0] h1_index, h2_index, h3_index;
wire cellSkip, fakePure, sigEqual;

//reg [`KeyField:0] decodedList [0: `SetSize-`Set2Size-1] ;
reg [`KeyField:0] decodedList [0: `S1Distinct+`S2Distinct-1] ;
reg [`SetLen-1:0] decodeIndex;

CRCgenerator CRC (clk, reset, crcStart, Key, crcDone, CRC_code);


assign Done = pureDone;
assign decodedNum = (Done) ? decodeIndex: 0;

//Load IBF
always @(posedge clk) begin
	if (reset) wrDone <= 0;
	else if ((IBF_Load) & (Wr) & (Addr <`IBFSize)) begin
		IBF[Addr] <= IBF_Row; wrDone <= 0; 
	end
	if (Wr & (Addr ==`IBFSize-1) ) wrDone <= 1;
	else wrDone <= 0;
end


always @(posedge clk) 
	if (reset) state <= S0;
	else state <= nextState;

always @(*) begin
	case (state)
	S0: begin //IBF Load
		IBF_Load = 1; 
		pureListDecoding = 0;
		if (wrDone) nextState = S1; 
		else nextState = S0; 
	end 
	S1: begin //Decoding in pureList
		IBF_Load = 0; 
		pureListDecoding = 1;
		if (pureDone) nextState = S0;
		else nextState = S1;
	end 
	default: begin
		IBF_Load = 0; 
		pureListDecoding = 0;
	end
	endcase
end
	
assign pureListEmpty = ~|pureList; 
always @(*) begin
	if (pureDone) 
		 for (i=0;i<`IBFSize; i=i+1) IBF_Empty = (IBF[i] == 'b0) ? 1: 0;
	else IBF_Empty = 0;
end

assign pureDone = (pureListDecoding & pureListEmpty ) ? 1: 0;

assign h1_index = (pureListDecoding & crcDone) ? CRC_code[`CRCLength-1: `CRCLength-`IndexSize] : 'bz;
assign h2_index = (pureListDecoding & crcDone) ? CRC_code[`CRCLength-`IndexSize-1: `CRCLength-`IndexSize-`IndexSize] : 'bz;
assign h3_index = (pureListDecoding & crcDone) ? CRC_code[`IndexSize-1: 0]: 'bz;


always @(posedge clk) 
	if (reset) pureListupDone <= 0; 
	else if (wrDone) pureListupDone <= 1;
	else pureListupDone <= 0;

always @(posedge clk) begin
	if (reset) pureIndex <= 0;
	else if (pureListDecoding & crcDone) pureIndex <= pureIndex + 1;
	if (pureListDecoding & !pureList[pureIndex]) pureIndex <= pureIndex + 1; //non-pure cells are skiped
end

assign fakePure = (pureListDecoding & crcDone & 
	(!sigEqual | ((pureIndex != h1_index) & (pureIndex != h2_index) & (pureIndex != h3_index)) )) ? 1'b1: 1'b0;
assign cellSkip = (!pureList[pureIndex] | fakePure) ? 1: 0;



//fill an entry to the decodedList 
always @(posedge clk) 
	if (reset) decodeIndex <= 0; 
	else if (wrDone) decodeIndex <= 0;
	else if (pureListDecoding & crcDone & !fakePure) decodeIndex <= decodeIndex+1;

always @(posedge clk) begin
	if (reset) for (i=0;i<`SetSize; i=i+1) decodedList[i] <= 0;
	else if (pureListDecoding & crcDone & !fakePure) begin
		decodedList[decodeIndex] <= {1'b1, Key};
	end
end


//crcStart generation
always @(posedge clk) begin
	if (reset) preStart <= 0; 
	//else if (pureListDecoding & !pureListEmpty & pureList[pureIndex+1] & (pureListupDone | crcDone | cellSkip)) 
	else if (pureListDecoding & !pureListEmpty & (pureListupDone | crcDone | cellSkip)) 
		preStart <= 1;
	else preStart <= 0;
end

assign crcStart = preStart & !cellSkip;

//parsing the current cell of pureIndex
assign currentCell = (pureListDecoding) ? IBF[pureIndex]: 'b0;
assign Key = (pureListDecoding & pureList[pureIndex]) ? currentCell[`CellSize-1:`CellSize-`KeyField] : 'b0;
assign sigField = IBF[pureIndex][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ];
assign countField = (pureListDecoding & pureList[pureIndex]) ? 
			currentCell[`CellSize-`KeyField-`SigField-1:`CellSize-`KeyField-`SigField-`CountField] : 'b0;

assign inSig = (pureListDecoding & crcDone) ? CRC_code[`CRCLength-`IndexSize-1: `CRCLength-`IndexSize-`SigField]: 'bz;
assign sigEqual = (pureListDecoding & crcDone & (inSig == sigField) ) ? 1'b1: 1'b0;
	

//pure list generation, reset the current entry and set the new one
always @(*) begin
	if (crcDone & !pureDone) begin
	     if (!fakePure) begin
		pureListPre[pureIndex] = 0;	             
		case(pureIndex)
		h1_index: begin //if the same indexes are generated.
		   if (h2_index == h3_index) begin
			if (IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 3) 
				pureListPre[h2_index] = 1;
		        else if (IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 2) 
				pureListPre[h2_index] = 0;
			else pureListPre[h2_index] = pureList[h2_index];
		   end
		   else begin //at the last pure cell processing, in case if two pure cells are decoded at the same time
			if (IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 2)
				pureListPre[h2_index] = 1;
			else if (IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 1)
				pureListPre[h2_index] = 0;
			else if ( (IBF[h2_index][`CellSize-1:`CellSize-`KeyField] != 0 ) & // if count field is 0, then should be set 
				(IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 0) )
				pureListPre[h2_index] = 1; 
			else  pureListPre[h2_index] = pureList[h2_index];

			if (IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 2)
				pureListPre[h3_index] = 1;
			else if (IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 1)
				pureListPre[h3_index] = 0;
			else if ( (IBF[h3_index][`CellSize-1:`CellSize-`KeyField] != 0 ) & 
				(IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 0) )
				pureListPre[h3_index] = 1;
			else pureListPre[h3_index] = pureList[h3_index];
		   end
		end
		h2_index: begin 
 		   if (h1_index == h3_index) begin
			if (IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 3) 
				pureListPre[h1_index] = 1;
		        else if (IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 2) 
				pureListPre[h1_index] = 0;
			else pureListPre[h1_index] = pureList[h1_index];
		   end
		   else begin
			if (IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 2)
				pureListPre[h1_index] = 1;
			else if (IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 1) 
				pureListPre[h1_index] = 0;
			else if ( (IBF[h1_index][`CellSize-1:`CellSize-`KeyField] != 0 ) &
				(IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 0) )
				pureListPre[h1_index] = 1;
			else pureListPre[h1_index] = pureList[h1_index];

			if (IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 2)
				pureListPre[h3_index] = 1;
			else if (IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 1)
				pureListPre[h3_index] = 0;
			else if ( (IBF[h3_index][`CellSize-1:`CellSize-`KeyField] != 0 ) &
				(IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 0))
				pureListPre[h3_index] = 1;
			else pureListPre[h3_index] = pureList[h3_index];
		   end
		end
		h3_index: begin 
		   if (h1_index == h2_index) begin
			if (IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 3) 
				pureListPre[h1_index] = 1;
		        else if (IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 2) 
				pureListPre[h1_index] = 0;
			else pureListPre[h1_index] = pureList[h1_index];
		   end
		   else begin			
			if (IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 2)
				pureListPre[h1_index] = 1;
			else if (IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 1) 
				pureListPre[h1_index] = 0;
			else if ( (IBF[h1_index][`CellSize-1:`CellSize-`KeyField] != 0 ) &
				(IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 0) )
				pureListPre[h1_index] = 1;
			else  pureListPre[h1_index] = pureList[h1_index];

			if (IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 2)
				pureListPre[h2_index] = 1;
			else if (IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 1)
				pureListPre[h2_index] = 0;
			else if ( (IBF[h2_index][`CellSize-1:`CellSize-`KeyField] != 0 ) &
				(IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 0) )
				pureListPre[h2_index] = 1;
			else pureListPre[h2_index] = pureList[h2_index];
		   end
		end
		//default: pureListPre[pureIndex] = 0;
		endcase
	   end
	   else pureListPre[pureIndex] = 0;
	end
	else pureListPre = pureList;
end

always @(posedge clk) begin
	if (reset) begin 
		pureList <= 'b0; 
	end
	else if (wrDone) begin
		for (i=0;i<`IBFSize; i=i+1) //initial pure list
			if (IBF[i][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] == 1) 
				pureList[i] <= 1;
			else pureList[i] <= 0;
	end
	else if (crcDone & !pureDone) pureList <= pureListPre; //new generated pure cells during decoding
end

//IBF processing. Since indexes could be the same, the following processing should be performed sequentially. Hence, blocking assignment is used	
always @(posedge clk) begin
	if (crcDone & !pureDone & !fakePure) begin
		IBF[h1_index][`CellSize-1:`CellSize-`KeyField] = IBF[h1_index][`CellSize-1:`CellSize-`KeyField] ^ Key;
		IBF[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] 
			= IBF[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ]^ inSig;

		// count field in d-IBF could be 0, if the number of elements is the same in two IBFs.
		if (IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] > 0) 
		IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] - 1;
		else 
		IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] + 1;
		

		IBF[h2_index][`CellSize-1:`CellSize-`KeyField] = IBF[h2_index][`CellSize-1:`CellSize-`KeyField] ^ Key; 
		IBF[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] 
			= IBF[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ]^ inSig;

		if (IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] > 0)
		IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] - 1;
		else 
		IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] + 1;
		

		IBF[h3_index][`CellSize-1:`CellSize-`KeyField] = IBF[h3_index][`CellSize-1:`CellSize-`KeyField] ^ Key; 
		IBF[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] 
			= IBF[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ]^ inSig;

		if (IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] > 0)
		IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] - 1;
		else begin //If it was 0, should be increased
		IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] + 1;
		$display ("time = %d, IBF[%d] = %d," , $time, h3_index, 
			IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField]);
		end
	end
end

integer result1 = 0, result2 = 0;
always @(posedge pureDone) begin
	result1 = $fopen ("IBF_Left.txt");
	result2 = $fopen ("decodedList.txt");
	for (i=0; i<`IBFSize; i=i+1) $fdisplay (result1, "IBF[%d] = %b", i, IBF[i]);
	//for (i=0; i<`SetSize-`Set2Size; i=i+1)  $fdisplay (result2, "decodedList[%d] = %b", i, decodedList[i] );
	for (i=0; i<decodeIndex; i=i+1)  $fdisplay (result2, "decodedList[%d] = %b", i, decodedList[i] );
end
	
endmodule
