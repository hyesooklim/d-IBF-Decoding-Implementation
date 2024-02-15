//Written by prof. Hyesook Lim at Ewha Womans University (2023.01).
//This code decodes the d-IBF with the conventional method.
//The conventional method has no consideration about T1 or T2 cases, and hence generates many composite keys, which composed of many elements.
//In order to properly use this design, a directory named "result_conv" should exist in the current simulation directory.
//Result files for experimentA or experiment B will be made in the result_conv directory.


`include "headers.v"
module d_IBF_conv_decoding (input clk, reset, Start, input Wr, input [`CellSize-1: 0] IBF_Row, input [`IndexSize:0] Addr, 
			output reg wrDone, output reg allDone, output wire [`SetLen-1:0] decodedNum, 
			output reg [15:0] sigNotEqualCount, T1CaseCount );

reg [`CellSize-1:0] IBF [0: `IBFSize-1];
reg [`CellSize-1:0] IBF_comb [0: `IBFSize-1];

reg pureListupDone;

parameter S0 = 0, S1 = 1;
reg state, nextState;
reg IBF_Load, pureListDecoding;
wire pureListEmpty;
reg IBF_Empty;

wire [`CRCLength-1:0] CRC_code;
reg Done;
wire pureDone;
integer i;
wire [`CellSize-1:0] currentCell;
reg preStart;
wire crcStart;
wire [`KeyField-1:0] Key, h1_key, h2_key, h3_key;
wire [`SigField-1:0] sigField, inSig, h1_sig, h2_sig, h3_sig;
wire sigNotEqual;
wire [`CountField-1:0] countField, h1_count, h2_count, h3_count;

reg [0:`IBFSize-1] pureList, pureListPre;
reg [`IndexSize-1:0] pureIndex;
wire [`IndexSize-1:0] h1_index, h2_index, h3_index;
wire cellSkip, fakePure;
reg [`KeyField:0] decodedList [1: `DecodeMax] ;
reg [`SetLen-1:0] decodeIndex; 


CRCgenerator CRC (clk, reset, crcStart, Key, crcDone, CRC_code);

always @(posedge clk)
	if (reset) Done <= 1'b0;
	else Done <= pureDone;

always @(posedge clk)
	if (reset) allDone <= 1'b0;
	else allDone <= Done;

assign decodedNum = (decodeIndex-1);


//IBF processing
always @(posedge clk) begin
	if (reset) wrDone <= 0;
	else if ((IBF_Load) & (Wr)) begin
		if (Addr <`IBFSize) begin 
			IBF[Addr] <= IBF_Row; 
			wrDone <= 0; 
		end
		else if (Addr ==`IBFSize)  wrDone <= 1;
	end
	else begin 
		wrDone <= 0;
		if (crcDone & !pureDone & !fakePure) begin
			IBF[h1_index] <= IBF_comb[h1_index];
			IBF[h2_index] <= IBF_comb[h2_index];
			IBF[h3_index] <= IBF_comb[h3_index];
		end
	end
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
assign h1_index = (pureListDecoding & crcDone) ? CRC_code[`CRCLength-1: `CRCLength-`IndexSize] % `IBFSize : 'bz;
assign h2_index = (pureListDecoding & crcDone) ? CRC_code[`CRCLength-`NextIndexStart-1: `CRCLength-`NextIndexStart-`IndexSize] % `IBFSize  : 'bz;
assign h3_index = (pureListDecoding & crcDone) ? CRC_code[`IndexSize-1: 0]  % `IBFSize : 'bz;


always @(posedge clk) 
	if (reset) pureListupDone <= 0; 
	else if (wrDone) pureListupDone <= 1;
	else pureListupDone <= 0;

always @(posedge clk) begin
	if (reset) pureIndex <= 0;
	else if (pureListDecoding & crcDone) pureIndex <= (pureIndex + 1)  % `IBFSize;
	if (pureListDecoding & !pureList[pureIndex]) pureIndex <= (pureIndex + 1) % `IBFSize; //non-pure cells are skiped
end

assign T1Case = (pureListDecoding & crcDone & 
	((pureIndex != h1_index) & (pureIndex != h2_index) & (pureIndex != h3_index)) ) ? 1'b1: 1'b0;

always @(posedge clk)
	if (reset) T1CaseCount <= 0;
	else if (T1Case) T1CaseCount <= T1CaseCount + 1;

always @(posedge clk)
	if (reset) sigNotEqualCount <= 0;
	else if (sigNotEqual) sigNotEqualCount <= sigNotEqualCount + 1;

assign sigNotEqual = (pureListDecoding & crcDone & (inSig != sigField) ) ? 1'b1: 1'b0;

assign fakePure = sigNotEqual;
assign cellSkip = (!pureList[pureIndex] | fakePure) ? 1: 0;

//fill an entry to the decodedList 
always @(posedge clk) 
	if (reset) decodeIndex <= 1; 
	else if (wrDone) decodeIndex <= 1;
	else if (pureListDecoding & crcDone & !fakePure) decodeIndex <= decodeIndex+1;

//Type2Error is identified if the same Key is already decoded in the decoded list. 
//In this case, the two same keys became invalid by setting the first bit with 0 
/*
always @(posedge clk)
	if (reset) begin T2ErrorNow <= 0; T2ErrorCount <= 0; end
	else if (pureListDecoding & crcDone & !fakePure) 
		for (i=1; i<(decodeIndex + 1); i=i+1) if (decodedList[i] == {1'b1, Key})  begin
							T2ErrorNow[decodeIndex] = 1'b1; T2ErrorCount <= T2ErrorCount + 1; 
						      end

always @(posedge clk) 
	if (reset) T2ErrorPre <= 'b0; 
	else if (pureListDecoding & crcDone & !fakePure) 
		for (i=1; i<(decodeIndex + 1); i=i+1) if (decodedList[i] == {1'b1, Key}) T2ErrorPre[i] = 1'b1; 

assign T2ErrorList = T2ErrorPre | T2ErrorNow;
*/

always @(posedge clk) begin
	if (reset) for (i=1;i<`DecodeMax; i=i+1) decodedList[i] <= 0;
	else if (pureListDecoding & crcDone & !fakePure) decodedList[decodeIndex] <= {1'b1, Key};
end

//crcStart generation
always @(posedge clk) begin
	if (reset) preStart <= 0; 
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

	
//pure list generation, reset the current entry after processing and set the new one
always @(*) begin
	if (crcDone & !pureDone) begin
	     if (!fakePure) begin
		pureListPre[pureIndex] = 0;	             
		case(pureIndex)
		h1_index: begin //if the same indexes are generated.
		   if (h2_index == h3_index) begin
			if (h2_count == 3) 
				pureListPre[h2_index] = 1;
		        else if (h2_count == 2) 
				pureListPre[h2_index] = 0;
			else pureListPre[h2_index] = pureList[h2_index];
		   end
		   else begin //at the last pure cell processing, in case if two pure cells are decoded at the same time
			if (h2_count == 2)
				pureListPre[h2_index] = 1;
			else if (h2_count == 1)
				pureListPre[h2_index] = 0;
			else if ( (IBF[h2_index][`CellSize-1:`CellSize-`KeyField] != 0 ) & // if count field is 0, then should be set 
				(h2_count == 0) )
				pureListPre[h2_index] = 1; 
			else  pureListPre[h2_index] = pureList[h2_index];

			if (h3_count == 2)
				pureListPre[h3_index] = 1;
			else if (h3_count == 1)
				pureListPre[h3_index] = 0;
			else if ( (IBF[h3_index][`CellSize-1:`CellSize-`KeyField] != 0 ) & (h3_count == 0) )
				pureListPre[h3_index] = 1;
			else pureListPre[h3_index] = pureList[h3_index];
		   end
		end
		h2_index: begin 
 		   if (h1_index == h3_index) begin
			if (h1_count == 3) 
				pureListPre[h1_index] = 1;
		        else if (h1_count == 2) 
				pureListPre[h1_index] = 0;
			else pureListPre[h1_index] = pureList[h1_index];
		   end
		   else begin
			if (h1_count == 2)
				pureListPre[h1_index] = 1;
			else if (h1_count == 1) 
				pureListPre[h1_index] = 0;
			else if ( (IBF[h1_index][`CellSize-1:`CellSize-`KeyField] != 0 ) & (h1_count == 0) )
				pureListPre[h1_index] = 1;
			else pureListPre[h1_index] = pureList[h1_index];

			if (h3_count == 2)
				pureListPre[h3_index] = 1;
			else if (h3_count == 1)
				pureListPre[h3_index] = 0;
			else if ( (IBF[h3_index][`CellSize-1:`CellSize-`KeyField] != 0 ) & (h3_count == 0))
				pureListPre[h3_index] = 1;
			else pureListPre[h3_index] = pureList[h3_index];
		   end
		end
		h3_index: begin 
		   if (h1_index == h2_index) begin
			if (h1_count == 3) 
				pureListPre[h1_index] = 1;
		        else if (h1_count == 2) 
				pureListPre[h1_index] = 0;
			else pureListPre[h1_index] = pureList[h1_index];
		   end
		   else begin			
			if (h1_count == 2)
				pureListPre[h1_index] = 1;
			else if (h1_count == 1) 
				pureListPre[h1_index] = 0;
			else if ( (IBF[h1_index][`CellSize-1:`CellSize-`KeyField] != 0 ) &(h1_count == 0) )
				pureListPre[h1_index] = 1;
			else  pureListPre[h1_index] = pureList[h1_index];

			if (h2_count == 2)
				pureListPre[h2_index] = 1;
			else if (h2_count == 1)
				pureListPre[h2_index] = 0;
			else if ( (IBF[h2_index][`CellSize-1:`CellSize-`KeyField] != 0 ) & (h2_count == 0) )
				pureListPre[h2_index] = 1;
			else pureListPre[h2_index] = pureList[h2_index];
		   end
		end
		default: pureListPre[pureIndex] = 0; 
		//if pureIndex is not equal to any of h_indexes, then should be reset. Otherwise, simulation never stop.
		endcase
	   end
	   else pureListPre[pureIndex] = 0; //if pureIndex is fakePure, then should be reset. Otherwise, simulation never stop.
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

//parsing each field in IBF
assign h1_key = (crcDone & !pureDone & !fakePure) ? IBF[h1_index][`CellSize-1:`CellSize-`KeyField]:'bz;
assign h2_key = (crcDone & !pureDone & !fakePure) ? IBF[h2_index][`CellSize-1:`CellSize-`KeyField]:'bz;
assign h3_key = (crcDone & !pureDone & !fakePure) ? IBF[h3_index][`CellSize-1:`CellSize-`KeyField]:'bz;

assign h1_sig = (crcDone & !pureDone & !fakePure) ? IBF[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField]:'bz;
assign h2_sig = (crcDone & !pureDone & !fakePure) ? IBF[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField]:'bz;
assign h3_sig = (crcDone & !pureDone & !fakePure) ? IBF[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField]:'bz;

assign h1_count = (crcDone & !pureDone & !fakePure) ? IBF[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField]: 'bz;
assign h2_count = (crcDone & !pureDone & !fakePure) ? IBF[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField]: 'bz;
assign h3_count = (crcDone & !pureDone & !fakePure) ? IBF[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField]: 'bz;

//IBF processing. Since indexes could be the same, 
//the following processing should be performed sequentially in a combinational always block. 
always @(*) begin
	IBF_comb[h1_index] = IBF[h1_index];
	IBF_comb[h2_index] = IBF[h2_index];
	IBF_comb[h3_index] = IBF[h2_index];
	case(pureIndex)
		h1_index: begin 
		    IBF_comb[h1_index][`CellSize-1:`CellSize-`KeyField] = h1_key ^ Key;
	   	    IBF_comb[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] = h1_sig ^ inSig;
	   // count field in d-IBF could be 0, if the number of elements is the same in two IBFs.
	   	    if (h1_count > 0) 
		     	IBF_comb[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h1_count - 1;
	   	    else //If it was 0, should be increased
			 IBF_comb[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h1_count + 1;

		    if (h2_index == h3_index) begin //if the same indexes are generated.
			IBF_comb[h2_index] = IBF[h2_index];
			IBF_comb[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h2_count - 2;
		    end
		    else begin
			IBF_comb[h2_index][`CellSize-1:`CellSize-`KeyField] = h2_key ^ Key; 
	            	IBF_comb[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] = h2_sig ^ inSig;
	            	if (h2_count > 0)
		    		IBF_comb[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h2_count - 1;
	  		else 
				IBF_comb[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h2_count + 1;

	   		IBF_comb[h3_index][`CellSize-1:`CellSize-`KeyField] = h3_key ^ Key; 
	   		IBF_comb[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField] = h3_sig ^ inSig;
	   		if (h3_count > 0)
				IBF_comb[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h3_count - 1;
	  		else 
				IBF_comb[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h3_count + 1;
		    end
		end
		h2_index: begin 
		    IBF_comb[h2_index][`CellSize-1:`CellSize-`KeyField] = h2_key ^ Key;
	   	    IBF_comb[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] = h2_sig ^ inSig;
	   	    if (h2_count > 0) 
		     	IBF_comb[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h2_count - 1;
	   	    else 
			IBF_comb[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h2_count + 1;

		    if (h1_index == h3_index) begin //if the same indexes are generated.
			IBF_comb[h1_index] = IBF[h1_index];
			IBF_comb[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h1_count - 2;
		    end
		    else begin
			IBF_comb[h1_index][`CellSize-1:`CellSize-`KeyField] = h1_key ^ Key; 
	            	IBF_comb[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] = h1_sig ^ inSig;
	            	if (h1_count > 0)
		    		IBF_comb[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h1_count - 1;
	  		else 
				IBF_comb[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h1_count + 1;

	   		IBF_comb[h3_index][`CellSize-1:`CellSize-`KeyField] = h3_key ^ Key; 
	   		IBF_comb[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField] = h3_sig ^ inSig;
	   		if (h3_count > 0)
				IBF_comb[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h3_count - 1;
	  		else 
				IBF_comb[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h3_count + 1;
		    end
		end
		h3_index: begin 
		    IBF_comb[h3_index][`CellSize-1:`CellSize-`KeyField] = h3_key ^ Key;
	   	    IBF_comb[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] = h3_sig ^ inSig;
	   	    if (h3_count > 0) 
		     	IBF_comb[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h3_count - 1;
	   	    else 
			IBF_comb[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h3_count + 1;

		    if (h1_index == h2_index) begin //if the same indexes are generated.
			IBF_comb[h1_index] = IBF[h1_index];
			IBF_comb[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h1_count - 2;
		    end
		    else begin
			IBF_comb[h1_index][`CellSize-1:`CellSize-`KeyField] = h1_key ^ Key; 
	            	IBF_comb[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] = h1_sig ^ inSig;
	            	if (h1_count > 0)
		    		IBF_comb[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h1_count - 1;
	  		else 
				IBF_comb[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h1_count + 1;

	   		IBF_comb[h2_index][`CellSize-1:`CellSize-`KeyField] = h2_key ^ Key; 
	   		IBF_comb[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField] = h2_sig ^ inSig;
	   		if (h2_count > 0)
				IBF_comb[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h2_count - 1;
	  		else  
				IBF_comb[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] = h2_count + 1;

		    end
		end	
	endcase	 
end

integer result1 = 0, result2 = 0;
wire [3:0] fileNo;

assign fileNo = (`IBFSize == 40) ? 1 : (`IBFSize == 60) ? 2: (`IBFSize == 80) ? 3 : (`IBFSize == 100) ? 4 : 
		(`IBFSize == 10000) ? 5 : (`IBFSize == 15000) ? 6: (`IBFSize == 20000) ? 7 : (`IBFSize == 25000) ? 8 : 
		(`IBFSize == 1000) ? 9 : (`IBFSize == 1500) ? 10: (`IBFSize == 2000) ? 11 : (`IBFSize == 2500) ? 12 : 0;

always @(posedge Done) begin

   case (fileNo)
	1: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_40.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_40.txt");
	end
	2: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_60.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_60.txt");
	end
	3: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_80.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_80.txt");
	end
	4: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_100.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_100.txt");
	end
	5: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_10000.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_10000.txt");
	end
	6: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_15000.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_15000.txt");
	end
	7: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_20000.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_20000.txt");
	end
	8: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_25000.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_25000.txt");
	end
	9: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_1000.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_1000.txt");
	end
	10: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_1500.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_1500.txt");
	end
	11: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_2000.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_2000.txt");
	end
	12: begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv_2500.txt");
		result2 = $fopen ("./result_conv/decodedList_conv_2500.txt");
	end
	default:  begin 
		result1 = $fopen ("./result_conv/d-IBF_Left_conv.txt");
		result2 = $fopen ("./result_conv/decodedList_conv.txt");
	end
    endcase

	for (i=0; i<`IBFSize; i=i+1) $fdisplay (result1, "IBF[%d] = %b", i, IBF[i]);
	for (i=1; i<decodeIndex; i=i+1)  $fdisplay (result2, "%b", decodedList[i] );
	$fclose (result1);
	$fclose (result2);
	
end
	
endmodule