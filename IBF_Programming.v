//Written by prof. Hyesook Lim at Ewha Womans University (2023.01).
//This code programs an IBF.
//Since 2-d memory is not returned, the programmed IBF is written to a file, "IBF1.txt" or "IBF2.txt" depending in input "no".
//The TwoIBFProgramming_Tb.v has two instantiations of this code to generate two IBFs.

`include "headers.v"
module IBF_Programming(input clk, reset, Start, insertDone, input no, input [`KeyField-1: 0] inValue, output wire Done);

reg [`CellSize-1:0] IBF1 [0: `IBFSize-1];

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

assign h1_index = (crcDone) ? CRC_code[`CRCLength-1: `CRCLength-`IndexSize] % `IBFSize : 'bz;
assign h2_index = (crcDone) ? CRC_code[`CRCLength-`NextIndexStart-1: `CRCLength-`NextIndexStart-`IndexSize] % `IBFSize : 'bz;
assign h3_index = (crcDone) ? CRC_code[`IndexSize-1: 0] % `IBFSize : 'bz;
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


integer programmed_IBF1 = 0, programmed_IBF2 = 0;
integer j=0;
always @(posedge insertDone) begin
	//if (insertDone) begin
		if (no == 1'b0) programmed_IBF1 = $fopen("IBF1.txt");
		else if (no == 1'b1) programmed_IBF1 = $fopen("IBF2.txt");
		for (j=0; j<`IBFSize; j=j+1) begin
			$fdisplay(programmed_IBF1, "%b", IBF1[j]);
		end
		$fclose (programmed_IBF1);	
	//end
end

endmodule

