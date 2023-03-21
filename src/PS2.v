module PS2(
	input wire clk,
	input wire reset_n,
	
	output reg led,
	
	inout wire dm,
	inout wire dp,

	input wire [11:0] port,
	output reg [7:0] dout,
	input wire [7:0] din,
	input wire cpu_iordin,
	output reg cpu_iordout,
	input wire cpu_iowrin,
	output reg cpu_iowrout,
	
	output reg [7:0] keycode,
	output reg irq1
);

wire noled;
wire [7:0] shift;
wire [7:0] keycode1;
wire [7:0] keycode2;
wire [7:0] keycode3;
reg [7:0] prev_shift;
reg [7:0] prev_keycode1;
reg [7:0] prev_keycode2;
reg [7:0] prev_keycode3;
USB_LS_HID ls_hid(
	.clk(clk),
	.reset_n(reset_n),
	
	.led(noled),
	
	.shift(shift),
	.keycode1(keycode1),
	.keycode2(keycode2),
	.keycode3(keycode3),
	
	.dm(dm),
	.dp(dp)
);

wire iord = cpu_iordout ^ cpu_iordin;
wire iowr = cpu_iowrout ^ cpu_iowrin;

reg cs_60h;
reg cs_61h;

reg [24:0] div;

reg [19:0] div2;

wire [7:0] code1;
keyboard rom
(
	.clock(~clk),
	.address(keycode1 | prev_keycode1),
	.q(code1)
);

always @(negedge clk)
begin
	cs_60h <= port == 12'h060;
	cs_61h <= port == 12'h061;
end

reg press1;
reg release1;

always @(posedge clk)
begin
	cpu_iordout <= cpu_iordin;
	cpu_iowrout <= cpu_iowrin;
	
	dout <= keycode;
	
	//led <= noled;
	
	if (div2[19:12] == keycode1)
	begin
		div2 <= 20'd0;
		led <= ~led;
	end
	else
	begin
		div2 <= div2 + 1'd1;
	end
	
	// irq1 <= div < 7'd30;
	
	if (cs_61h && iowr)
	begin
		irq1 <= 1'b0;
	end
	
	div <= div[24] ? 25'd0 : div + 1'd1;
	
	prev_shift <= shift;
	prev_keycode1 <= keycode1;
	prev_keycode2 <= keycode2;
	prev_keycode3 <= keycode3;
	
	press1 <= prev_keycode1 == 8'd0 && keycode1 != 8'd0;
	release1 <= prev_keycode1 != 8'd0 && keycode1 == 8'd0;
	
	if (press1)
	begin
		keycode <= code1;
		if (|code1)
			irq1 <= 1'b1;
	end
	else if (release1)
	begin
		keycode <= code1 | 8'h80;
		if (code1)
			irq1 <= 1'b1;
	end
end

endmodule
