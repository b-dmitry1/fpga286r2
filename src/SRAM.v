module SRAM(
	input wire clk,

	output wire ready,
	
	input wire [23:0] cpu_addr,
	input wire cpu_bhe_n,
	input wire [15:0] cpu_din,
	output reg [15:0] cpu_dout,
	input wire cpu_rdin,
	output reg cpu_rdout,
	input wire cpu_wrin,
	output reg cpu_wrout,

	input wire [23:0] gpu_addr,
	input wire [31:0] gpu_din,
	output reg [31:0] gpu_dout,
	input wire gpu_rdin,
	output reg gpu_rdout,
	input wire gpu_wrin,
	output reg gpu_wrout,
	
	input wire [23:0] video_addr,
	output reg [63:0] video_dout,

	output reg [17:0] a,
	inout reg [15:0] d,
	output wire cs_n,
	output wire we_n,
	output wire oe_n,
	output reg lb_n,
	output reg ub_n
);

parameter S_IDLE			 		= 1 << 0;
parameter S_READ_CPU	   		= 1 << 1;
parameter S_WRITE_CPU   		= 1 << 2;
parameter S_WRITE_CPU_1   		= 1 << 3;
parameter S_READ_GPU_0   		= 1 << 5;
parameter S_READ_GPU_1   		= 1 << 6;
parameter S_READ_GPU_2   		= 1 << 7;
parameter S_WRITE_GPU_0			= 1 << 8;
parameter S_WRITE_GPU_1			= 1 << 9;
parameter S_READ_VIDEO_0  		= 1 << 10;
parameter S_READ_VIDEO_1  		= 1 << 11;
parameter S_READ_VIDEO_2  		= 1 << 12;
parameter S_READ_VIDEO_3  		= 1 << 13;
parameter S_READ_VIDEO_4  		= 1 << 14;

reg [14:0] state;

reg [18:3] cur_video_addr;

reg cs;
reg oe;
reg we;

assign ready = ~((cpu_rdin ^ cpu_rdout) | (cpu_wrin ^ cpu_wrout));

assign oe_n = ~oe;
assign we_n = ~we;
assign cs_n = ~cs;

reg video_needs_data;

always @(posedge clk)
begin
	video_needs_data <= video_addr[18:3] != cur_video_addr;
end

reg delay;

always @(posedge clk)
begin
	delay <= 1'b1;//(cpu_wrin ^ cpu_wrout) || (cpu_rdin ^ cpu_rdout);
	case (state)
		S_IDLE:
			if (video_needs_data)
			begin
				a <= {video_addr[18:3], 2'b00};
				d <= 16'hZZZZ;
				cs <= 1'b1;
				oe <= 1'b1;
				we <= 1'b0;
				lb_n <= 1'b0;
				ub_n <= 1'b0;
				state <= S_READ_VIDEO_0;
			end
			//else if (gpu_wrin ^ gpu_wrout)
				//state <= S_WRITE_GPU_0;
			//else if (gpu_rdin ^ gpu_rdout)
				//state <= S_READ_GPU_0;
			else if ((cpu_wrin ^ cpu_wrout) && delay)
			begin
				a <= cpu_addr[18:1];
				d <= cpu_din;
				cs <= 1'b0;
				oe <= 1'b0;
				we <= 1'b1;
				lb_n <= cpu_addr[0];
				ub_n <= cpu_bhe_n;
				state <= S_WRITE_CPU;
			end
			else if ((cpu_rdin ^ cpu_rdout) && delay)
			begin
				a <= cpu_addr[18:1];
				d <= 16'hZZZZ;
				cs <= 1'b1;
				oe <= 1'b1;
				we <= 1'b0;
				lb_n <= 1'b0;
				ub_n <= 1'b0;
				state <= S_READ_CPU;
			end
		S_READ_CPU:
		begin
			cpu_rdout <= ~cpu_rdout;
			cpu_dout <= d;
			cs <= 1'b0;
			oe <= 1'b0;
			state <= S_IDLE;
		end
		S_WRITE_CPU:
		begin
			cs <= 1'b1;
			state <= S_WRITE_CPU_1;
		end
		S_WRITE_CPU_1:
		begin
			cpu_wrout <= ~cpu_wrout;
			d <= 16'hZZZZ;
			cs <= 1'b0;
			we <= 1'b0;
			state <= S_IDLE;
		end
		S_READ_GPU_0:
			state <= S_READ_GPU_1;
		S_READ_GPU_1:
			state <= S_READ_GPU_2;
		S_READ_GPU_2:
			state <= S_IDLE;
		S_WRITE_GPU_0:
			state <= S_WRITE_GPU_1;
		S_WRITE_GPU_1:
			state <= S_IDLE;
		S_READ_VIDEO_0:
		begin
			a <= {video_addr[18:3], 2'b01};
			video_dout[15:0] <= d;
			state <= S_READ_VIDEO_1;
		end
		S_READ_VIDEO_1:
		begin
			a <= {video_addr[18:3], 2'b10};
			video_dout[31:16] <= d;
			state <= S_READ_VIDEO_2;
		end
		S_READ_VIDEO_2:
		begin
			a <= {video_addr[18:3], 2'b11};
			video_dout[47:32] <= d;
			state <= S_READ_VIDEO_3;
		end
		S_READ_VIDEO_3:
		begin
			cur_video_addr <= video_addr[18:3];
			video_dout[63:48] <= d;
			cs <= 1'b0;
			oe <= 1'b0;
			state <= S_IDLE;
		end
		default:
			state <= S_IDLE;
	endcase
end

endmodule
