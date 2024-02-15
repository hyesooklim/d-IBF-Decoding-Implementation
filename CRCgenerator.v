//Written by prof. Hyesook Lim at Ewha Womans University (2023.01).
//This code generates and returns the 32-bit CRC code of input A

`include "./headers.v"
module CRCgenerator (input CLK, reset, Start, input [`KeyField-1:0] A, output wire Done, 
	output wire [`CRCLength-1:0] CRC_code);

reg [`KeyField-1:0] A_reg;
reg [`KeyField-1:0] count;
reg [`CRCLength-1:0] CRC_reg;
reg [`CRCLength-1:0] CRC;
reg CRC_on;

always @(posedge CLK) 
	if (reset | Start) begin
		A_reg <= A;
        end

always @(posedge CLK)
	if (reset) count <= 0;
	else if (Start) count <= 0;
	else if (count < `KeyField) count <= count + 1;

always @(posedge CLK)
	if (reset | Start) CRC_reg <=   'b1111_1111_1111_1111_1111_1111_1111_1110; //This initial value is an arbitrary number.
	else if ( count < `KeyField ) CRC_reg <= CRC;

always @(posedge CLK)
	if (reset) CRC_on <= 0;
	else if (Start) CRC_on <= 1;
	else if (Done) CRC_on <= 0;
 
always @(*) begin
	if (CRC_on) begin
		CRC[0] <= A_reg[`KeyField-count-1] ^ CRC_reg[`CRCLength-1];
		CRC[1] <= A_reg[`KeyField-count-1] ^ CRC_reg[0];
		CRC[2] <= A_reg[`KeyField-count-1] ^ CRC_reg[1];
		CRC[3] <= CRC_reg[2];
		CRC[4] <= A_reg[`KeyField-count-1] ^ CRC_reg[3];
		CRC[5] <= A_reg[`KeyField-count-1] ^ CRC_reg[4];
		CRC[6] <= CRC_reg[5];
		CRC[7] <= A_reg[`KeyField-count-1] ^ CRC_reg[6];
		CRC[8] <= A_reg[`KeyField-count-1] ^ CRC_reg[7];
		CRC[9] <= CRC_reg[8];
		CRC[10] <= A_reg[`KeyField-count-1] ^ CRC_reg[9];
		CRC[11] <= A_reg[`KeyField-count-1] ^ CRC_reg[10];
		CRC[12] <= A_reg[`KeyField-count-1] ^ CRC_reg[11];
		CRC[13] <= CRC_reg[12];
		CRC[14] <= CRC_reg[13];
		CRC[15] <= CRC_reg[14];
		CRC[16] <= A_reg[`KeyField-count-1] ^ CRC_reg[15];
		CRC[17] <= CRC_reg[16];
		CRC[18] <= CRC_reg[17];
		CRC[19] <= CRC_reg[18];
		CRC[20] <= CRC_reg[19];
		CRC[21] <= CRC_reg[20];
		CRC[22] <= A_reg[`KeyField-count-1] ^ CRC_reg[21];
		CRC[23] <= A_reg[`KeyField-count-1] ^ CRC_reg[22];
		CRC[24] <= CRC_reg[23];
		CRC[25] <= CRC_reg[24];
		CRC[26] <= A_reg[`KeyField-count-1] ^ CRC_reg[25];
		CRC[27] <= CRC_reg[26];
		CRC[28] <= CRC_reg[27];
		CRC[29] <= CRC_reg[28];
		CRC[30] <= CRC_reg[29];
		CRC[31] <= CRC_reg[30];
	end
	else CRC = 'b1111_1111_1111_1111_1111_1111_1111_1110;
end

assign Done = ( (CRC_on) & (count == `KeyField) ) ? 1 : 0;
assign CRC_code = Done ? CRC_reg : 'bz;

endmodule
