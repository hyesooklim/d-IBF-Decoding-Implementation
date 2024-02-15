`include "headers.v"
module TwoIBFProgramming(input clk, reset, Start, insertDone, input [`KeyField-1: 0] inValue, output wire Done);

reg [`CellSize-1:0] IBF1 [0: `IBFSize-1];
reg [`CellSize-1:0] IBF2 [0: `IBFSize-1];

wire [`KeyField-1: 0] A;
//wire [`Len-1:0] Length;
wire [`CRCLength-1: 0] CRC_code;
wire [`IndexSize-1:0] h1_index, h2_index, h3_index;
reg [`KeyField-1: 0] keyValue;
wire [`SigField-1:0] inSig;
reg [`SetLen - 1: 0] programmedNo;
wire crcDone;

assign A = inValue;
assign Done = crcDone;

CRCgenerator CRC (clk, reset, Start, A, crcDone, CRC_code);

assign h1_index = CRC_code[`CRCLength-1: `CRCLength-`IndexSize];
assign h2_index = CRC_code[`CRCLength-`IndexSize-1: `CRCLength-`IndexSize-`IndexSize];
assign h3_index = CRC_code[`IndexSize-1: 0];
//assign inSig = keyValue[`KeyField-1:`KeyField-`SigField];

assign inSig = CRC_code[`CRCLength-`IndexSize-1: `CRCLength-`IndexSize-`SigField];

always @(posedge clk)
	if (reset) keyValue <= 0;
	else keyValue <= (Start) ? inValue: keyValue;

always @(posedge clk)
	if (reset) programmedNo <= 0;
	else if (crcDone) programmedNo <= programmedNo + 1;
 
//insert an element. Blocking assignment is used for the case of the same indexes.
integer i;
always @(posedge clk) begin
	if (reset) for(i=0; i<`IBFSize; i=i+1) IBF1[i] = 'b0;
	else if (crcDone) begin
		IBF1[h1_index][`CellSize-1:`CellSize-`KeyField] = IBF1[h1_index][`CellSize-1:`CellSize-`KeyField] ^ keyValue;
		IBF1[h2_index][`CellSize-1:`CellSize-`KeyField] = IBF1[h2_index][`CellSize-1:`CellSize-`KeyField] ^ keyValue;
		IBF1[h3_index][`CellSize-1:`CellSize-`KeyField] = IBF1[h3_index][`CellSize-1:`CellSize-`KeyField] ^ keyValue; 

		IBF1[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] 
			= IBF1[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ]^ inSig;
		IBF1[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] 
			= IBF1[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ]^ inSig;
		IBF1[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] 
			= IBF1[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ]^ inSig;

		IBF1[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF1[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] + 1;
		IBF1[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF1[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] + 1;
		IBF1[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF1[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] + 1;
	end
end

//programming IBF2
always @(posedge clk) begin
	if (reset) for(i=0; i<`IBFSize; i=i+1) IBF2[i] = 'b0;
	else if (crcDone & (programmedNo <`Set2Size)) begin
		IBF2[h1_index][`CellSize-1:`CellSize-`KeyField] = IBF2[h1_index][`CellSize-1:`CellSize-`KeyField] ^ keyValue;
		IBF2[h2_index][`CellSize-1:`CellSize-`KeyField] = IBF2[h2_index][`CellSize-1:`CellSize-`KeyField] ^ keyValue;
		IBF2[h3_index][`CellSize-1:`CellSize-`KeyField] = IBF2[h3_index][`CellSize-1:`CellSize-`KeyField] ^ keyValue; 

		IBF2[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] 
			= IBF2[h1_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ]^ inSig;
		IBF2[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] 
			= IBF2[h2_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ]^ inSig;
		IBF2[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ] 
			= IBF2[h3_index][`CellSize-`KeyField-1:`CellSize-`KeyField-`SigField ]^ inSig;

		IBF2[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF2[h1_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] + 1;
		IBF2[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF2[h2_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] + 1;
		IBF2[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF2[h3_index][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] + 1;
	end
end


integer programmed_IBF1 = 0, programmed_IBF2 = 0;
integer j=0;
always @(*)
	if (insertDone) begin
		programmed_IBF1 = $fopen("IBF1.txt");
		programmed_IBF2 = $fopen("IBF2.txt");
		for (j=0; j<`IBFSize; j=j+1) begin
			$fdisplay(programmed_IBF1, "%b", IBF1[j]);
			$fdisplay(programmed_IBF2, "%b", IBF2[j]);
		end
		
	end

endmodule


