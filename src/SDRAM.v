module SDRAM(
	input wire clk,
	input wire clk1,
	input wire reset_n,

	output wire ready,
	output wire cpu_addr_hit,
	
	input wire [23:0] cpu_addr,
	input wire cpu_bhe_n,
	input wire [15:0] cpu_din,
	output wire [15:0] cpu_dout,
	input wire cpu_rdin,
	output reg cpu_rdout,
	input wire cpu_wrin,
	output reg cpu_wrout,

	output reg [12:0] a,
	output reg [1:0] ba,
	output reg [1:0] dqm,
	inout wire [15:0] d,
	output wire ras_n,
	output wire cas_n,
	output wire we_n,
	output wire cs_n,
	output wire sclk,
	output reg scke
);

assign d =
	state == S_WRITE_CPU ? cpu_din :
	16'hZZZZ;

reg [23:2] cpu_data_addr;
reg [31:0] cpu_data;
reg cpu_data_valid;

assign cpu_dout =
	cpu_addr[1] == 1'b0 ? cpu_data[15:0] :
	cpu_data[31:16];

assign cpu_addr_hit = (cpu_data_addr == cpu_addr[23:2]) && cpu_data_valid;

reg [19:0] start;
reg start1, start2, start3;
always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
		start <= 20'd0;
	else
		start <= start[19] ? start : start + 20'd1;
end
always @(posedge clk)
begin
	start3 = start[19];
	start2 = |start[19:18];
	start1 = |start[19:17];
end

localparam S_START 						= 0;
localparam S_IDLE 						= 1;
localparam S_PRECHARGE		 			= 2;
localparam S_LOADMODE 					= 3;
localparam S_READ_CPU					= 4;
localparam S_READ_CPU_1					= 5;
localparam S_READ_CPU_2					= 6;
localparam S_READ_CPU_3					= 7;
localparam S_WRITE_CPU					= 8;
localparam S_WRITE_CPU_1				= 9;
localparam S_WRITE_CPU_2				= 10;
localparam S_REFRESH 					= 11;
localparam S_REFRESH_1 					= 12;
localparam S_REFRESH_2 					= 13;
localparam S_REFRESH_3 					= 14;
localparam S_REFRESH_DONE 				= 15;

												//   SRCW
localparam NOP								= 4'b0000;
localparam PRECHARGE						= 4'b1101;
localparam REFRESH						= 4'b1110;
localparam LOADMODE						= 4'b1111;
localparam ACTIVE							= 4'b1100;
localparam READ							= 4'b1010;
localparam WRITE							= 4'b1011;

reg [4:0] state;

reg [9:0] refresh;

reg [3:0] cmd;

assign sclk = clk1;

assign cs_n = ~cmd[3];
assign ras_n = ~cmd[2];
assign cas_n = ~cmd[1];
assign we_n = ~cmd[0];

reg [13:0] row;
reg row_active;

assign ready = (cpu_rdin == cpu_rdout) && (cpu_wrin == cpu_wrout);

always @(posedge clk)
begin
	scke <= start1;
	
	refresh <= state == S_REFRESH ? 10'd0 : refresh + 10'd1;
