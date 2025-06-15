module usb_phy(
	input  wire clk,
	input  wire clk60m,
	input  wire reset_n,
	
	input  wire [ 9:0] addr,
	input  wire [31:0] din,
	output reg  [31:0] dout,
	input  wire [ 3:0] lane,
	input  wire        wr,
	input  wire        valid,
	output reg         ready,
	
	inout  reg  dm,
	inout  reg  dp,

	output reg  connected,
	output reg  full_speed
);

// Memory / MMIO map:
// Address  Size    Area
// 0x000    256     USB RAM
// 0x200    4       CTRL1
// 0x204    4       CTRL2

// USB RAM may be used as a regular RAM
// It is not supports 16/32 byte accesses, only 8 bit reads/writes are allowed

// CTRL1:
// Bits   Type        Desc
// 0-7    Read-only   USB PHY's current RAM address
// 16     Read-only   Device connected flag
// 17     Read-only   Full speed (0 - 1.5 Mbit/s, 1 - 12 Mbit/s)
// 18     Write-only  Force USB reset
// 19     Write-only  Trigger USB transfer
// 20     Read-only   PHY is in idle state and ready to transmit/receive
// 21     Read-only   Odd frame (toggles every 1 ms)
// 22     Read-only   Frame end (do not start new transfers flag)

// CTRL2:
// Bits   Type        Desc
// 0-7    Read/write  Transmitter's packet start address in RAM
// 8-15   Read/write  Transmitter's packet end address in RAM
// 16-23  Read/write  Receivers's packet start address in RAM
// 24-31  Read-only   Receivers's packet end address in RAM

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
	S_RECEIVE				= 4'd12,
	S_RECEIVE_ACK			= 4'd13;

reg  [ 3:0] state;

wire  [7:0] ram_q_a;
reg   [7:0] ram_addr;
reg         ram_write;
wire  [7:0] ram_q;
usbram i_ram(
	.clock_a   (~clk),
	.address_a (addr[7:0]),
	.data_a    (din[7:0]),
	.wren_a    (wr & valid & ~ready & ~addr[9]),
	.q_a       (ram_q_a),

	.clock_b   (clk60m),
	.address_b (ram_addr),
	.data_b    (data[7:0]),
	.wren_b    (ram_write),
	.q_b       (ram_q)
);

reg  [ 2:0] force_reset;
reg         tx_toggle_cpu;
reg         tx_toggle_usb;
reg  [ 1:0] tx_toggle_cpu_sync;

reg  [25:0] timer;
reg  [17:0] timer1ms;
reg         timer1ms_expired;
reg         silent_area;
reg         frame_end_area;
reg  [10:0] frame;

reg   [7:0] tx_start_addr;
reg   [7:0] tx_end_addr;
reg   [7:0] rx_start_addr;
reg   [7:0] rx_end_addr;

reg  [10:0] errors;

reg  [15:0] data;
reg  [ 2:0] ones;
reg  [ 4:0] bits;
reg  [ 6:0] bytes;
reg         flip;
reg         ram_addr_inc;

// Full-speed support
reg  [15:0] sof;
reg  [10:0] sof_frame;
reg  [ 3:0] update_sof;
reg         sending_sof;

reg  [12:0] response_timeout;

reg dmi, dpi;
reg prev_dmi;

