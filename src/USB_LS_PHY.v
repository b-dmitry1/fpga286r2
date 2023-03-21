module USB_LS_PHY(
	input wire clk,
	input wire reset_n,
	
	inout reg dm,
	inout reg dp,

	output reg led,
	
	output reg connected,
	
	output reg frame_out,

	input wire send_in,
	output reg send_out,
	input wire [31:0] send_ctrl,
	input wire [5:0] send_ctrl_size,
	input wire [95:0] send_data,
	input wire [6:0] send_data_size,

	output reg recv_out,
	output reg [95:0] recv_data,
	output reg [6:0] recv_size,
	output reg [7:0] last_received_packet_type,
	
	output reg [7:0] byte2,
	output reg [7:0] byte3,
	output reg [7:0] byte4,
	output reg [7:0] byte5,
	output reg [7:0] byte6,
	output reg [7:0] byte7
);

localparam
	S_NODEVICE				= 4'd0,
	S_DEBOUNCE				= 4'd1,
	S_RESET					= 4'd2,
	S_IDLE					= 4'd3,
	S_SEND					= 4'd4,
	S_START0					= 4'd5,
	S_START1					= 4'd6,
	S_START2					= 4'd7,
	S_STOP0					= 4'd8,
	S_STOP1					= 4'd9,
	S_STOP2					= 4'd10,
	S_RECEIVE_SYNC			= 4'd11,
	S_RECEIVE				= 4'd12;

localparam
	R_ACK						= 8'hD2,
	R_NAK						= 8'h5A,
	R_STALL					= 8'h1E,
	R_DATA0					= 8'hC3,
	R_DATA1					= 8'h4B;

reg [3:0] state;
reg send_data_after_ctrl;

reg [19:0] timer;
reg timer_exp;

reg [3:0] phase;
reg [3:0] errors;
reg [2:0] ones;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Packet data
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
reg [95:0] data;
reg flip;
reg [6:0] bits;
reg [7:0] response_timeout;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Bit and frame timer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
reg [15:0] frame_timer;
reg frame, prev_frame;
reg [5:0] div33;
reg bit_clk;
reg fast;
reg dmi;
reg dpi;
always @(negedge bit_clk)
begin
	timer_exp <= timer == 20'd0;
	dmi <= dm;
	dpi <= dp;