end

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		state <= S_START;
	end
	else
	begin
		case (state)
			S_START:
			begin
				cmd <= NOP;
				ba <= 2'b00;
				if (start2)
					state <= S_IDLE;
				cpu_data_valid <= 1'b0;
				row_active <= 1'b0;
			end
			S_IDLE:
			begin
				if (~start3)
				begin
				end
				else if (refresh[8])
				begin
					cmd <= PRECHARGE;
					a <= 13'h400;
					ba <= 2'b00;
					row_active <= 1'b0;
					state <= S_REFRESH;
				end
				else if (cpu_rdin ^ cpu_rdout)
				begin
					dqm <= 2'b00;
					if (row_active)
					begin
						if (row == cpu_addr[23:10])
						begin
							state <= S_READ_CPU;
						end
						else
						begin
							cmd <= PRECHARGE;
							a <= 13'h400;
							ba <= 2'b00;
							row_active <= 1'b0;
						end
					end
					else
					begin
						cmd <= ACTIVE;
						a <= cpu_addr[21:10];
						ba <= cpu_addr[23:22];
						row <= cpu_addr[23:10];
						row_active <= 1'b1;
						state <= S_READ_CPU;
					end
				end
				else if (cpu_wrin ^ cpu_wrout)
				begin
					dqm[0] <= cpu_addr[0];
					dqm[1] <= cpu_bhe_n;
					if (row_active)
					begin
						if (row == cpu_addr[23:10])
						begin
							state <= S_WRITE_CPU;
						end
						else
						begin
							cmd <= PRECHARGE;
							a <= 13'h400;
							ba <= 2'b00;
							row_active <= 1'b0;
						end
					end
					else
					begin
						cmd <= ACTIVE;
						a <= cpu_addr[21:10];
						ba <= cpu_addr[23:22];
						row <= cpu_addr[23:10];
						row_active <= 1'b1;
						state <= S_WRITE_CPU;
					end
				end
			end
			S_REFRESH:
			begin
				cmd <= REFRESH;
				state <= S_REFRESH_1;
			end
			S_REFRESH_1:
			begin
				cmd <= NOP;
				state <= S_REFRESH_2;
			end
			S_REFRESH_2:
				state <= S_REFRESH_3;
			S_REFRESH_3:
				state <= S_REFRESH_DONE;
			S_REFRESH_DONE:
			begin
				cmd <= LOADMODE;
				a <= 13'h220;
				ba <= 2'b00;
				state <= S_LOADMODE;
			end
			S_LOADMODE:
			begin
				cmd <= NOP;
				state <= S_IDLE;
			end
			S_READ_CPU:
			begin
				cmd <= READ;
				a <= {4'b00, cpu_addr[9:2], 1'b0};
				ba <= cpu_addr[23:22];
				state <= S_READ_CPU_1;
			end
			S_READ_CPU_1:
			begin
				a <= {4'b00, cpu_addr[9:2], 1'b1};
				state <= S_READ_CPU_2;
			end
			S_READ_CPU_2:
			begin
				cmd <= NOP;
				cpu_data[15:0] <= d[15:0];
				state <= S_READ_CPU_3;
			end
			S_READ_CPU_3:
			begin
				cpu_data_addr <= cpu_addr[23:2];
				cpu_data[31:16] <= d[15:0];
				cpu_data_valid <= 1'b1;
				cpu_rdout <= ~cpu_rdout;
				state <= S_IDLE;
			end
			S_WRITE_CPU:
			begin
				if (cpu_addr[23:2] == cpu_data_addr)
				begin
					cpu_data[7:0] <= (cpu_addr[1] == 1'b0) && (cpu_addr[0] == 1'b0) ? cpu_din[7:0] : cpu_data[7:0];
					cpu_data[15:8] <= (cpu_addr[1] == 1'b0) && (cpu_bhe_n == 1'b0) ? cpu_din[15:8] : cpu_data[15:8];
					cpu_data[23:16] <= (cpu_addr[1] == 1'b1) && (cpu_addr[0] == 1'b0) ? cpu_din[7:0] : cpu_data[23:16];
					cpu_data[31:24] <= (cpu_addr[1] == 1'b1) && (cpu_bhe_n == 1'b0) ? cpu_din[15:8] : cpu_data[31:24];
				end
				cmd <= WRITE;
				a <= {4'b00, cpu_addr[9:1]};
				state <= S_WRITE_CPU_1;
			end
			S_WRITE_CPU_1:
			begin
				cmd <= NOP;
				dqm <= 2'b00;
				cpu_wrout <= ~cpu_wrout;
				state <= S_IDLE;
			end
			default:
				state <= S_START;
		endcase
	end
end

endmodule
