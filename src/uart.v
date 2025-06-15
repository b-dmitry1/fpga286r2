module uart
(
	input wire        clk,
	
	input wire [ 2:0] addr,
	input wire [31:0] din,
	output reg [31:0] dout,
	input wire [ 3:0] lane,
	input wire        wr,
	input wire        valid,
	
	input  wire       rxd,
	output reg        txd
);

localparam
	BIT_TIME	  = 12'd433;

localparam
	S_IDLE     = 2'd0,
	S_TRANSMIT = 2'd1,
	S_START    = 2'd1,
	S_RECEIVE  = 2'd2,
	S_STOP     = 2'd3;

//////////////////////////////////////////////////////////////////////////////
// Transmitter
//////////////////////////////////////////////////////////////////////////////
reg [11:0] tdiv;
reg [ 1:0] tstate;
reg [ 9:0] tdata;
always @(posedge clk)
begin
	tdiv <=
		tstate == S_IDLE ? 12'd0 :
		tdiv == BIT_TIME ? 12'd0 :
		tdiv + 1'd1;
	
	txd <=
		tstate == S_IDLE ? 1'b1 :
		tdata[0];
	
	if (addr[2])
		dout <= {16'h0000, 1'b0, tstate == S_IDLE, tstate == S_IDLE, 4'b0000, rnotempty, 8'h00};
	else
		dout <= {24'd0, rdata};
	
	case (tstate)
		S_IDLE:
		begin
			if (valid && wr && ~addr[2] && lane[0])
			begin
				tdata <= {1'b1, din[7:0], 1'b0};
				tstate <= S_TRANSMIT;
			end
		end
		S_TRANSMIT:
		begin
			if (tdiv == BIT_TIME)
			begin
				tdata <= {1'b0, tdata[9:1]};
				if (tdata == 10'd1)
					tstate <= S_IDLE;
			end
		end
	endcase
end

//////////////////////////////////////////////////////////////////////////////
// Receiver
//////////////////////////////////////////////////////////////////////////////
reg [11:0] rdiv;
reg [1:0]  rstate;
reg [7:0]  rdata;
reg [3:0]  rbits;
reg        rnotempty;
always @(posedge clk)
begin
	if (valid && ~wr && ~addr[2] && lane[0])
		rnotempty <= 1'b0;

	case (rstate)
		S_IDLE:
		begin
			rdiv <= 12'd0;
			if (~rxd)
				rstate <= S_START;
			rbits <= 4'd7;
		end
		S_START:
		begin
			if (rdiv >= BIT_TIME / 2)
			begin
				rdiv <= 12'd0;
				if (~rxd)
					rstate <= S_RECEIVE;
				else
					rstate <= S_IDLE;
			end
			else
				rdiv <= rdiv + 1'd1;
		end
		S_RECEIVE:
		begin
			if (rdiv >= BIT_TIME)
			begin
				rdiv  <= 12'd0;
				rdata <= {rxd, rdata[7:1]};
				rbits <= rbits - 1'd1;
				if (rbits == 3'd0)
				begin
					rnotempty <= 1;
					rstate <= S_STOP;
				end
			end
			else
				rdiv <= rdiv + 1'd1;
		end
		S_STOP:
		begin
			if (rxd)
				rstate <= S_IDLE;
		end
	endcase
end

endmodule
