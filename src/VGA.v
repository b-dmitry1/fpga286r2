module VGA(
	input wire clk,
	input wire clk250,
	input wire reset_n,
	
	input wire [23:0] a,
	input wire [7:0] din,
	output reg [7:0] dout,
	input wire mrdin,
	output reg mrdout,
	input wire mwrin,
	output reg mwrout,
	
	input wire [7:0] port,
	input wire [7:0] iodin,
	output reg [7:0] iodout,
	input wire iowrin,
	output reg iowrout,
	input wire iordin,
	output reg iordout,
	
	output wire ready,
	
	output wire hsync,
	output wire vsync,
	
	output reg [7:0] red,
	output reg [7:0] green,
	output reg [7:0] blue,

	output reg [23:0] video_addr,
	input wire [63:0] video_din,
	
	output reg [23:0] gpu_addr,
	output reg [31:0] gpu_dout,
	input wire [31:0] gpu_din,
	input wire gpu_rdin,
	output reg gpu_rdout,
	input wire gpu_wrin,
	output reg gpu_wrout,
	
	output reg planar,

	output wire hdmi_rp,
	output wire hdmi_rm,
	output wire hdmi_gp,
	output wire hdmi_gm,
	output wire hdmi_bp,
	output wire hdmi_bm,
	output wire hdmi_cp,
	output wire hdmi_cm
);

localparam
	GPU_IDLE		= 0,
	GPU_READ		= 1,
	GPU_WRITE_1	= 2,
	GPU_WRITE_2 = 3;

reg [1:0] gpu_state;

reg div;

reg [9:0] hcounter;
reg [9:0] vcounter;
reg [9:0] line;

// Reverse byte order
wire [63:0] video_din_r = {
	video_din[56], video_din[57], video_din[58], video_din[59], video_din[60], video_din[61], video_din[62], video_din[63],
	video_din[48], video_din[49], video_din[50], video_din[51], video_din[52], video_din[53], video_din[54], video_din[55],
	video_din[40], video_din[41], video_din[42], video_din[43], video_din[44], video_din[45], video_din[46], video_din[47],
	video_din[32], video_din[33], video_din[34], video_din[35], video_din[36], video_din[37], video_din[38], video_din[39],
	video_din[24], video_din[25], video_din[26], video_din[27], video_din[28], video_din[29], video_din[30], video_din[31],
	video_din[16], video_din[17], video_din[18], video_din[19], video_din[20], video_din[21], video_din[22], video_din[23],
	video_din[8], video_din[9], video_din[10], video_din[11], video_din[12], video_din[13], video_din[14], video_din[15],
	video_din[0], video_din[1], video_din[2], video_din[3], video_din[4], video_din[5], video_din[6], video_din[7]};

reg [9:0] scan_size;
reg v_480;
reg vvisible;

reg [63:0] video_data;

reg [4:0] frame;

reg textmode;
reg [8:0] next_addr_mask;
reg [3:0] next_line_mask;
reg [2:0] shift_size;
reg [3:0] shift_mask;
reg cga;
reg mode9;
reg ega;
reg ega320;
reg ega640;
reg vga256;
reg mono;
reg video_rev;
reg framebufferA0000;

reg [4:0] vmode;

reg [31:0] vga_latch;

assign hsync = (hcounter >= 10'd656) && (hcounter < 10'd752);
assign vsync = (vcounter >= 10'd490) && (vcounter < 10'd492);

wire visible = (hcounter < 10'd640) && (vcounter < 10'd480);

