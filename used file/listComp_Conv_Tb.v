`include "./headers.v"
module listComp_Conv_Tb;

reg [`KeyField:0] SetDiff [0:`S1Distinct+`S2Distinct-1];
reg [`KeyField:0] DecodedList [0:`DecodeMax-1];
reg [0:`S1Distinct+`S2Distinct-1] Found;

initial $readmemb ("Set_Difference.txt", SetDiff);
initial $readmemb ("decodedList_conv.txt", DecodedList);

integer foundCount = 0, notFoundCount = 0;
integer i, j;
initial begin 
	for (i=0;i<`S1Distinct+`S2Distinct; i = i+1) Found[i] = 0;
	for (i=0;i<`S1Distinct+`S2Distinct; i = i+1) begin
		for (j=0;j<`DecodeMax;j=j+1) begin
			if (SetDiff[i] == DecodedList[j]) begin
				foundCount = foundCount + 1; Found[i] = 1;
				$display (" %d element is located in decodedList %d", i, (j+1));
			end
		end
		if (!Found[i]) begin $display ("%d element not found", i); notFoundCount = notFoundCount + 1; end
	end
	$display ("No. of correctly decoded elements = %d, No. of unfound elements = %d", foundCount, notFoundCount);
end

endmodule
