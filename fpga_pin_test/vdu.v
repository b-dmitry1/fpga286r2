module vdu
(
	input  wire        clk,
	
	output wire        hsync,
	output wire        vsync,
	output reg  [ 7:0] red,
	output reg  [ 7:0] green,
	output reg  [ 7:0] blue
);

assign     hsync = ~((hcounter >= 10'd664) && (hcounter < 10'd760));
assign     vsync = ~((vcounter >= 10'd490) && (vcounter < 10'd492));

reg        pixel_div;

reg  [9:0] hcounter;
reg  [9:0] vcounter;

reg  [7:0] frame;

always @(posedge clk)
begin
	pixel_div <= ~pixel_div;
	
	if (hcounter < 10'd640 && vcounter < 10'd480)
	begin
		red   <= hcounter[7:0] + frame;
		green <= vcounter[7:0] + hcounter[8:1];
		blue  <= vcounter[7:0];
	end
	else
	begin
		red   <= 8'd0;
		green <= 8'd0;
		blue  <= 8'd0;
	end
	
	if (pixel_div)
	begin
		if (hcounter == 10'd799)
		begin
			hcounter <= 10'd0;
			if (vcounter == 10'd524)
			begin
				vcounter <= 10'd0;
				frame <= frame + 1'd1;
			end
			else
			begin
				vcounter <= vcounter + 10'd1;
			end
		end
		else
			hcounter <= hcounter + 10'd1;
	end
end

endmodule
