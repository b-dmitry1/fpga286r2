module Main(
	input wire clk,
	input wire reset_n,
	
	output wire vga_vsync,
	output wire vga_hsync,
	output wire [7:4] vga_r,
	output wire [7:4] vga_g,
	output wire [7:4] vga_b,
	
	inout reg  [15:0] cpu_d,
	input wire [23:0] cpu_a,
	
	input wire cpu_bhe_n,
	input wire cpu_s0_n,
	input wire cpu_s1_n,
	input wire cpu_inta_n,
	input wire cpu_mio,
	
	output wire cpu_intr,
	output reg cpu_clk_n,
	output wire cpu_nmi_n,
	
	input wire cpu_error_n,
	
	output wire cpu_hold,
	input wire cpu_hlda,
	output reg cpu_reset,
	output reg cpu_ready,
	
	output wire sd_cs_n,
	input wire sd_miso,
	output wire sd_mosi,
	output wire sd_sck,

	inout wire usb1_p,
	inout wire usb1_m,
	inout wire usb2_p,
	inout wire usb2_m,
	
	input wire uart_rxd,
	output wire uart_txd,

	output reg audio_left,
	output reg audio_right,

	input wire fdd_change_n,
	input wire fdd_wprot_n,
	input wire fdd_trk0_n,
	input wire fdd_index_n,
	output wire fdd_motor_n,
	output wire fdd_drvsel_n,
	output wire fdd_dir_n,
	output wire fdd_step_n,
	output wire fdd_wdata,
	output wire fdd_wgate_n,
	output wire fdd_head_n,
	
	output wire [12:0] sdram_a,
	inout wire [15:0] sdram_d,
	output wire [1:0] sdram_dqm,
	output wire [1:0] sdram_ba,
	output wire sdram_clk,
	output wire sdram_cke,
	output wire sdram_cs_n,
	output wire sdram_we_n,
	output wire sdram_cas_n,
	output wire sdram_ras_n,
	
	output wire [17:0] vram_a,
	inout wire [15:0] vram_d,
	output wire [1:0] vram_dqm,
	output wire vram_cs_n,
	output wire vram_we_n,
	output wire vram_oe_n,
	
	output reg intf_irq_n,
	inout reg [19:6] intf
);

assign cpu_nmi_n = 1'b1;
assign cpu_hold = 1'b0;

wire empty_txd;

always @(posedge clk)
begin
	intf_irq_n <= 1'bZ;
	intf[19:6] <= 14'bZZZZZZZZZZZZZZ;
end

//////////////////////////////////////////////////////////////////////////////
// RISC-V Memory map
//////////////////////////////////////////////////////////////////////////////

wire sram_area        = addr[31:28] == 4'h0;
wire uart_area        = addr[31:24] == 8'h10;
wire timer_area       = addr[31:24] == 8'h11;
wire gpio_area        = addr[31:24] == 8'h13;
wire usb1_area        = addr[31:24] == 8'h14 && (addr[13:12] == 2'b00);
wire usb2_area        = addr[31:24] == 8'h14 && (addr[13:12] == 2'b01);
wire vps2_area        = addr[31:24] == 8'h15;
wire mouse_area       = addr[31:24] == 8'h16;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RISC-V USB
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [31:0] usb1_dout;
wire        usb1_ready;
usb_phy i_usb_phy1(
	.clk   (clk),
	.clk60m(clk60m),
	.reset_n(reset_n),
	.addr  (addr),
	.din   (din),
	.dout  (usb1_dout),
	.lane  (lane),
	.wr    (wr),
	.valid (valid && usb1_area),
	.ready (usb1_ready),

	.dm    (usb1_m),
	.dp    (usb1_p)
);