always @(posedge clk60m or negedge reset_n)
begin
	if (~reset_n)
	begin
		state <= S_NODEVICE;
		dm <= 1'bZ;
		dp <= 1'bZ;
		connected <= 1'b0;
		ram_addr <= 8'd0;
		ram_write <= 1'b0;
		rx_end_addr <= 8'd0;
		tx_toggle_usb <= 1'b0;
		tx_toggle_cpu_sync <= 2'b0;
		sending_sof <= 1'b0;
		sof <= 16'hE800;
		ram_addr_inc <= 1'b0;
	end
	else
	begin
		dmi <= dm;
		dpi <= dp;
		prev_dmi <= dmi;

		tx_toggle_cpu_sync <= {tx_toggle_cpu_sync[0], tx_toggle_cpu};
		
		timer1ms <= timer1ms + 15'd1;
		timer1ms_expired <= timer1ms >= 18'd59998;
		
		ram_write <= 1'b0;
		ram_addr_inc <= 1'b0;

		if (ram_addr_inc)
		begin
			ram_addr <= ram_addr + 8'd1;
			if (state != S_SEND && state != S_STOP0)
				rx_end_addr <= rx_end_addr + 8'd1;
		end
		
		silent_area <= timer1ms >= 18'd57344;
		frame_end_area <= timer1ms >= 18'd49152;
		
		// For better synchronization
		if (state == S_RECEIVE && timer[25] && (prev_dmi ^ dmi))
			timer <= full_speed ? {1'b1, 25'd0} : {1'b1, 25'd10};
		else
			timer <= ~timer[25] ? timer : timer - 26'd1;
		
		// Update CRC5 for SOF
		if (update_sof != 4'd0)
		begin
			if (sof_frame[0] ^ sof[11])
				sof[15:11] <= {1'b0, sof[15:12]} ^ 5'h14;
			else
				sof[15:11] <= {1'b0, sof[15:12]};
			sof_frame <= {1'b0, sof_frame[10:1]};
			update_sof <= update_sof - 4'd1;
		end
		
		if (force_reset[2])
			state <= S_NODEVICE;
		else if (~timer[25])
		begin
			case (state)
				S_NODEVICE:
				begin
					dm <= 1'bZ;
					dp <= 1'bZ;
					connected <= 1'b0;
					errors <= 11'd0;
					timer1ms <= 18'd0;
					// Check every 500 ms
					timer <= {1'b1, 25'd30000000};
					if (dmi != dpi)
						state <= S_DEBOUNCE;
				end
				S_DEBOUNCE:
				begin
					dm <= 1'b0;
					dp <= 1'b0;
					full_speed <= dp;
					if (dmi != dpi)
						state <= S_RESET;
					else
						state <= S_NODEVICE;
					timer <= {1'b1, 25'd1200000};
				end
				S_RESET:
				begin
					timer <= {1'b1, 25'd1200000};
					dm <= 1'bZ;
					dp <= 1'bZ;
					state <= S_IDLE;
				end
				S_IDLE:
				begin
					dm <= 1'bZ;
					dp <= 1'bZ;
					flip <= full_speed;
					response_timeout <= 9'd0;
					bits <= 5'd0;
					ones <= 3'd0;
					bytes <= 7'd0;
					connected <= 1'b1;
					sending_sof <= 1'b0;
					ram_addr <= tx_start_addr;
					if (~dmi && ~dpi)
					begin
						errors <= errors + 11'd1;
						if (errors[10])
							state <= S_NODEVICE;
					end
					else
						errors <= 11'd0;
					if (timer1ms_expired)
					begin
						timer1ms <= 18'd0;
						timer1ms_expired <= 1'b0;
						frame <= frame + 11'd1;
						if (~full_speed)
						begin
							dm <= 1'b0;
							dp <= 1'b0;
							state <= S_START0;
							timer <= full_speed ? {1'b1, 25'd3} : {1'b1, 25'd38};
						end
						else
						begin
							bits <= 5'd16;
							data <= 16'hA580;
							sending_sof <= 1'b1;
							state <= S_SEND;
						end
					end
					else if (~silent_area && (tx_toggle_cpu_sync[1] ^ tx_toggle_usb))
					begin
						tx_toggle_usb <= ~tx_toggle_usb;
						dm <= ~full_speed;
						dp <= full_speed;
						bits <= 5'd8;
						data <= ram_q;
						ram_addr <= ram_addr + 8'd1;
						state <= S_SEND;
						timer <= full_speed ? {1'b1, 25'd3} : {1'b1, 25'd38};
					end
					else if ({dmi, dpi} == {full_speed, ~full_speed})
					begin
						timer <= full_speed ? {1'b1, 25'd0} : {1'b1, 25'd10};
						flip <= ~full_speed;
						state <= S_RECEIVE_SYNC;
					end
				end
				S_START0:
				begin
					timer <= full_speed ? {1'b1, 25'd3} : {1'b1, 25'd38};
					state <= S_START1;
				end
				S_START1:
				begin
					timer <= full_speed ? {1'b1, 25'd8} : {1'b1, 25'd78};
					dm <= 1'bZ;
					dp <= 1'bZ;
					state <= S_IDLE;
				end
				S_SEND:
				begin
					timer <= full_speed ? {1'b1, 25'd3} : {1'b1, 25'd38};
					if (ones == 3'd6)
					begin
						flip <= ~flip;
						dm <= flip;
						dp <= ~flip;
						ones <= 3'd0;
					end
					else if (|bits && bytes != 7'd4)
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
						
						data <= {1'b0, data[15:1]};
						
						if (bits == 5'd9)
							bytes <= bytes + 7'd1;

						if (bits == 5'd1)
						begin
							if (sending_sof)
							begin
								// Send SOF and start a new SOF crc5 calculation
								if (bytes == 7'd1)
								begin
									bits <= 5'd16;
									data <= sof ^ 16'hF800;
									sof[10:0] <= sof[10:0] + 11'd1;
									sof_frame <= sof[10:0] + 11'd1;
									sof[15:11] <= 5'h1F;
									update_sof <= 4'd11;
								end
							end
							else if (ram_addr < tx_end_addr)
							begin
								bits <= 5'd8;
								data <= ram_q;
								ram_addr_inc <= 1'b1;
							end
							bytes <= bytes + 7'd1;
						end
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
					timer <= full_speed ? {1'b1, 25'd3} : {1'b1, 25'd38};
					dm <= 1'b0;
					dp <= 1'b0;
					state <= S_STOP1;
				end
				S_STOP1:
				begin
					timer <= full_speed ? {1'b1, 25'd3} : {1'b1, 25'd38};
					dm <= ~full_speed;
					dp <= full_speed;
					state <= S_STOP2;
				end
				S_STOP2:
				begin
					dm <= 1'bZ;
					dp <= 1'bZ;
					flip <= full_speed;
					ones <= 3'd0;
					bytes <= bytes + 7'd1;
					if (bits >= 5'd8)
					begin
						timer <= full_speed ? {1'b1, 25'd3} : {1'b1, 25'd38};
						state <= S_SEND;
					end
					else
					begin
						timer <= full_speed ? {1'b1, 25'd1} : {1'b1, 25'd18};
						state <= S_IDLE;
					end
				end
				S_RECEIVE_SYNC:
				begin
					bytes <= 7'd0;
					response_timeout <= 9'd0;
					ram_addr <= rx_start_addr;
					rx_end_addr <= rx_start_addr;
					if ({dmi, dpi} == {full_speed, ~full_speed})
						state <= S_RECEIVE;
					else
						state <= S_IDLE;
				end
				S_RECEIVE:
				begin
					timer <= full_speed ? {1'b1, 25'd3} : {1'b1, 25'd38};
					response_timeout <= response_timeout + 1'd1;
					if (response_timeout[12])
					begin
						state <= S_IDLE;
					end
					else if ({dmi, dpi} == 2'b00)
					begin
						timer <= full_speed ? {1'b1, 25'd16} : {1'b1, 25'd150};
						if (bytes >= 7'd4)
							state <= S_RECEIVE_ACK;
						else
							state <= S_IDLE;
					end
					else
					begin
						if (ones == 3'd6)
						begin
							ones <= 3'd0;
						end
						else if (dmi == flip)
						begin
							data <= {1'b1, data[7:1]};
							bits <= bits + 1'd1;
							if (bits == 5'd7)
							begin
								ram_write <= 1'b1;
								ram_addr_inc <= 1'b1;
								bits <= 5'd0;
								bytes <= bytes + 7'd1;
							end
							ones <= ones + 1'd1;
						end
						else
						begin
							data <= {1'b0, data[7:1]};
							bits <= bits + 1'd1;
							if (bits == 5'd7)
							begin
								ram_write <= 1'b1;
								ram_addr_inc <= 1'b1;
								bits <= 5'd0;
								bytes <= bytes + 7'd1;
							end
							ones <= 3'd0;
						end
						flip <= dmi;
					end
				end
				S_RECEIVE_ACK:
				begin
					dm <= 1'bZ;
					dp <= 1'bZ;
					flip <= full_speed;
					response_timeout <= 9'd0;
					ones <= 3'd0;
					bytes <= 7'd0;
					sending_sof <= 1'b0;

					// TODO: add CRC16 checking
					bits <= 5'd16;
					data <= 16'hD280;

					state <= S_SEND;
				end
			endcase
		end
	end
end

always @(posedge clk or negedge reset_n)
begin
	if (~reset_n)
	begin
		ready <= 1'b0;
		force_reset <= 3'b111;
		tx_toggle_cpu <= 1'b0;
		tx_start_addr <= 8'd0;
		tx_end_addr <= 8'd0;
		rx_start_addr <= 8'd0;
	end
	else
	begin
		ready <= 1'b0;
		if (valid & ~ready)
			ready <= 1'b1;

		if (addr[9])
		begin
			if (addr[2])
				dout <= {rx_end_addr, rx_start_addr, tx_end_addr, tx_start_addr};
			else
				dout <= {9'd0, frame_end_area, frame[0], state == S_IDLE,
					1'b0, 1'b0, full_speed, connected, 8'd0, ram_addr};
		end
		else
			dout <= {{4{ram_q_a}}};
		
		force_reset <= {force_reset[1:0], wr & valid & ~ready & addr[9] & ~addr[2] & din[18]};
		if (wr & valid & ~ready & addr[9])
		begin
			if (addr[2] & lane[0])
				tx_start_addr <= din[7:0];
			if (addr[2] & lane[1])
				tx_end_addr <= din[15:8];
			if (addr[2] & lane[2])
				rx_start_addr <= din[23:16];
			if (~addr[2] & din[19])
				tx_toggle_cpu <= ~tx_toggle_cpu;
		end
	end
end

endmodule