////////////////////////////////////////////////////////////////////////////////////////////////
// FONT
////////////////////////////////////////////////////////////////////////////////////////////////
wire [7:0] font_out;
Font font(.clock(~clk), .address({video_data[7:0], 4'b0000} + vcounter[3:0]), .q(font_out));

////////////////////////////////////////////////////////////////////////////////////////////////
// Registers and palette
////////////////////////////////////////////////////////////////////////////////////////////////
reg [9:0] vga_pal_read_index;
reg [9:0] vga_pal_write_index;

wire [17:0] rgb256;
reg [17:0] rgbin;
reg [17:0] rgblatch;

reg [4:0] gc_index;
reg [4:0] crt_index;
reg [4:0] sq_index;
reg [4:0] ac_index;
reg ac_data;

reg [7:0] vga_mask;
reg [1:0] read_plane;
reg [1:0] write_mode;
reg [3:0] color_compare;
reg [3:0] color_dont_care;
reg read_mode;
reg [2:0] rotate;
reg [3:0] planes;
reg [3:0] fill_color4;
reg [3:0] fill_mask4;
reg [1:0] logic_op;
reg [7:0] crt12;
reg [7:0] crt13;
reg [7:0] crt19;

reg [7:0] cga_color_cr;

reg [31:0] vga_data;

reg [7:0] vga_pan;

wire [8:0] reg_addr =
	(port == 8'hC0) && ega ? {4'b0000, ac_index} :
	port == 8'hD5 ? {4'b1100, crt_index} :
	port == 8'hC5 ? {4'b1101, sq_index} :
	port == 8'hCF ? {4'b1110, gc_index} :
	9'b111111111;

wire [7:0] reg_out;

wire [17:0] ega_color = {{3{iodin[0], iodin[3]}}, {3{iodin[1], iodin[4]}}, {3{iodin[2], iodin[5]}}};