wire [31:0] usb2_dout;
wire        usb2_ready;
usb_phy i_usb_phy2(
	.clk   (clk),
	.clk60m(clk60m),
	.reset_n(reset_n),
	.addr  (addr),
	.din   (din),
	.dout  (usb2_dout),
	.lane  (lane),
	.wr    (wr),
	.valid (valid && usb2_area),
	.ready (usb2_ready),

	.dm    (usb2_m),
	.dp    (usb2_p)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RISC-V UART
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire [31:0] uart_dout;
uart i_uart
(
	.clk   (clk),
	.addr  (addr),
	.din   (din),
	.dout  (uart_dout),
	.lane  (lane),
	.wr    (wr),
	.valid (valid && uart_area),
	.rxd   (uart_rxd),
	.txd   (uart_txd)
);

//////////////////////////////////////////////////////////////////////////////
// RISC-V TIMER
//////////////////////////////////////////////////////////////////////////////

reg [63:0] mtime;
reg [63:0] mtimecmp;
reg [19:0] timer_div;
reg [31:0] timer_dout;
wire       timer_irq = (mtimecmp[63:0] != 64'd0) && (mtime[63:0] > mtimecmp[63:0]);
always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		mtime    <= 64'd0;
		mtimecmp <= 64'd0;
	end
	else
	begin
		// Increment every 1 us
		timer_div <= timer_div == 19'd49 ? 5'd0 : timer_div + 1'd1;

		if (valid && wr && timer_area && addr[15:0] == 16'h4000)
			mtimecmp[31: 0] <= din;
		if (valid && wr && timer_area && addr[15:0] == 16'h4004)
			mtimecmp[63:32] <= din;

		if (valid && wr && timer_area && addr[15:0] == 16'hBFF8)
			mtime[31: 0] <= din;
		else if (valid && wr && timer_area && addr[15:0] == 16'hBFFC)
			mtime[63:32] <= din;
		else
			mtime        <= timer_div == 8'd49 ? mtime + 32'd1 : mtime;

		case (addr[3:2])
			2'b00: timer_dout <= mtimecmp[31: 0];
			2'b01: timer_dout <= mtimecmp[63:32];
			2'b10: timer_dout <= mtime   [31: 0];
			2'b11: timer_dout <= mtime   [63:32];
		endcase
	end
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RISC-V
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire [31:0] addr;
wire [31:0] din;
reg  [31:0] dout;
wire [ 3:0] lane;
wire        wr;
wire        valid;
reg         ready;
riscv_min i_cpu
(
	.clk   (clk),
	.rst   (~reset_n),
	.addr  (addr),
	.dout  (din),
	.din   (usb1_area ? usb1_dout : usb2_area ? usb2_dout : dout),
	.lane  (lane),
	.wr    (wr),
	.valid (valid),
	.ready (ready || usb1_ready || usb2_ready)

//	.timer_irq (timer_irq)
);

reg last_valid;

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		ready <= 0;
		last_valid <= 0;
	end
	else
	begin
		// Peripherial to CPU data bus
		last_valid <= valid;
		if (last_valid && valid && ~ready)
		begin
			dout <=
				sram_area ? sram_dout :
				uart_area ? uart_dout :
				timer_area ? timer_dout :
				usb1_area ? usb1_dout :
				usb2_area ? usb2_dout :
				vps2_area ? vps2_dout :
				mouse_area ? mouse_dout :
				32'hFFFFFFFF;
		end

		// "Ready" control
		ready <= last_valid && valid && ~ready;
	end
end

//////////////////////////////////////////////////////////////////////////////
// RISC-V ROM / RAM
//////////////////////////////////////////////////////////////////////////////

wire [31:0] sram_dout;
reg sram_wr;
riscv_ram i_riscv_sram
(
	.clock   (clk),
	.data    (din),
	.address (addr[13:2]),
	.wren    (valid && wr && sram_area),
	.byteena (lane),
	.q       (sram_dout)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// USB to virtual PS/2 converter
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [7:0] ps2_iodout;
wire cpu_rdin_ps2;
reg  cpu_rdout_ps2;
wire cpu_wrin_ps2;
reg  cpu_wrout_ps2;

wire [31:0] vps2_dout;
wire        vps2_ready;
PS2 ps2(
	.clk(clk),
	.reset_n(reset_n),

	.r_addr  (addr),
	.r_din   (din),
	.r_dout  (vps2_dout),
	.r_lane  (lane),
	.r_wr    (wr),
	.r_valid (valid && vps2_area),
	.r_ready (vps2_ready),

	.port(addr_8bit),
	.dout(ps2_iodout),
	.din(data_8bit),
	.cpu_iordin(cpu_rdout_ps2),
	.cpu_iordout(cpu_rdin_ps2),
	.cpu_iowrin(cpu_wrout_ps2),
	.cpu_iowrout(cpu_wrin_ps2),

	.irq1(irq[1]),

	.toggle(div[16:15])
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// USB to virtual serial mouse converter
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [7:0] mouse_iodout;
wire cpu_rdin_mouse;
reg  cpu_rdout_mouse;
wire cpu_wrin_mouse;
reg  cpu_wrout_mouse;

wire [31:0] mouse_dout;
wire        mouse_ready;
serial_mouse i_mouse(
	.clk(clk),
	.reset_n(reset_n),

	.r_addr  (addr),
	.r_din   (din),
	.r_dout  (mouse_dout),
	.r_lane  (lane),
	.r_wr    (wr),
	.r_valid (valid && mouse_area),
	.r_ready (mouse_ready),

	.port(addr_8bit),
	.dout(mouse_iodout),
	.din(data_8bit),
	.cpu_iordin(cpu_rdout_mouse),
	.cpu_iordout(cpu_rdin_mouse),
	.cpu_iowrin(cpu_wrout_mouse),
	.cpu_iowrout(cpu_wrin_mouse),

	.irq4(irq[4])
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UART
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
reg [7:0] uart_tx_data;
reg cpu_wrout_dbg;
wire uart_tx_in;
wire dbg_ready = cpu_wrout_dbg == uart_tx_in;
wire empty_txd2;
UART_tx uart_tx(
	.clk(clk),
	.data(data_8bit),
	.send_in(cpu_wrout_dbg),
	.send_out(uart_tx_in),
//	.txd(uart_txd)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PLL
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire clk_sdram;
wire clk_sram;
wire clk2;
wire clk60m;
PLL1 i_pll1(.inclk0(clk), .c0(clk_sdram), .c2(clk_sram), .c3(clk2), .c4(clk60m));

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SDRAM
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [15:0] cpu_dout_sdram;
reg [15:0] cpu_din_sdram;
wire cpu_rdin_sdram;
reg  cpu_rdout_sdram;
wire cpu_wrin_sdram;
reg cpu_wrout_sdram;
wire sdram_cpu_addr_hit;
wire sdram_ready;

SDRAM sdram(.clk(clk), .clk1(clk_sdram), .reset_n(reset_n), .ready(sdram_ready),
	.cpu_addr(c_a), .cpu_bhe_n(c_bhe_n), .cpu_din(c_d), .cpu_dout(cpu_dout_sdram), .cpu_addr_hit(sdram_cpu_addr_hit),
	.cpu_rdin(cpu_rdout_sdram), .cpu_rdout(cpu_rdin_sdram), .cpu_wrin(cpu_wrout_sdram), .cpu_wrout(cpu_wrin_sdram),

	.a(sdram_a), .ba(sdram_ba), .d(sdram_d), .ras_n(sdram_ras_n), .cas_n(sdram_cas_n), .we_n(sdram_we_n), .cs_n(sdram_cs_n),
	.sclk(sdram_clk), .scke(sdram_cke), .dqm(sdram_dqm));

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SRAM
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire [15:0] cpu_dout_sram;
reg [15:0] cpu_din_sram;
wire cpu_rdin_sram;
reg  cpu_rdout_sram;
wire cpu_wrin_sram;
reg  cpu_wrout_sram;
wire sram_ready;

wire [23:0] gpu_addr;
wire [31:0] gpu_din;
wire [31:0] gpu_dout;
wire gpu_rdin;
wire gpu_rdout;
wire gpu_wrin;
wire gpu_wrout;

SRAM sram(.clk(clk),
	.cpu_addr(c_a), .cpu_bhe_n(c_bhe_n), .cpu_din(c_d), .cpu_dout(cpu_dout_sram), .ready(sram_ready),
	.cpu_rdin(cpu_rdout_sram), .cpu_rdout(cpu_rdin_sram), .cpu_wrin(cpu_wrout_sram), .cpu_wrout(cpu_wrin_sram),
	.gpu_addr(gpu_addr), .gpu_din(gpu_din), .gpu_dout(gpu_dout),
	.gpu_rdin(gpu_rdin), .gpu_rdout(gpu_rdout), .gpu_wrin(gpu_wrin), .gpu_wrout(gpu_wrout),
	.video_addr(video_addr), .video_dout(video_din),
	.a(vram_a), .d(vram_d), .we_n(vram_we_n), .cs_n(vram_cs_n), .oe_n(vram_oe_n),
	.lb_n(vram_dqm[0]), .ub_n(vram_dqm[1]));

	
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// VGA
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [23:0] video_addr;
wire [63:0] video_din;
wire [7:0] video_red;
wire [7:0] video_green;
wire [7:0] video_blue;
assign vga_r = video_red[7:4];
assign vga_g = video_green[7:4];
assign vga_b = video_blue[7:4];
wire [7:0] vga_iodout;
wire [15:0] vga_dout;
wire vga_ready;
wire vga_planar;

wire cpu_rdin_vga;
reg  cpu_rdout_vga;
wire cpu_wrin_vga;
reg  cpu_wrout_vga;

VGA vga(.clk(clk), .reset_n(reset_n), .ready(vga_ready),
	// .a(c_a), .din(c_d), .dout(vga_dout), .mrdin(cpu_rdout_sram), .mwrin(cpu_wrout_sram),
	.port(addr_8bit), .iodin(data_8bit), .iodout(vga_iodout),
	.iordin(cpu_rdout_vga),
	.iordout(cpu_rdin_vga),
	.iowrin(cpu_wrout_vga),
	.iowrout(cpu_wrin_vga),

	.hsync(vga_hsync), .vsync(vga_vsync),
	.red(video_red), .green(video_green), .blue(video_blue),
	.video_addr(video_addr),

	.video_din(video_din),

	.gpu_addr(gpu_addr),
	.gpu_din(gpu_dout),
	.gpu_dout(gpu_din),
	.gpu_rdin(gpu_rdout),
	.gpu_rdout(gpu_rdin),
	.gpu_wrin(gpu_wrout),
	.gpu_wrout(gpu_wrin),

	.planar(vga_planar)

	// ,.hdmi_rp(hdmi_rp), .hdmi_rm(hdmi_rm), .hdmi_gp(hdmi_gp), .hdmi_gm(hdmi_gm), .hdmi_bp(hdmi_bp), .hdmi_bm(hdmi_bm), .hdmi_cp(hdmi_cp), .hdmi_cm(hdmi_cm)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// SPI
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [7:0] spi_iodout;
wire spi_ready;
wire cpu_rdin_spi;
reg  cpu_rdout_spi;
wire cpu_wrin_spi;
reg  cpu_wrout_spi;
SPI spi(
	.clk(clk),

	.addr(addr_8bit),
	.din(data_8bit),
	.dout(spi_iodout),

	.cpu_iordin(cpu_rdout_spi),
	.cpu_iordout(cpu_rdin_spi),
	.cpu_iowrin(cpu_wrout_spi),
	.cpu_iowrout(cpu_wrin_spi),

	.ready(spi_ready),

	.cs_n(sd_cs_n),
	.miso(sd_miso),
	.mosi(sd_mosi),
	.sck(sd_sck)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PIT
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire t1out, t2out;
wire [7:0] pit_iodout;
wire cpu_rdin_pit;
reg  cpu_rdout_pit;
wire cpu_wrin_pit;
reg  cpu_wrout_pit;
PIT pit(
	.clk(clk),
	.reset_n(reset_n),
	
	.port(addr_8bit),
	.din(data_8bit),
	.dout(pit_iodout),

	.cpu_iordin(cpu_rdout_pit),
	.cpu_iordout(cpu_rdin_pit),
	.cpu_iowrin(cpu_wrout_pit),
	.cpu_iowrout(cpu_wrin_pit),
	
	.irq0(irq[0]),
	.t1out(t1out),
	.t2out(t2out)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PIC
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [7:0] pic_iodout;
wire cpu_rdin_pic;
reg  cpu_rdout_pic;
wire cpu_wrin_pic;
reg  cpu_wrout_pic;
wire [7:0] irq_vector;
wire [7:0] irq;
PIC pic(
	.clk(clk),
	.reset_n(reset_n),
	
	.port(addr_8bit),
	.din(data_8bit),
	.dout(pic_iodout),

	.cpu_iordin(cpu_rdout_pic),
	.cpu_iordout(cpu_rdin_pic),
	.cpu_iowrin(cpu_wrout_pic),
	.cpu_iowrout(cpu_wrin_pic),

	.inta(inta),
	
	.irq_vector(irq_vector),
	.intr(cpu_intr),
	
	.irq0(irq[0]),
	.irq1(irq[1]),
	.irq4(irq[4])
);


reg [23:0] div;
reg run;

// assign cpu_reset = ~run;

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		div <= 24'd0;
		run <= 1'b0;
	end
	else
	begin
		div <= div + 24'd1;
		if (div[23])
			run <= 1'b1;
	end
end



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// BIOS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [15:0] bios_out;
BIOS bios(
	.clock(clk),
	.address(c_a[12:1]),
	.q(bios_out)
);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Fake YM3812
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
wire [7:0] ym3812_iodout;
wire cpu_rdin_ym3812;
reg  cpu_rdout_ym3812;
wire cpu_wrin_ym3812;
reg  cpu_wrout_ym3812;
wire [7:0] music;
ym3812 i_ym3812(
	.clk(clk),
	.reset_n(reset_n),

	.port(addr_8bit),
	.dout(ym3812_iodout),
	.din(data_8bit),
	.cpu_iordin(cpu_rdout_ym3812),
	.cpu_iordout(cpu_rdin_ym3812),
	.cpu_iowrin(cpu_wrout_ym3812),
	.cpu_iowrout(cpu_wrin_ym3812),
	
	.music(music)
	
//	.txd   (uart_txd)
);

wire ym3812_ready = cpu_rdout_ym3812 == cpu_rdin_ym3812;

reg [9:0] pwm;
always @(posedge clk)
begin
	pwm <= pwm + 1'd1;
	audio_left <= pwm < music;
	audio_right <= pwm < music;
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 16 bit to 8 bit bridge
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

task send_io_request;
	if (spi_write) cpu_wrout_spi <= ~cpu_wrout_spi;
	if (spi_read) cpu_rdout_spi <= ~cpu_rdout_spi;
	if (pit_write) cpu_wrout_pit <= ~cpu_wrout_pit;
	if (pit_read) cpu_rdout_pit <= ~cpu_rdout_pit;
	if (pic_write) cpu_wrout_pic <= ~cpu_wrout_pic;
	if (pic_read) cpu_rdout_pic <= ~cpu_rdout_pic;
	if (vga_write) cpu_wrout_vga <= ~cpu_wrout_vga;
	if (vga_read) cpu_rdout_vga <= ~cpu_rdout_vga;
	if (dbg_write) cpu_wrout_dbg <= ~cpu_wrout_dbg;
	if (ps2_write) cpu_wrout_ps2 <= ~cpu_wrout_ps2;
	if (ps2_read) cpu_rdout_ps2 <= ~cpu_rdout_ps2;
	if (ym3812_write) cpu_wrout_ym3812 <= ~cpu_wrout_ym3812;
	if (ym3812_read) cpu_rdout_ym3812 <= ~cpu_rdout_ym3812;
	if (mouse_write) cpu_wrout_mouse <= ~cpu_wrout_mouse;
	if (mouse_read) cpu_rdout_mouse <= ~cpu_rdout_mouse;
endtask


reg [23:0] addr_8bit;
reg [7:0] data_8bit;
reg [15:0] result_16bit;
reg cycle_phase0;
reg cycle_phase1;

task process_bridge;
	if (io_ready)
	begin
		if (cycle_phase0)
		begin
			// Cycle 0 is done -> store lower 8 bit from i/o device's output,
			// send higher 8 bit, and advance to a next address
			addr_8bit[0] <= 1'b1;
			data_8bit <= c_d[15:8];
			
			cycle_phase0 <= 1'b0;
			result_16bit[7:0] <= io_dout;

			if (cycle_phase1)
				send_io_request;
		end
		else if (cycle_phase1)
		begin
			cycle_phase1 <= 1'b0;
			result_16bit[15:8] <= io_dout;
		end
	end
endtask

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CPU
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
reg [1:0] c_s;

reg [23:0] c_a;
reg c_bhe_n;
reg [15:0] c_d;

always @(posedge clk)
begin
	cpu_d <=
		bios_read ? bios_out :
		vram_read ? cpu_dout_sram :
		ram_read ? cpu_dout_sdram :
		spi_read ? result_16bit :
		pit_read ? result_16bit :
		pic_read ? result_16bit :
		vga_read ? result_16bit :
		ps2_read ? result_16bit :
		ym3812_read ? result_16bit :
		mouse_read ? result_16bit :
		inta ? irq_vector :
		16'hZZZZ;
end

wire [7:0] io_dout =
	vga_read ? vga_iodout :
	pic_read ? pic_iodout :
	pit_read ? pit_iodout :
	ps2_read ? ps2_iodout :
	ym3812_read ? ym3812_iodout :
	mouse_read ? mouse_iodout :
	spi_iodout;

always @(negedge div[0])
begin
	cpu_clk_n <= ~cpu_clk_n;
end

always @(posedge cpu_clk_n)
begin
	cpu_reset <= ~run;
end

// BIOS: 0F0000-0FFFFF, FF0000-FFFFFF
wire bios_area = (&cpu_a[19:16]) && (cpu_a[23:20] == 4'hF || cpu_a[23:20] == 4'h0);
// Video RAM: 0A0000-0BFFFF
wire vram_area = cpu_a[23:17] == 7'b0000101;
// RAM: all but BIOS and Video RAM
wire ram_area = !vram_area;

// SPI: I/O 0B0-0B2
wire spi_area = cpu_a[11:2] == 10'b0000101100;
// PIT: I/O 040-043
wire pit_area = cpu_a[11:2] == 10'b0000010000;
// PIC: I/O 020-021
wire pic_area = cpu_a[11:1] == 11'b00000010000;
// VGA: I/O 3B0-3DF
wire vga_area = (cpu_a[11:5] == 7'b0011101) || (cpu_a[11:5] == 7'b0011110) || (cpu_a[11:0] == 12'h0BE);
// DEBUG UART: I/O 0BC
wire dbg_area = cpu_a[11:0] == 12'hBC;
// PS/2: I/O 060-064
wire ps2_area = cpu_a[11:3] == 9'b000001100;
// COM1: I/O 3F8-3FF
wire com1_area = cpu_a[11:3] == 9'b001111111;
// YM3812: I/O 388-389
wire ym3812_area = cpu_a[11:3] == 9'b001110001;

// Decoded commands and areas
reg bios_read;
reg vram_read;
reg vram_write;
reg ram_read;
reg ram_write;
reg inta;

reg spi_read;
reg spi_write;
reg pit_read;
reg pit_write;
reg pic_read;
reg pic_write;
reg vga_read;
reg vga_write;
reg dbg_write;
reg ps2_read;
reg ps2_write;
reg ym3812_read;
reg ym3812_write;
reg mouse_read;
reg mouse_write;

reg io_read;
reg io_write;

// CPU cycle status
wire [3:0] cpu_cmd = {cpu_inta_n, cpu_mio, cpu_s1_n, cpu_s0_n};
wire mem_read_cycle = cpu_cmd[2:0] == 3'b101;	
wire mem_write_cycle = cpu_cmd[2:0] == 3'b110;	
wire io_read_cycle = cpu_cmd[2:0] == 3'b001;	
wire io_write_cycle = cpu_cmd[2:0] == 3'b010;	
wire inta_cycle = cpu_cmd[3:0] == 4'b0000;	

wire io_ready = spi_ready && vga_ready && dbg_ready && ym3812_ready;

always @(negedge cpu_clk_n)
begin
	cpu_ready <= sdram_ready && sram_ready && io_ready && (!cycle_phase0) && (!cycle_phase1);

	c_s <= {cpu_s1_n, cpu_s0_n};
	
	if ((cpu_s1_n == 1'b0) || (cpu_s0_n == 1'b0))
	begin
		// The address is now available
		c_a <= cpu_a;
		c_bhe_n <= cpu_bhe_n;
		
		addr_8bit <= cpu_a;
		
		// Decode CPU address and command
		bios_read <= bios_area & mem_read_cycle;
		vram_read <= vram_area & mem_read_cycle;
		vram_write <= vram_area & mem_write_cycle;
		ram_read <= ram_area & mem_read_cycle;
		ram_write <= ram_area & mem_write_cycle;
		inta <= inta_cycle;

		spi_read <= spi_area & io_read_cycle;
		spi_write <= spi_area & io_write_cycle;
		pit_read <= pit_area & io_read_cycle;
		pit_write <= pit_area & io_write_cycle;
		pic_read <= pic_area & io_read_cycle;
		pic_write <= pic_area & io_write_cycle;
		vga_read <= vga_area & io_read_cycle;
		vga_write <= vga_area & io_write_cycle;
		dbg_write <= dbg_area & io_write_cycle;
		ps2_read <= ps2_area & io_read_cycle;
		ps2_write <= ps2_area & io_write_cycle;
		ym3812_read <= ym3812_area & io_read_cycle;
		ym3812_write <= ym3812_area & io_write_cycle;
		mouse_read <= com1_area & io_read_cycle;
		mouse_write <= com1_area & io_write_cycle;
		
		io_read <= io_read_cycle;
		io_write <= io_write_cycle;
	end
	else if ((c_s[1] == 1'b0) || (c_s[0] == 1'b0))
	begin
		c_d <= cpu_d;
		
		data_8bit <= addr_8bit[0] ? cpu_d[15:8] : cpu_d[7:0];
		
		if (io_read || io_write) // || (vga_planar && c_a[23:16] == 8'h0A))
		begin
			cycle_phase0 <= c_a[0] == 1'b0;
			cycle_phase1 <= cpu_bhe_n == 1'b0;
		end
		
		// Execute CPU's command
		
		if (vram_read) cpu_rdout_sram <= ~cpu_rdout_sram;
		if (vram_write) cpu_wrout_sram <= ~cpu_wrout_sram;
		if (ram_read) cpu_rdout_sdram <= ~cpu_rdout_sdram;
		if (ram_write) cpu_wrout_sdram <= ~cpu_wrout_sdram;

		send_io_request;
	end

	process_bridge;
end

endmodule
