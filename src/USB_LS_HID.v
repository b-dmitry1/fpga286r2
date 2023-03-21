module USB_LS_HID(
	input wire clk,
	input wire reset_n,
	
	output reg led,
	
	inout wire dm,
	inout wire dp,
	
	output reg [7:0] shift,
	output reg [7:0] keycode1,
	output reg [7:0] keycode2,
	output reg [7:0] keycode3,
	output reg irq_flip_out,
	input wire irq_flip_in,
	
	input wire keycode_next_flip
);

wire connected;
wire frame_in;
reg frame_out;

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

wire [7:0] byte2;
wire [7:0] byte3;
wire [7:0] byte4;
wire [7:0] byte5;
wire [7:0] byte6;
wire [7:0] byte7;
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
	.last_received_packet_type(last_received_packet_type),
	.byte2(byte2),
	.byte3(byte3),
	.byte4(byte4),
	.byte5(byte5),
	.byte6(byte6),
	.byte7(byte7)
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
	CMD_READ01				= 32'hA0806980,
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
	S_NO_ADDRESS_READ					= 4'd5,
	S_NO_STATUS_READ					= 4'd10,
	S_NO_CONF							= 4'd6,
	S_NO_CONF_READ						= 4'd7,
	S_READY								= 4'd8,
	S_NO_DESCR							= 4'd4,
	S_NO_DESCR_READ1					= 4'd1,
	S_NO_DESCR_READ2					= 4'd2,
	S_NO_DESCR_READ3					= 4'd3;

reg [3:0] state;

reg [7:0] last2;
reg [7:0] last3;
reg [7:0] last4;
reg [7:0] last5;

reg [9:0] counter;

reg [3:0] packet;

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		state <= S_NO_ADDRESS;
	end
	else
	begin
		if (!connected)
		begin
			state <= S_NO_ADDRESS;
		end
		else if (frame_in != frame_out)
		begin
			frame_out <= ~frame_out;
			//if (state != S_READY && counter[9])
			//begin
			//	state <= S_NO_ADDRESS;
			//end
			//else
			
			// if (state == S_READY) led <= ~led;
			
			begin
				counter <= counter + 1'd1;
				case (state)
					S_NO_DESCR:
					begin
						send_out <= ~send_out;
						send_ctrl <= CMD_SETUP0;
						send_ctrl_size <= SZ_SETUP0;
						send_data <= CMD_GET_DESCR;
						send_data_size <= SZ_SET_CONF;
					end
					S_NO_DESCR_READ1, S_NO_DESCR_READ2, S_NO_DESCR_READ3:
					begin
						send_out <= ~send_out;
						send_ctrl <= CMD_READ0;
						send_ctrl_size <= SZ_READ0;
						send_data <= CMD_NONE;
						send_data_size <= SZ_NONE;
					end
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
					S_NO_STATUS_READ:
					begin
						send_out <= ~send_out;
						send_ctrl <= CMD_READ1;
						send_ctrl_size <= SZ_READ1;
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
						packet <= packet + 1'd1;
						//if (packet == 4'd8)
						begin
							send_out <= ~send_out;
							send_ctrl <= CMD_READ1;
							send_ctrl_size <= SZ_READ1;
							send_data <= CMD_NONE;
							send_data_size <= SZ_NONE;
						end
					end
				endcase
			end
		end
		
		if (recv_in != recv_out)
		begin
			recv_out <= ~recv_out;
			if (last_received_packet_type == R_ACK)
			begin
				counter <= 10'd0;
				case (state)
					S_NO_ADDRESS:
					begin
						state <= S_NO_ADDRESS_READ;
					end
					S_NO_DESCR:
					begin
						state <= S_NO_DESCR_READ1;
					end
					S_NO_CONF:
					begin
						state <= S_READY;//S_NO_CONF_READ;
					end
				endcase
			end
			if (last_received_packet_type == R_NAK)
			begin
				counter <= 10'd0;
				case (state)
					S_READY:
					begin
						//led <= ~led;
					end
				endcase
			end
			else if (last_received_packet_type == R_DATA0 || last_received_packet_type == R_DATA1)
			begin				
				counter <= 10'd0;
				led <= ~led;
				case (state)
					S_NO_ADDRESS_READ:
					begin
						state <= S_NO_CONF;
					end
					S_NO_STATUS_READ:
					begin
						state <= S_NO_CONF;
					end
					S_NO_DESCR_READ1:
					begin
						state <= S_NO_DESCR_READ2;
					end
					S_NO_DESCR_READ2:
					begin
						state <= S_NO_DESCR_READ3;
					end
					S_NO_DESCR_READ3:
					begin
						state <= S_NO_ADDRESS;
					end
					S_NO_CONF_READ:
					begin
						state <= S_READY;
					end
					S_READY:
					begin
						led <= ~led;
						last2 <= byte2;
						last3 <= byte3;
						last4 <= byte4;
						last5 <= byte5;
						
						shift <= byte2;
						
						keycode1 <= byte4;
						keycode2 <= byte5;
						keycode3 <= byte6;
					end
				endcase
			end
		end
	end
end

endmodule
