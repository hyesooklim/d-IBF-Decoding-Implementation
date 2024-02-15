//Written by prof. Hyesook Lim at Ewha Womans University (2023.01).
//This testbench provides two IBFs to d-IBF_build.v design. 
//Each row of two IBFs are provided to the design in each clock cycle.

`include "./headers.v"

module d_IBF_Build_Tb;
//parameter tlimit = 20000;
//initial #tlimit $stop;
reg [`CellSize-1:0] IBF1 [0: `IBFSize-1];
reg [`CellSize-1:0] IBF2 [0: `IBFSize-1];
reg Wr;
reg [`IndexSize:0] Addr;
wire [`CellSize-1: 0] IBF_Row1, IBF_Row2;
wire [`SetLen - 1: 0] decodedNum;

reg clk = 0, reset = 1, Start = 0;

d_IBF_Build d_IBF (clk, reset, Start, Wr, IBF_Row1, IBF_Row2, Addr, wrDone);

initial $readmemb ("IBF1.txt", IBF1);
initial $readmemb ("IBF2.txt", IBF2);
always #5 clk = ~clk; //clock generation
initial #10 reset = 0; //reset de-activation

//Load IBF
always @(posedge clk)
	if (reset) begin
		Wr = 1;
		Addr = 0;	
	end
	else if ((!wrDone) & (Addr <`IBFSize)) begin Addr = Addr + 1; end
	else if (Addr == `IBFSize) Wr = 0; 

assign IBF_Row1 = IBF1[Addr]; 
assign IBF_Row2 = IBF2[Addr];

always @(posedge wrDone) begin
	$display ("d-IBF Build complete!");
	#100 $stop;
end

endmodule