VGARegs regs(.clock(~clk),
	.address_a(&vga_pal_write_index[1:0] ? vga_pal_write_index[9:2] :
		vga_pal_read_index[1:0] == 2'b00 ? vga_pal_read_index[9:2] :
		mode9 ? {5'h0, video_data[3], video_data[2], video_data[1], video_data[0]} :
		ega ? {5'h0, video_data[24], video_data[16], video_data[8], video_data[0]} :
		video_data[7:0]),
	.q_a(rgb256), .data_a(rgbin), .wren_a(&vga_pal_write_index[1:0]),
	.address_b(reg_addr), .q_b(reg_out),
	.data_b(port == 8'hC0 ? ega_color : iodin),
	.wren_b((iowrin ^ iowrout) && ((port != 8'hC0) || ac_data)));

////////////////////////////////////////////////////////////////////////////////////////////////
// GPU
////////////////////////////////////////////////////////////////////////////////////////////////


wire [31:0] fill_color = {{8{fill_color4[3]}}, {8{fill_color4[2]}}, {8{fill_color4[1]}}, {8{fill_color4[0]}}};
wire [31:0] fill_mask = {{8{fill_mask4[3]}}, {8{fill_mask4[2]}}, {8{fill_mask4[1]}}, {8{fill_mask4[0]}}};
reg [31:0] plane_write_mask;
wire [31:0] write_mask = {4{vga_mask}};
wire [31:0] bit_fill = {{8{rdin2[3]}}, {8{rdin2[2]}}, {8{rdin2[1]}}, {8{rdin2[0]}}};
wire [31:0] byte_fill = {rdin2, rdin2, rdin2, rdin2};

reg [7:0] rdin2;
always @*
begin
	case (rotate)
		3'd0: rdin2 <= din[7:0];
		3'd1: rdin2 <= {din[0], din[7:1]};
		3'd2: rdin2 <= {din[1:0], din[7:2]};
		3'd3: rdin2 <= {din[2:0], din[7:3]};
		3'd4: rdin2 <= {din[3:0], din[7:4]};
		3'd5: rdin2 <= {din[4:0], din[7:5]};
		3'd6: rdin2 <= {din[5:0], din[7:6]};
		3'd7: rdin2 <= {din[6:0], din[7]};
		default: rdin2 <= din[7:0];
	endcase
end

reg [31:0] op_write_mask;
reg [31:0] op_data;

always @*
begin
	case (logic_op)
		2'd0: vga_data <= (op_data & op_write_mask) | (vga_latch & (~op_write_mask));
		2'd1: vga_data <= (op_data | (~op_write_mask)) & vga_latch;
		2'd2: vga_data <= (op_data & op_write_mask) | vga_latch;
		2'd3: vga_data <= (op_data & op_write_mask) ^ vga_latch;
		default: vga_data <= op_data;
	endcase
end

wire [31:0] color_compare_dont_care32 =
	{{8{color_compare[3] & color_dont_care[3]}},
	{8{color_compare[2] & color_dont_care[2]}},
	{8{color_compare[1] & color_dont_care[1]}},
	{8{color_compare[0] & color_dont_care[0]}}};

wire [31:0] color_dont_care32 =
	{{8{color_dont_care[3]}}, {8{color_dont_care[2]}}, {8{color_dont_care[1]}}, {8{color_dont_care[0]}}};

wire [31:0] read_mode_1_result = (gpu_din & color_dont_care32) ^ color_compare_dont_care32;

always @(posedge clk)
begin
	gpu_addr <= (gpu_state == GPU_IDLE) && ((mrdin ^ mrdout) || (mwrin ^ mwrout)) && (a[23:16] == 8'h0A) && planar ? 24'hA0000 + {a[15:0], 2'b00} : gpu_addr;
	
	op_write_mask <= write_mode == 2'd3 ? byte_fill & write_mask : write_mask;
	
	case (write_mode)
		2'd0: op_data <= (fill_color & fill_mask) | (byte_fill & (~fill_mask));
		2'd1: op_data <= vga_latch;
		2'd2: op_data <= bit_fill;
		2'd3: op_data <= fill_color;
	endcase
	
	mrdout <= mrdin;
	mwrout <= mwrin;
	
	plane_write_mask <= {{8{planes[3]}}, {8{planes[2]}}, {8{planes[1]}}, {8{planes[0]}}};
	
	gpu_rdout <= (gpu_state == GPU_IDLE) && ((mrdin ^ mrdout) || (mwrin ^ mwrout)) && (a[23:16] == 8'h0A) && planar ? ~gpu_rdout : gpu_rdout;
	
	gpu_wrout <= (gpu_state == GPU_WRITE_1) && (gpu_rdin == gpu_rdout) ? ~gpu_wrout : gpu_wrout;

	gpu_dout <= (gpu_state == GPU_WRITE_1) && (gpu_rdin == gpu_rdout) ?
		(vga_data & plane_write_mask) | (gpu_din & (~plane_write_mask)) :
		gpu_dout;

	dout <= read_mode ? ~(read_mode_1_result[3] | read_mode_1_result[2] | read_mode_1_result[1] | read_mode_1_result[0]) :
		planar && (gpu_state == GPU_READ) && (gpu_rdin == gpu_rdout) && (read_plane == 2'b00) ? gpu_din[7:0] :
		planar && (gpu_state == GPU_READ) && (gpu_rdin == gpu_rdout) && (read_plane == 2'b01) ? gpu_din[15:8] :
		planar && (gpu_state == GPU_READ) && (gpu_rdin == gpu_rdout) && (read_plane == 2'b10) ? gpu_din[23:16] :
		planar && (gpu_state == GPU_READ) && (gpu_rdin == gpu_rdout) && (read_plane == 2'b11) ? gpu_din[31:24] :
		dout;

	// При чтении байта значение записывается в 32-битный регистр-защелку
	vga_latch <= (gpu_state == GPU_READ) && (gpu_rdin == gpu_rdout) ? gpu_din[31:0] : vga_latch;

	case (gpu_state)
		GPU_IDLE:
			if ((a[23:16] == 8'h0A) && planar)
			begin
				if (mrdin ^ mrdout)
					gpu_state <= GPU_READ;
				else if (mwrin ^ mwrout)
					gpu_state <= GPU_WRITE_1;
			end
		GPU_READ:
			if (gpu_rdin == gpu_rdout)
				gpu_state <= GPU_IDLE;
		GPU_WRITE_1:
			if (gpu_rdin == gpu_rdout)
				gpu_state <= GPU_WRITE_2;
		GPU_WRITE_2:
			if (gpu_wrin == gpu_wrout)
				gpu_state <= GPU_IDLE;
	endcase
end

reg read_palette;

////////////////////////////////////////////////////////////////////////////////////////////////
// Main
////////////////////////////////////////////////////////////////////////////////////////////////

assign ready = (iowrin == iowrout) && (iordin == iordout) && (|vga_pal_read_index[1:0]) && (gpu_state == GPU_IDLE);

always @(posedge clk)
begin
	div <= ~div;

	//vmode <= 5'd3;
	
	vga_pan <=
		crt19 <= 8'd40 ? 8'd0 :
		vmode == 5'h13 ? (crt19 - 8'd40) << 1 :
		vmode == 5'h0D ? ((crt19 - 8'd40) << 2) - 8'd2 :
		8'd0;
	
	iordout <= iordin;
	iowrout <= iowrin;
	
	// I/O write
	if (iowrin ^ iowrout)
	begin
		case (port)
			8'hBE:
				vmode <= iodin[4:0];
			8'hC7:
				vga_pal_read_index <= {iodin, 2'b00};
			8'hC8:
				vga_pal_write_index <= {iodin, 2'b00};
			8'hC9:
			begin
				vga_pal_write_index <= vga_pal_write_index + 10'd1;
				case (vga_pal_write_index[1:0])
					2'b00: rgbin[5:0] <= iodin[5:0];
					2'b01: rgbin[11:6] <= iodin[5:0];
					2'b10: rgbin[17:12] <= iodin[5:0];
				endcase
			end
			8'hC0:
				if (~ac_data)
					ac_index <= iodin[4:0];
			8'hC4:
				sq_index <= iodin[4:0];
			8'hC5:
			begin
				if (sq_index == 5'h2) planes <= iodin[3:0];
				if (sq_index == 5'h4) planar <= ~iodin[3];
			end
			8'hCE:
				gc_index <= iodin[4:0];
			8'hCF:
			begin
				if (gc_index == 5'h0) fill_color4 <= iodin[3:0];
				if (gc_index == 5'h1) fill_mask4 <= iodin[3:0];
				if (gc_index == 5'h2) color_compare <= iodin[3:0];
				if (gc_index == 5'h3) rotate <= iodin[2:0];
				if (gc_index == 5'h3) logic_op <= iodin[4:3];
				if (gc_index == 5'h4) read_plane <= iodin[1:0];
				if (gc_index == 5'h5) write_mode <= iodin[1:0];
				if (gc_index == 5'h5) read_mode <= iodin[3];
				if (gc_index == 5'h7) color_dont_care <= iodin[3:0];
				if (gc_index == 5'h8) vga_mask <= iodin;
			end
			8'hD4:
				crt_index <= iodin[4:0];
			8'hD5:
			begin
				if (crt_index == 5'd12) crt12 <= iodin;
				if (crt_index == 5'd13) crt13 <= iodin;
				if (crt_index == 5'd19) crt19 <= iodin;
			end
			8'hD9:
				cga_color_cr <= iodin;
		endcase
	end
	
	ac_data <=
		(iordin ^ iordout) && (port == 8'hDA) ? 1'b0 :
		(iowrin ^ iowrout) && (port == 8'hC0) ? ~ac_data :
		ac_data;
	
	// I/O read
	case (port)
		8'hC7:
			iodout <= vga_pal_read_index[9:2];
		8'hC8:
			iodout <= vga_pal_write_index[9:2];
		8'hC9:
		begin
			if (iordin ^ iordout)
			begin
				case (vga_pal_read_index[1:0])
					2'b01: iodout <= {2'b00, rgblatch[5:0]};
					2'b10: iodout <= {2'b00, rgblatch[11:6]};
					2'b11: iodout <= {2'b00, rgblatch[17:12]};
				endcase
			end
		end
		8'hC4:
			iodout <= sq_index;
		8'hCE:
			iodout <= gc_index;
		8'hD4:
			iodout <= crt_index;
		8'hC5,
		8'hCF,
		8'hD5:
			iodout <= reg_out[7:0];
		8'hD9:
			iodout <= cga_color_cr;
		8'hDA:
			iodout <= {4'h0, vcounter >= 10'd400, 2'b00, (vcounter >= 10'd400) || (hcounter >= 10'd320)}; // Для Wolfenstein 3D
	endcase
	
	// Palette get/set
	if (&vga_pal_write_index[1:0])
		vga_pal_write_index <= vga_pal_write_index + 10'd1;

	if (vga_pal_read_index[1:0] == 2'b00)
		rgblatch <= rgb256;
	
	vga_pal_read_index <=
		(vga_pal_read_index[1:0] == 2'b00) || ((iordin ^ iordout) && (port == 8'hC9)) ? vga_pal_read_index + 10'd1 :
		((iowrin ^ iowrout) && (port == 8'hC7)) ? {iodin, 2'b00} :
		((iowrin ^ iowrout) && (port == 8'hC9)) ? {vga_pal_read_index[9:2], 2'b00} :
		vga_pal_read_index;
	
	// Video mode
	textmode <= vmode <= 5'h3;
	v_480 <= (vmode == 5'h11) || (vmode == 5'h12) || (vmode == 5'h14);
	vga256 <= (vmode == 5'h13) || (vmode == 5'h14);
	cga <= (vmode == 5'h4) || (vmode == 5'h5) || (vmode == 5'h6);
	mode9 <= vmode == 5'h9;
	ega <= (vmode == 5'hD) || (vmode == 5'h10) || (vmode == 5'h12) || (vmode == 5'h11);
	ega320 <= vmode == 5'hD;
	ega640 <= (vmode == 5'h10) || (vmode == 5'h12);
	framebufferA0000 <= vmode >= 5'hA;
	video_rev <= (vmode > 5'h3) && (vmode < 5'h13);
	mono <= (vmode == 5'h6) || (vmode == 5'h11);
	case (vmode)
		5'h13:
		begin
			scan_size <= 10'd320;// + vga_pan;
			next_addr_mask <= 9'b000001111;
			next_line_mask <= 4'b0001;
			shift_mask <= 4'b0001;
			shift_size <= 3'd3;
		end
		5'h04,
		5'h05,
		5'h06:
		begin
			scan_size <= 10'd80;
			next_addr_mask <= 9'b000111111;
			next_line_mask <= 4'b0011;
			shift_mask <= 4'b0001;
			shift_size <= 3'd1;
		end
		5'h09:
		begin
			scan_size <= 10'd160;
			next_addr_mask <= 9'b000011111;
			next_line_mask <= 4'b0111;
			shift_mask <= 4'b0001;
			shift_size <= 3'd2;
		end
		5'h0D:
		begin
			scan_size <= 10'd160;// + vga_pan;
			next_addr_mask <= 9'b000011111;
			next_line_mask <= 4'b0001;
			shift_mask <= 4'b0001;
			shift_size <= 3'd0;
		end
		5'h11:
		begin
			scan_size <= 10'd80;
			next_addr_mask <= 9'b000111111;
			next_line_mask <= 4'b0000;
			shift_mask <= 4'b0000;
			shift_size <= 3'd0;
		end
		5'h10,
		5'h12:
		begin
			scan_size <= 10'd320;
			next_addr_mask <= 9'b000001111;
			next_line_mask <= 4'b0000;
			shift_mask <= 4'b0000;
			shift_size <= 3'd0;
		end
		default:
		begin
			scan_size <= 10'd160;
			next_addr_mask <= 9'b000011111;
			next_line_mask <= 4'b1111;
			shift_mask <= 4'b0111;
			shift_size <= 3'd4;
		end
	endcase
	
	vvisible <= v_480 ? vcounter < 10'd480 : vcounter < 10'd400;
	
	// Video data
	if (~div)
	begin
		// Color mux
		if ((hcounter < 10'd640) && (vvisible))
		begin
			if (textmode)
			begin
				red <= font_out[hcounter[2:0]] ? {video_data[10], video_data[11], 6'd0} : {video_data[14], video_data[15], 6'd0};
				green <= font_out[hcounter[2:0]] ? {video_data[9], video_data[11], 6'd0} : {video_data[13], video_data[15], 6'd0};
				blue <= font_out[hcounter[2:0]] ? {video_data[8], video_data[11], 6'd0} : {video_data[12], video_data[15], 6'd0};
			end
			else if (vga256 | ega)
			begin
				red <= {rgb256[5:0], 2'b00};
				green <= {rgb256[11:6], 2'b00};
				blue <= {rgb256[17:12], 2'b00};
			end
			else if (mode9)
			begin
				red <= {4{video_data[1], video_data[0]}};
				green <= {4{video_data[2], video_data[0]}};
				blue <= {4{video_data[3], video_data[0]}};
			end
			else if (mono)
			begin
				red <= {video_data[0], 7'd0};
				green <= {video_data[0], 7'd0};
				blue <= {video_data[0], 7'd0};
			end
			else
			begin
				if (~cga_color_cr[5])
				begin
					red <= {8{video_data[0]}};
					green <= {8{video_data[1]}};
					blue <= 8'h00;
				end
				else
				begin
					red <= {8{video_data[0]}};
					green <= {8{video_data[1]}};
					blue <= {8{video_data[1] | video_data[0]}};
				end
			end
		end
		else
		begin
			red <= 8'd0;
			green <= 8'd0;
			blue <= 8'd0;
		end

		// Frame
		if (hcounter == 10'd799)
		begin
			hcounter <= 10'd0;
			if (vcounter == 10'd524)
			begin
				vcounter <= 10'd0;
				frame <= frame + 5'd1;
			end
			else
				vcounter <= vcounter + 10'd1;
		end
		else
			hcounter <= hcounter + 10'd1;

		// Pixel shift
		if ((hcounter[8:0] & next_addr_mask) == next_addr_mask)
			video_data <= video_rev ? video_din_r : video_din;
		else if (((hcounter[3:0] & shift_mask) == shift_mask) && (hcounter < 10'd640))
		begin
			case (shift_size)
				3'd0: video_data <= (ega640 && &hcounter[2:0]) || (ega320 && &hcounter[3:0]) ? video_data >> 25 : video_data >> 1;
				3'd1: video_data <= video_data >> 2;
				3'd2: video_data <= video_data >> 4;
				3'd3: video_data <= video_data >> 8;
				3'd4: video_data <= video_data >> 16;
			endcase
		end

		// Address shift
		if ((hcounter[8:0] & next_addr_mask) == 0)
		begin
			if (hcounter < 10'd640)
			begin
				if (vvisible)
					video_addr <= video_addr + 8'd8;
			end
			
			if (hcounter == 10'd640)
			begin
				if (vvisible)
				begin
					if (mode9)
					begin
						video_addr[14:13] <= (vcounter[2:0] + 3'd1) >> 1;
						if ((vcounter[3:0] & next_line_mask) != next_line_mask)
							video_addr[12:0] <= video_addr[12:0] - scan_size;
					end
					else
					if (cga)
					begin
						if (^vcounter[1:0])
							video_addr[13] <= 1'b1;
						else
							video_addr[13] <= 1'b0;
						if ((vcounter[3:0] & next_line_mask) != next_line_mask)
							video_addr[12:0] <= video_addr[12:0] - scan_size;
					end
					else
					begin
						if ((vcounter[3:0] & next_line_mask) != next_line_mask)
							video_addr <= video_addr - scan_size;// + vga_pan;
						else
							video_addr <= video_addr + vga_pan;
					end
				end
				else
					video_addr <= framebufferA0000 ? 24'hA0000 + {crt12, crt13[7:1], 3'b000} : 24'hB8000;
			end
		end
	end
end

endmodule
