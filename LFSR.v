//Written by prof. Hyesook Lim at Ewha Womans University (2023.01).
//This code(Linear Feedback Shift Register) generates random numbers with any length.
//This code is obtained from HDL Chip Design written by Douglas J. Smith.
//For example, if KeyField is 8, 256 different numbers are randomly generated.

`include "./headers.v"
module LFSR (input clk, reset, output wire [`KeyField-1:0] Y);
	
reg [31:0] TapsArray[2:32];
wire [`KeyField-1: 0] Taps;
integer N;
reg Bits0_Nminus1_Zero, Feedback;
reg [`KeyField-1:0] LFSR_reg, Next_LFSR_reg;

always @(reset) begin
	TapsArray[2] =  2'b 11;
	TapsArray[3] =  3'b 101;
	TapsArray[4] =  4'b 1001;
	TapsArray[5] =  5'b 10010;
	TapsArray[6] =  6'b 100001;
	TapsArray[7] =  7'b 1000001;
	TapsArray[8] =  8'b 10001110;
	TapsArray[9] =  9'b 10000100_0;
	TapsArray[10] = 10'b10000001_00;
	TapsArray[11] = 11'b10000000_010;
	TapsArray[12] = 12'b10000010_1001;
	TapsArray[13] = 13'b10000000_01101;
	TapsArray[14] = 14'b10000000_010101;
	TapsArray[15] = 15'b10000000_0000001;
	TapsArray[16] = 16'b10000000_00010110;
	TapsArray[17] = 17'b10000000_00000010_0;
	TapsArray[18] = 18'b10000000_00010000_00;
	TapsArray[19] = 19'b10000000_00000010_011;
	TapsArray[20] = 20'b10000000_00000000_0100;
	TapsArray[21] = 21'b10000000_00000000_00010;
	TapsArray[22] = 22'b10000000_00000000_000001;
	TapsArray[23] = 23'b10000000_00000000_0010000;
	TapsArray[24] = 24'b10000000_00000000_00001101;
	TapsArray[25] = 25'b10000000_00000000_00000010_0;
	TapsArray[26] = 26'b10000000_00000000_00001000_11;
	TapsArray[27] = 27'b10000000_00000000_00000010_011;
	TapsArray[28] = 28'b10000000_00000000_00000000_0100;
	TapsArray[29] = 29'b10000000_00000000_00000000_00010;
	TapsArray[30] = 30'b10000000_00000000_00000000_101001; 
	TapsArray[31] = 31'b10000000_00000000_00000000_0000100;
	TapsArray[32] = 32'b10000000_00000000_00000000_01100010;
end

assign Taps[`KeyField-1:0] = TapsArray[`KeyField];

always @(negedge reset or posedge clk)
	begin: LFSR_Register
		if (!reset) LFSR_reg <= 0;
		else LFSR_reg <= Next_LFSR_reg;
	end

always @(LFSR_reg)
	begin: LFSR_Feedback
		Bits0_Nminus1_Zero = ~| LFSR_reg[`KeyField-2:0];
		Feedback = LFSR_reg[`KeyField-1] ^ Bits0_Nminus1_Zero;
		for (N = `KeyField-1; N > 0; N = N-1)
			if (Taps[N-1]) Next_LFSR_reg[N] = LFSR_reg[N-1] ^ Feedback;
			else Next_LFSR_reg[N] = LFSR_reg[N-1];
		Next_LFSR_reg[0] = Feedback;
	end

assign Y = LFSR_reg;

endmodule
