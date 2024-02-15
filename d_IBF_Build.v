//Written by prof. Hyesook Lim at Ewha Womans University (2023.01).
//This code computes a d-IBF of two IBFs. 
//Since 2-dimensional memory cannot be returned by output, the generated d-IBF is written to a file, d-IBF.txt.
//Note that the system task to generate the file is not synthesizable.

`include "headers.v"
module d_IBF_Build (input clk, reset, Start, input Wr, input [`CellSize-1: 0] IBF_Row_1, input [`CellSize-1: 0] IBF_Row_2, input [`IndexSize:0] Addr, 
			output reg wrDone);

reg [`CellSize-1:0] IBF1 [0: `IBFSize-1];
reg [`CellSize-1:0] IBF2 [0: `IBFSize-1];
reg [`CellSize-1:0] d_IBF [0: `IBFSize-1];
reg [`CountField-1:0] count1, count2;

//Load IBF
always @(posedge clk) begin
	if (reset) wrDone <= 0;
	else if ((Wr) & (Addr <`IBFSize)) begin
		wrDone <= 0; 
		IBF1[Addr] <= IBF_Row_1;
		IBF2[Addr] <= IBF_Row_2;
	end
	if (Wr & (Addr ==`IBFSize-1) ) wrDone <= 1;
	else wrDone <= 0;
end

integer i;
always @(posedge clk) 
		if (reset) for (i=0; i<`IBFSize; i=i+1) d_IBF[i] <= 'b0;
		else if (wrDone) begin
		   for (i=0; i<`IBFSize; i=i+1) begin
			d_IBF[i][`CellSize-1:`CellSize-`KeyField] 
			= IBF1[i][`CellSize-1:`CellSize-`KeyField] ^ IBF2[i][`CellSize-1:`CellSize-`KeyField];
			//$display ("time = %d, d_IBF[%d] = %d ", $time, i, d_IBF[i]);

			d_IBF[i][`CellSize-`KeyField-1: `CellSize-`KeyField-`SigField] 
			= IBF1[i][`CellSize-`KeyField-1: `CellSize-`KeyField-`SigField] ^ IBF2[i][`CellSize-`KeyField-1: `CellSize-`KeyField-`SigField];

			count1 = IBF1[i][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField];
			count2 = IBF2[i][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField];

			if (count1 > count2) 
			d_IBF[i][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF1[i][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
				- IBF2[i][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField];
			else 
			d_IBF[i][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
			= IBF2[i][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField] 
				- IBF1[i][`CellSize-`KeyField-`SigField-1: `CellSize-`KeyField-`SigField-`CountField];
		  end
		end

integer dIBF = 0;
always @(posedge clk) begin
	dIBF = $fopen("d-IBF.txt");
	if (!reset & wrDone) for (i=0; i<`IBFSize; i=i+1) begin
		$fdisplay (dIBF, "%b", d_IBF[i]);
	end
end


endmodule
