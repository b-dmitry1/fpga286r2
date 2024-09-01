module top
(
	input wire clk,
	input wire reset_n,
	
	output wire vga_vsync,
	output wire vga_hsync,
	output wire [7:0] vga_r,
	output wire [7:0] vga_g,
	output wire [7:0] vga_b,
	
	output wire [15:0] cpu_d,
	output wire [23:0] cpu_a,
	
	output wire cpu_bhe_n,
	output wire cpu_s0_n,
	output wire cpu_s1_n,
	output wire cpu_inta_n,
	output wire cpu_mio,
	
	output wire cpu_intr,
	output wire cpu_clk_n,
	output wire cpu_nmi_n,
	
	output wire cpu_error_n,
	
	output wire cpu_hold,
	output wire cpu_hlda,
	output wire cpu_reset,
	output wire cpu_ready,

	output wire sd_cs_n,
	input  wire sd_miso,
	output wire sd_mosi,
	output wire sd_sck,

	output wire usb1_p,
	output wire usb1_m,
	output wire usb2_p,
	output wire usb2_m,
	
	input  wire uart_rxd,
	output wire uart_txd,

	output wire audio_left,
	output wire audio_right,

	input  wire fdd_change_n,
	input  wire fdd_trk0_n,
	input  wire fdd_index_n,
	output wire fdd_motor_n,
	output wire fdd_drvsel_n,
	output wire fdd_dir_n,
	output wire fdd_step_n,
	output wire fdd_wdata,
	output wire fdd_wgate_n,
	output wire fdd_head_n,
	
	output wire [12:0] sdram_a,
	output wire [15:0] sdram_d,
	output wire [1:0] sdram_dqm,
	output wire [1:0] sdram_ba,
	output wire sdram_clk,
	output wire sdram_cke,
	output wire sdram_cs_n,
	output wire sdram_we_n,
	output wire sdram_cas_n,
	output wire sdram_ras_n,
	
	output wire [17:0] vram_a,
	output wire [15:0] vram_d,
	output wire [1:0] vram_dqm,
	output wire vram_cs_n,
	output wire vram_we_n,
	output wire vram_oe_n,
	
	output wire intf_irq_n,
	output wire [19:6] intf
);

//////////////////////////////////////////////////////////////////////////////
// VGA controller
//////////////////////////////////////////////////////////////////////////////

vdu i_vdu
(
	.clk         (clk),
	
	.hsync       (vga_hsync),
	.vsync       (vga_vsync),
	.red         (vga_r),
	.green       (vga_g),
	.blue        (vga_b)
);

//////////////////////////////////////////////////////////////////////////////
// UART
//////////////////////////////////////////////////////////////////////////////

reg [7:0] uart_symbol;

always @*
begin
	case (delay[25:23])
		3'd0: uart_symbol <= 8'h54;
		3'd1: uart_symbol <= 8'h65;
		3'd2: uart_symbol <= 8'h73;
		3'd3: uart_symbol <= 8'h74;
		3'd4: uart_symbol <= 8'h0D;
		3'd5: uart_symbol <= 8'h0A;
		default: uart_symbol <= 8'h20;
	endcase
end

uart i_uart
(
	.clk   (clk),
	.addr  (3'd0),
	.din   ({24'h0, uart_symbol}),
	.lane  (4'b1111),
	.wr    (1'b1),
	.valid (delay[22:0] == 23'h10000),
	.txd   (uart_txd)
);

reg [25:0]  delay;
reg [7:0] shift;

assign cpu_d = ~{2{shift}};
assign cpu_a = ~{3{shift}};

assign cpu_bhe_n = ~shift[0];
assign cpu_s0_n = ~shift[1];
assign cpu_s1_n = ~shift[2];
assign cpu_inta_n = ~shift[3];
assign cpu_mio = ~shift[4];

assign cpu_intr = ~shift[5];
assign cpu_clk_n = ~shift[6];
assign cpu_nmi_n = ~shift[7];

assign cpu_error_n = ~shift[0];
assign cpu_hold = ~shift[1];
assign cpu_hlda = ~shift[2];
assign cpu_reset = ~shift[3];
assign cpu_ready = ~shift[4];

assign sd_cs_n = ~shift[5];
assign sd_mosi = ~shift[6];
assign sd_sck = ~shift[7];

assign usb1_p = ~shift[0];
assign usb1_m = ~shift[1];
assign usb2_p = ~shift[2];
assign usb2_m = ~shift[3];

assign fdd_motor_n = ~shift[4];
assign fdd_drvsel_n = ~shift[5];
assign fdd_dir_n = ~shift[6];
assign fdd_step_n = ~shift[7];
assign fdd_wdata = ~shift[0];
assign fdd_wgate_n = ~shift[1];
assign fdd_head_n = ~shift[2];

assign sdram_a = ~{shift[0], shift[7:4], shift};
assign sdram_d = ~{2{shift}};
assign sdram_dqm = ~shift[1:0];
assign sdram_ba = ~shift[3:2];
assign sdram_clk = ~shift[4];
assign sdram_cke = ~shift[5];
assign sdram_cs_n = ~shift[6];
assign sdram_we_n = ~shift[7];
assign sdram_cas_n = ~shift[0];
assign sdram_ras_n = ~shift[1];
	
assign vram_a = ~{shift[3:2], shift, shift};
assign vram_d = ~{2{shift}};
assign vram_dqm = ~shift[5:4];
assign vram_cs_n = ~shift[6];
assign vram_we_n = ~shift[7];
assign vram_oe_n = ~shift[0];
	
assign intf_irq_n = ~shift[1];
assign intf = ~{shift[7:2], shift};

assign audio_left  = delay[16] & (&delay[24:23]) & ~delay[25];
assign audio_right = delay[16] & (&delay[25:23]);

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		delay <= 26'd0;
		shift <= 8'd1;
	end
	else
	begin
		delay <= delay + 1'd1;

		if (&delay[19:0])
		begin
			if (|shift)
				shift <= {shift[6:0], shift[7]};
			else
				shift <= 8'h01;
		end
	end
end

endmodule
