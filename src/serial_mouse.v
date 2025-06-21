module serial_mouse(
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

	output reg irq4
);

reg   [7:0] buffer [0:15];
reg   [3:0] rp;
reg   [3:0] wp;
reg   [4:0] count;

wire iord = cpu_iordout ^ cpu_iordin;
wire iowr = cpu_iowrout ^ cpu_iowrin;

reg cs_3f8;
reg cs_3fc;

always @(negedge clk)
begin
	cs_3f8 <= port == 12'h3F8;
	cs_3fc <= port == 12'h3FC;
end

wire [3:0] wp_next;
assign wp_next = wp + 1'd1;

reg [7:0] r8250 [0:7];

always @*
begin
	case (port[2:0])
		3'd0: dout <= r8250[0];
		3'd1: dout <= r8250[1];
		3'd2: dout <= r8250[2];
		3'd3: dout <= r8250[3];
		3'd4: dout <= r8250[4];
		3'd5: dout <= r8250[5];
		3'd6: dout <= r8250[6];
		default: dout <= r8250[7];
	endcase
end

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		rp <= 4'd0;
		wp <= 4'd0;
	end
	else
	begin
		cpu_iordout <= cpu_iordin;
		cpu_iowrout <= cpu_iowrin;
		
		r8250[5][0] <= 1'b1;
		
		if (iord)
		begin
			case (port[2:0])
				3'd0: r8250[0] <= buffer[rp];
			endcase
		end
		
		if (iowr && (port[11:3] == 9'b1111111))
			r8250[port[2:0]] <= din;
		
		irq4 <= rp != wp;

		r_ready <= 1'b0;
		
		if (cs_3fc && iowr)
		begin
			rp <= 3'd0;
			wp <= 3'd6;
			buffer[0] <= 8'h4D;
			buffer[1] <= 8'h4D;
			buffer[2] <= 8'h4D;
			buffer[3] <= 8'h4D;
			buffer[4] <= 8'h4D;
			buffer[5] <= 8'h4D;
		end
		else if (cs_3f8 && iord)
		begin
			if (rp != wp)
				rp <= rp + 1'd1;
		end
		else if (r_valid)
		begin
			r_ready <= 1'b1;
			if (r_valid & ~r_ready)
			begin
				if (wp_next != rp)
				begin
					buffer[wp] <= r_din[7:0];
					wp <= wp + 1'd1;
				end
			end
		end
	end
end

endmodule
