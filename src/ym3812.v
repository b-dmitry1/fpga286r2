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

	output reg [7:0] music
);

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

// Registers
always @(posedge clk)
begin
	index <= addr_wr ? din : index;
	
	if (data_wr)
		music <= music + 8'd32;
end

// Timers
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
