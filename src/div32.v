module div32(
	input wire clk,
	
	input wire [31:0] denom,
	input wire [31:0] num,
	output reg [31:0] q,
	output reg [31:0] r,
	
	input wire signed_div,
	
	input wire valid,
	output reg ready
);

reg [63:0] v;
reg [31:0] m;
reg [ 5:0] phase;
reg [31:0] res;
reg [63:0] bm;

wire sign             = denom[31] ^ num[31];
wire [31:0] pos_denom = (signed_div && denom[31]) ? 32'd0 - denom : denom;
wire [31:0] pos_num   = (signed_div && num[31]) ? 32'd0 - num : num;

always @(posedge clk)
begin
	if (valid)
	begin
		q <= (signed_div && sign) ? 32'd0 - res[31:0] : res[31:0];
		r <= (signed_div && sign) ? 32'd0 - v[31:0] : v[31:0];
		if (phase == 6'd32)
		begin
			ready <= 1;
		end
		else
		begin
			if (v >= bm)
			begin
				res <= res | m;
				v   <= v - bm;
			end
			bm <= {1'b0, bm[63:1]};
			m  <= {1'b0, m[31:1]};
		end
		phase  <= phase + 6'd1;
	end
	else
	begin
		ready <= 0;
		v     <= pos_denom;
		res   <= 32'd0;
		m     <= 32'h80000000;
		bm    <= {1'b0, pos_num, 31'd0};
		phase <= 6'd0;
	end
end

endmodule
