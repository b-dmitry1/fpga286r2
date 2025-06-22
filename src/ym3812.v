module ym3812(
	input wire clk,
	input wire reset_n,

	// CPU interface
	input  wire [11:0] port,
	output wire [7:0] dout,
	input  wire [7:0] din,
	input  wire cpu_iordin,
	output reg  cpu_iordout,
	input  wire cpu_iowrin,
	output reg  cpu_iowrout,

	output reg [7:0] music,
	
	output wire txd
);

wire sram_area        = r_addr[31:28] == 4'h0;
wire uart_area        = r_addr[31:24] == 8'h10;
wire timer_area       = r_addr[31:24] == 8'h11;
wire gpio_area        = r_addr[31:24] == 8'h13;

/*
wire neg1_0;
wire [3:0] value1_0;
wire neg2_0;
wire [3:0] value2_0;
wire play0;
ym3812_osc osc0(
	.clk(clk),
	
	.din(din),
	.wr_An(data_wr && index == 8'hA0),
	.wr_Bn(data_wr && index == 8'hB0),
	
//	input wire [3:0] harmonic1,
//	input wire [3:0] harmonic2,
	
//	input wire [1:0] waveform1,
//	input wire [1:0] waveform2,
	
	.neg1(neg1_0),
	.value1(value1_0),

	.neg2(neg2_0),
	.value2(value2_0),

	.play(play0)
);
*/

reg [15:0] acc;
always @(posedge clk)
begin
	//acc <= 16'd16 + (neg1_0 ? -value1_0 : value1_0);
	//music <= acc[7:0];
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RISC-V UART
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire [31:0] uart_dout;
uart i_uart
(
	.clk   (clk),
	.addr  (r_addr),
	.din   (r_din),
	.dout  (uart_dout),
	.lane  (r_lane),
	.wr    (r_wr),
	.valid (r_valid && uart_area),
	.txd   (txd)
);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RISC-V
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire [31:0] r_addr;
wire [31:0] r_din;
reg  [31:0] r_dout;
wire [ 3:0] r_lane;
wire        r_wr;
wire        r_valid;
reg         r_ready;
riscv_min i_cpu
(
	.clk   (clk),
	.rst   (~reset_n),
	.addr  (r_addr),
	.dout  (r_din),
	.din   (r_dout),
	.lane  (r_lane),
	.wr    (r_wr),
	.valid (r_valid),
	.ready (r_ready)
);

reg last_valid;

reg [31:0] r_timer;
reg [10:0] r_timer_div;

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		r_ready <= 0;
		last_valid <= 0;
		r_timer <= 32'd0;
		r_timer_div <= 11'd0;
	end
	else
	begin
		r_timer_div <= r_timer_div + 1'd1;
		if (r_timer_div[10])
		begin
			r_timer <= r_timer + 1'd1;
			r_timer_div <= 11'd0;
		end

		// Peripherial to CPU data bus
		last_valid <= r_valid;
		if (last_valid && r_valid && ~r_ready)
		begin
			r_dout <=
				sram_area ? sram_dout :
				uart_area ? uart_dout :
				timer_area ? r_timer :
				32'hFFFFFFFF;
		end

		if (r_valid && ~r_ready && r_wr && gpio_area)
			music <= r_din[7:0];
		
		// "Ready" control
		r_ready <= last_valid && r_valid && ~r_ready;
	end
end

//////////////////////////////////////////////////////////////////////////////
// RISC-V ROM / RAM
//////////////////////////////////////////////////////////////////////////////

wire [31:0] sram_dout;
reg sram_wr;
ym3812_firmware i_riscv_sram
(
	.clock   (clk),
	
	.data_a    (r_din),
	.address_a (r_addr[12:2]),
	.wren_a    (r_valid && r_wr && sram_area),
	.byteena_a (r_lane),
	.q_a       (sram_dout),

	.data_b    ({din, din}),
	.address_b ({5'b11111, index[7:1]}),
	.wren_b    (data_wr),
	.byteena_b ({index[0], ~index[0]})
);


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

wire iord = cpu_iordout ^ cpu_iordin;
wire iowr = cpu_iowrout ^ cpu_iowrin;

reg [5:0] iodelay;
always @(posedge clk)
begin
	cpu_iowrout <= cpu_iowrin;

	if (|iodelay)
	begin
		iodelay <= iodelay + 1'd1;
		if (&iodelay)
			cpu_iordout <= cpu_iordin;
	end
	else if (iord)
	begin
		if (port[11:4] == 8'h38)
			iodelay <= 1'd1;
		else
			cpu_iordout <= cpu_iordin;
	end
end

assign dout = {timer1[8] | timer2[8], timer1[8], timer2[8], 5'h0};

reg [7:0] index;

wire addr_wr = iowr && (port == 12'h388);
wire data_wr = iowr && (port == 12'h389);

always @(posedge clk)
begin
	index <= addr_wr ? din : index;
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Timers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

reg [8:0] timer1;
reg [8:0] timer2;

reg timer1_start;
reg timer2_start;

reg timer1_mask;
reg timer2_mask;

reg [13:0] timer_div;

always @(posedge clk)
begin
	timer_div <= timer_div + 14'd1;
	
	timer1 <=
		iowr && (port == 12'h389) && (index == 8'h04) && din[7] ? 9'd0 :
		iowr && (port == 12'h389) && (index == 8'h02) ? {1'b0, din} :
		timer1_start && (&timer_div[11:0]) && (~timer1[8]) ? timer1 + 9'd1 :
		timer1;

	timer1_start <=
		iowr && (port == 12'h389) && (index == 8'h04) && din[6] ? 1'b1 :
		timer1_start && timer1[8] ? 1'b0 :
		timer1_start;
	
	timer1_mask <=
		iowr && (port == 12'h389) && (index == 8'h04) ? din[6] :
		timer1_mask;

	timer2 <=
		iowr && (port == 12'h389) && (index == 8'h04) && din[7] ? 9'd0 :
		iowr && (port == 12'h389) && (index == 8'h03) ? {1'b0, din} :
		timer2_start && (&timer_div[13:0]) && (~timer2[8]) ? timer2 + 9'd1 :
		timer2;

	timer2_start <=
		iowr && (port == 12'h389) && (index == 8'h04) && din[5] ? 1'b1 :
		timer2_start && timer2[8] ? 1'b0 :
		timer2_start;
	
	timer2_mask <=
		iowr && (port == 12'h389) && (index == 8'h04) ? din[5] :
		timer2_mask;
end

endmodule
