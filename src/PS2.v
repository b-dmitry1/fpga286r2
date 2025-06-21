module PS2(
	input wire clk,
	input wire reset_n,
	
	// RISC-V interface
	input  wire [ 9:0] r_addr,
	input  wire [31:0] r_din,
	output reg  [31:0] r_dout,
	input  wire [ 3:0] r_lane,
	input  wire        r_wr,
	input  wire        r_valid,
	output reg         r_ready,

	// CPU interface
	input wire [11:0] port,
	output reg [7:0] dout,
	input wire [7:0] din,
	input wire cpu_iordin,
	output reg cpu_iordout,
	input wire cpu_iowrin,
	output reg cpu_iowrout,

	output reg irq1,

	input  wire [1:0] toggle
);

reg   [7:0] buffer [0:15];
reg   [3:0] rp;
reg   [3:0] wp;
reg   [4:0] count;

wire iord = cpu_iordout ^ cpu_iordin;
wire iowr = cpu_iowrout ^ cpu_iowrin;

reg cs_60h;
reg cs_61h;

always @(negedge clk)
begin
	cs_60h <= port == 12'h060;
	cs_61h <= port == 12'h061;
end

wire [3:0] wp_next;
assign wp_next = wp + 1'd1;

always @(posedge clk)
begin
	cpu_iordout <= cpu_iordin;
	cpu_iowrout <= cpu_iowrin;

	case (port[2:0])
		3'd1: dout <= {2'b00, toggle, 4'b0001};
		3'd2, 3'd3: dout <= 8'hFD;
		3'd4: dout <= {7'b0001110, rp != wp};
		default: dout <= buffer[rp];
	endcase

	irq1 <= rp != wp;

	r_ready <= 1'b0;
	
	if (cs_61h && iowr && ~din[7])
	begin
		if (rp != wp)
			rp <= rp + 1'd1;
	end
	else if (r_valid)
	begin
		r_ready <= 1'b1;
		if (r_valid & ~r_ready)
		begin
			buffer[wp] <= r_din[7:0];
			wp <= wp + 1'd1;
			if (wp_next == rp)
				rp <= rp + 1'd1;
		end
	end
end

endmodule
