module USB_LS_HID(
	input wire clk,
	input wire reset_n,
	
	output reg led,
	
	inout wire dm,
	inout wire dp
);

wire connected;
wire frame_in;

wire send_in;
reg send_out;
reg [31:0] send_ctrl;
reg [5:0] send_ctrl_size;
reg [95:0] send_data;
reg [6:0] send_data_size;

wire recv_in;
reg recv_out;
wire [95:0] recv_data;

wire phy_led;
wire [7:0] last_received_packet_type;

USB_LS_PHY phy(
	.clk(clk),
	.reset_n(reset_n),
	
	.dm(dm),
	.dp(dp),
	
	.led(phy_led),

	.connected(connected),
	
	.frame_out(frame_in),

	.send_in(send_out),
	.send_out(send_in),
	.send_data(send_data),
	.send_data_size(send_data_size),
	.send_ctrl(send_ctrl),
	.send_ctrl_size(send_ctrl_size),

	.recv_out(recv_in),
	.recv_data(recv_data),
	.last_received_packet_type(last_received_packet_type)
);

localparam
	R_ACK						= 8'hD2,
	R_NAK						= 8'h5A,
	R_STALL					= 8'h1E,
	R_DATA0					= 8'hC3,
	R_DATA1					= 8'h4B;

localparam
	CMD_SETUP0				= 32'h10002D80,
	CMD_SET_ADDRESS		= 96'h25EB0000_00000001_0500C380,
	CMD_SETUP1				= 32'hE8012D80,
	CMD_SET_CONF			= 96'h25270000_00000001_0900C380,
	CMD_READ0				= 32'h10006980,
	CMD_READ10				= 32'hE8016980,
	CMD_READ1				= 32'h58816980,
	CMD_GET_DESCR			= 96'hF4E00012_00000100_0680C380,
	CMD_NONE					= 96'h0,
	CMD_ACK					= 16'hD280;

localparam
	SZ_SETUP0				= 6'd32,
	SZ_SET_ADDRESS			= 7'd96,
	SZ_SETUP1				= 6'd32,
	SZ_SET_CONF				= 7'd96,
	SZ_READ0					= 6'd32,
	SZ_READ10				= 6'd32,
	SZ_READ1					= 6'd32,
	SZ_NONE					= 7'd0,
	SZ_ACK					= 6'd16;

localparam
	S_NO_ADDRESS						= 4'd0,
	S_NO_ADDRESS_READ					= 4'd1,
	S_NO_CONF							= 4'd2,
	S_NO_CONF_READ						= 4'd3,
	S_READY								= 4'd4;

reg [3:0] state;

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		state <= S_NO_ADDRESS;
	end
	else
	begin
		if (send_in == send_out)
		begin
			case (state)
				S_NO_ADDRESS:
				begin
					send_out <= ~send_out;
					send_ctrl <= CMD_SETUP0;
					send_ctrl_size <= SZ_SETUP0;
					send_data <= CMD_SET_ADDRESS;
					send_data_size <= SZ_SET_ADDRESS;
				end
				S_NO_ADDRESS_READ:
				begin
					send_out <= ~send_out;
					send_ctrl <= CMD_READ0;
					send_ctrl_size <= SZ_READ0;
					send_data <= CMD_NONE;
					send_data_size <= SZ_NONE;
				end
				S_NO_CONF:
				begin
					send_out <= ~send_out;
					send_ctrl <= CMD_SETUP1;
					send_ctrl_size <= SZ_SETUP1;
					send_data <= CMD_SET_CONF;
					send_data_size <= SZ_SET_CONF;
				end
				S_NO_CONF_READ:
				begin
					send_out <= ~send_out;
					send_ctrl <= CMD_READ10;
					send_ctrl_size <= SZ_READ10;
					send_data <= CMD_NONE;
					send_data_size <= SZ_NONE;
				end
				S_READY:
				begin
					send_out <= ~send_out;
					send_ctrl <= CMD_READ1;
					send_ctrl_size <= SZ_READ1;
					send_data <= CMD_NONE;
					send_data_size <= SZ_NONE;
				end
			endcase
		end
		
		if (recv_in != recv_out)
		begin
			recv_out <= ~recv_out;
			if (last_received_packet_type == R_ACK)
			begin
				case (state)
					S_NO_ADDRESS:
					begin
						state <= S_NO_ADDRESS_READ;
					end
					S_NO_ADDRESS_READ:
					begin
						state <= S_NO_CONF;
					end
					S_NO_CONF:
					begin
						state <= S_NO_CONF_READ;
					end
					S_NO_CONF_READ:
					begin
						state <= S_READY;
					end
				endcase
			end
			else if (last_received_packet_type == R_DATA0 || last_received_packet_type == R_DATA1)
			begin				
				case (state)
					S_NO_ADDRESS_READ:
					begin
						state <= S_NO_CONF;
					end
					S_NO_CONF_READ:
					begin
						state <= S_READY;
					end
					S_READY:
					begin
						led <= ~led;
					end
				endcase
			end
		end
	end
end

endmodule
