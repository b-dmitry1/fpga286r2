module ym3812_osc(
	input wire clk,
	
	input wire [7:0] din,
	input wire wr_An,
	input wire wr_Bn,
	
	input wire [3:0] harmonic1,
	input wire [3:0] harmonic2,
	
	input wire [1:0] waveform1,
	input wire [1:0] waveform2,
	
	output reg neg1,
	output reg [3:0] value1,
	
	output reg neg2,
	output reg [3:0] value2,
	
	output reg play
);

// Регистры
reg [9:0] freqn;
reg [2:0] block;

reg [31:0] period;
reg [31:0] counter1;
reg [31:0] counter2;
reg [4:0] delta1;
reg [4:0] delta2;

reg [4:0] t1;
reg [4:0] t2;

reg [3:0] sin1;
reg [3:0] sin2;

reg [25:0] freqmod;

reg [25:0] freq1;
reg [25:0] freq2;

reg [3:0] fmult1;
reg [3:0] fmult2;

always @(posedge clk)
begin
	if (wr_An) freqn[7:0] <= din;
	if (wr_Bn) freqn[9:8] <= din[1:0];
	if (wr_Bn) block <= din[4:2];
	if (wr_Bn) play <= din[5];
	
	freqmod <= {freqn + 10'd32};
	
	period <= freqmod << block;
	
	case (harmonic1)
		4'd11: fmult1 <= 4'd10;
		4'd13: fmult1 <= 4'd12;
		4'd14: fmult1 <= 4'd15;
		default: fmult1 <= harmonic1;
	endcase
	
	case (harmonic2)
		4'd11: fmult2 <= 4'd10;
		4'd13: fmult2 <= 4'd12;
		4'd14: fmult2 <= 4'd15;
		default: fmult2 <= harmonic2;
	endcase
	
	freq1 <=
		fmult1 == 4'd0 ? period :
		(fmult1[0] ? {period, 1'b0} : 1'b0) +
		(fmult1[1] ? {period, 2'b0} : 1'b0) +
		(fmult1[2] ? {period, 3'b0} : 1'b0) +
		(fmult1[3] ? {period, 4'b0} : 1'b0);
	
	freq2 <=
		fmult2 == 4'd0 ? period :
		(fmult2[0] ? {period, 1'b0} : 1'b0) +
		(fmult2[1] ? {period, 2'b0} : 1'b0) +
		(fmult2[2] ? {period, 3'b0} : 1'b0) +
		(fmult2[3] ? {period, 4'b0} : 1'b0);

	if (counter1 >= 32'd75000000)
	begin
		t1 <= t1 + 1'd1;
		counter1 <= counter1 - 32'd75000000;
	end
	else
		counter1 <= counter1 + freq1;
	
	if (counter2 >= 32'd75000000)
	begin
		t2 <= t2 + 1'd1;
		counter2 <= counter2 - 32'd75000000;
	end
	else
		counter2 <= counter2 + freq2;
	
	case (t1[3:0])
		4'h0: sin1 <= 4'h0;
		4'h1: sin1 <= 4'h3;
		4'h2: sin1 <= 4'h6;
		4'h3: sin1 <= 4'h9;
		4'h4: sin1 <= 4'hB;
		4'h5: sin1 <= 4'hC;
		4'h6: sin1 <= 4'hE;
		4'h7: sin1 <= 4'hF;
		4'h8: sin1 <= 4'hF;
		4'h9: sin1 <= 4'hF;
		4'hA: sin1 <= 4'hE;
		4'hB: sin1 <= 4'hC;
		4'hC: sin1 <= 4'hB;
		4'hD: sin1 <= 4'h9;
		4'hE: sin1 <= 4'h6;
		4'hF: sin1 <= 4'h3;
	endcase

	case (t2[3:0])
		4'h0: sin2 <= 4'h0;
		4'h1: sin2 <= 4'h3;
		4'h2: sin2 <= 4'h6;
		4'h3: sin2 <= 4'h9;
		4'h4: sin2 <= 4'hB;
		4'h5: sin2 <= 4'hC;
		4'h6: sin2 <= 4'hE;
		4'h7: sin2 <= 4'hF;
		4'h8: sin2 <= 4'hF;
		4'h9: sin2 <= 4'hF;
		4'hA: sin2 <= 4'hE;
		4'hB: sin2 <= 4'hC;
		4'hC: sin2 <= 4'hB;
		4'hD: sin2 <= 4'h9;
		4'hE: sin2 <= 4'h6;
		4'hF: sin2 <= 4'h3;
	endcase
	
	case ({t1[4:3], waveform1})
		4'd0: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd1: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd2: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd3: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd4: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd5: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd6: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd7: begin neg1 <= 1'b0; value1 <= 4'd0; end
		4'd8: begin neg1 <= 1'b1; value1 <= sin1; end
		4'd9: begin neg1 <= 1'b0; value1 <= 4'd0; end
		4'd10: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd11: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd12: begin neg1 <= 1'b1; value1 <= sin1; end
		4'd13: begin neg1 <= 1'b0; value1 <= 4'd0; end
		4'd14: begin neg1 <= 1'b0; value1 <= sin1; end
		4'd15: begin neg1 <= 1'b0; value1 <= 4'd0; end
	endcase

	case ({t2[4:3], waveform2})
		4'd0: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd1: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd2: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd3: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd4: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd5: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd6: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd7: begin neg2 <= 1'b0; value2 <= 4'd0; end
		4'd8: begin neg2 <= 1'b1; value2 <= sin2; end
		4'd9: begin neg2 <= 1'b0; value2 <= 4'd0; end
		4'd10: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd11: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd12: begin neg2 <= 1'b1; value2 <= sin2; end
		4'd13: begin neg2 <= 1'b0; value2 <= 4'd0; end
		4'd14: begin neg2 <= 1'b0; value2 <= sin2; end
		4'd15: begin neg2 <= 1'b0; value2 <= 4'd0; end
	endcase
end

endmodule
