//Written by prof. Hyesook Lim at Ewha Womans University (2023.01).
//This testbench is for testing the CRCgenerator design.

`timescale 1ns/1ns

module CRCgenerator_Tb;

parameter tlimit = 100;

reg CLK = 0;
reg reset = 1;
reg [7:0] A = 0 ;
wire [31:0] CRC_code;
wire Done;

reg Start = 0;

CRCgenerator CRC (CLK, reset, Start, A, Done,  CRC_code);
always #5 CLK = ~CLK;

initial #20 reset = 0;
           
initial begin               
 		#25;
                Start = 1; 
		A [7:0] = 'b11010001; 
                #15 Start = 0;
                wait (Done) 
                    #20;
end



always @(posedge Done) begin
		$display ("time = %d, A = %b, CRC_code = %h", $time, A, CRC_code);
end

initial #2000  $stop;

endmodule