end

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		state <= S_NODEVICE;
		dm <= 1'bZ;
		dp <= 1'bZ;
		connected <= 1'b0;
	end
	else
	begin
		// Variable bit clock
		if (fast)
		begin
			// Waiting response - sample faster to synchronize with the device
			div33 <= div33 == 6'd7 ? 6'd0 : div33 + 1'd1;
		end
		else
		begin
			div33 <= div33 == 6'd32 ? 6'd0 : div33 + 1'd1;
		end
		bit_clk <= div33 == 6'd6;
		
		frame_timer <= frame_timer == 16'd49999 ? 16'd0 : frame_timer + 1'd1;
		frame <= frame_timer == 16'd49999 ? frame + 1'd1 : frame;
		
		if (bit_clk)
		begin
			timer <= timer == 20'd0 ? timer : timer - 1'd1;

			if (timer_exp)
			begin
				case (state)
					S_NODEVICE:
					begin
						connected <= 1'b0;
						dm <= 1'bZ;
						dp <= 1'bZ;
						errors <= 4'd0;
						if ({dmi, dpi} == 2'b10)
						begin
							state <= S_DEBOUNCE;
						end
						// Check 2 times per second
						timer <= 20'd750000;
					end
					S_DEBOUNCE:
					begin
						dm <= 1'b0;
						dp <= 1'b0;
						state <= S_RESET;
						// 20 ms reset
						timer <= 20'd30000;
						send_out <= send_in;
					end
					S_RESET:
					begin
						dm <= 1'bZ;
						dp <= 1'bZ;
						state <= S_IDLE;
						timer <= 20'd100;
					end
					S_START0:
					begin
						dm <= 1'b0;
						dp <= 1'b0;
						state <= S_START1;
					end
					S_START1:
					begin
						dm <= 1'b0;
						dp <= 1'b0;
						state <= S_START2;
					end
					S_START2:
					begin
						dm <= 1'b1;
						dp <= 1'b0;
						timer <= 20'd7;
						frame_out <= ~frame_out;
						ones <= 3'd0;
						
						if (send_in != send_out)
						begin
							data <= send_ctrl;
							bits <= send_ctrl_size;
							state <= S_SEND;
							send_data_after_ctrl <= send_data_size != 7'd0;
						end
						else
						begin
							state <= S_IDLE;
						end
					end
					S_SEND:
					begin
						if (ones == 3'd6)
						begin
							flip <= ~flip;
							dm <= flip;
							dp <= ~flip;
							ones <= 3'd0;
						end
						else if (|bits)
						begin
							bits <= bits - 1'd1;
							
							if (data[0])
							begin
								ones <= ones + 1'd1;
							end
							else
							begin
								flip <= ~flip;
								dm <= flip;
								dp <= ~flip;
								ones <= 3'd0;
							end
							
							data <= {1'b0, data[95:1]};
						end
						else
						begin
							dm <= 1'b0;
							dp <= 1'b0;
							state <= S_STOP0;
						end
					end
					S_STOP0:
					begin
						dm <= 1'b0;
						dp <= 1'b0;
						state <= S_STOP1;
					end
					S_STOP1:
					begin
						dm <= 1'b1;
						dp <= 1'b0;
						state <= S_STOP2;
					end
					S_STOP2:
					begin
						dm <= 1'bZ;
						dp <= 1'bZ;
						flip <= 1'b0;
						ones <= 3'd0;
						send_out <= ~send_out;
						send_data_after_ctrl <= 1'b0;
						if (send_data_after_ctrl)
						begin
							data <= send_data;
							bits <= send_data_size;
							state <= S_SEND;
							timer <= 20'd0;
						end
						else
						begin
							fast <= 1'b1;
							state <= S_IDLE;
						end
					end
					S_RECEIVE_SYNC:
					begin
						dm <= 1'bZ;
						dp <= 1'bZ;
						flip <= 1'b1;
						fast <= 1'b0;
						ones <= 3'd0;
						state <= S_RECEIVE;
					end
					S_RECEIVE:
					begin
						response_timeout <= response_timeout + 1'd1;
						if ((&response_timeout) || (bits >= 7'd120))
						begin
							state <= S_IDLE;
						end
						else if ({dmi, dpi} == 2'b00)
						begin
							recv_data <= data;
							recv_size <= bits;
							recv_out <= ~recv_out;
							flip <= 1'b0;
							ones <= 3'd0;
							
							if (last_received_packet_type == R_STALL)
							begin
								// Something goes wrong. Let's re-initialize the device
								state <= S_NODEVICE;
							end
							else if (last_received_packet_type == R_DATA0 || last_received_packet_type == R_DATA1)
							begin
								led <= ~led;
								data <= 16'hD280;
								bits <= 6'd16;
								state <= S_SEND;
								timer <= 20'd3;
							end
							else
							begin
								state <= S_IDLE;
							end
						end
						else
						begin
							if (ones == 3'd6)
							begin
								ones <= 3'd0;
							end
							else if (dmi == flip)
							begin
								data <= {1'b1, data[95:1]};
								bits <= bits + 1'd1;
								if (bits <= 7'd16)
									last_received_packet_type <= {1'b1, last_received_packet_type[7:1]};
								if (bits <= 7'd24)
									byte2 <= {1'b1, byte2[7:1]};
								if (bits <= 7'd32)
									byte3 <= {1'b1, byte3[7:1]};
								if (bits <= 7'd40)
									byte4 <= {1'b1, byte4[7:1]};
								if (bits <= 7'd48)
									byte5 <= {1'b1, byte5[7:1]};
								if (bits <= 7'd56)
									byte6 <= {1'b1, byte6[7:1]};
								if (bits <= 7'd64)
									byte7 <= {1'b1, byte7[7:1]};
								ones <= ones + 1'd1;
							end
							else
							begin
								data <= {1'b0, data[95:1]};
								bits <= bits + 1'd1;
								if (bits <= 7'd16)
									last_received_packet_type <= {1'b0, last_received_packet_type[7:1]};
								if (bits <= 7'd24)
									byte2 <= {1'b0, byte2[7:1]};
								if (bits <= 7'd32)
									byte3 <= {1'b0, byte3[7:1]};
								if (bits <= 7'd40)
									byte4 <= {1'b0, byte4[7:1]};
								if (bits <= 7'd48)
									byte5 <= {1'b0, byte5[7:1]};
								if (bits <= 7'd56)
									byte6 <= {1'b0, byte6[7:1]};
								if (bits <= 7'd64)
									byte7 <= {1'b0, byte7[7:1]};
								ones <= 3'd0;
							end
							flip <= dmi;
						end
					end
					S_IDLE:
					begin
						// Usually, we're listening here at 4x frequency to find a start bit
						connected <= 1'b1;
						response_timeout <= 8'd0;
						ones <= 3'd0;
						
						if ({dmi, dpi} == 2'b00)
						begin
							errors <= errors + 1'd1;
							if (&errors)
								state <= S_NODEVICE;
						end
						else
						begin
							errors <= 4'd0;
						end
						
						if (frame != prev_frame)
						begin
							prev_frame <= frame;
							fast <= 1'b0;
							state <= S_START0;
						end
						else if ({dmi, dpi} == 2'b01)
						begin
							bits <= 7'd0;
							state <= S_RECEIVE_SYNC;
						end

						flip <= 1'b0;
						dm <= 1'bZ;
						dp <= 1'bZ;
					end

					default:
						state <= S_NODEVICE;					
				endcase
			end
		end
	end
end

endmodule
