module UART_tx(
	input wire clk,
	
	input wire [7:0] data,
	
	input wire send_in,
	output reg send_out,
	
	output reg txd
);

localparam
	PRESCALER = 9'd433;

reg [8:0] div;	
reg tx_clk;

reg [3:0] bitn;
reg [7:0] buffer;

always @(posedge clk)
begin
	div <= div == PRESCALER ? 9'd0 : div + 1'd1;
	tx_clk <= div == PRESCALER;
end

always @(posedge tx_clk)
begin
	if (bitn == 4'd0)
	begin
		if (send_in != send_out)
		begin
			bitn <= bitn + 1'd1;
			buffer <= data;
			send_out <= ~send_out;
			txd <= 1'b0;
		end
		else
		begin
			txd <= 1'b1;
		end
	end
	else
	begin
		if (bitn <= 4'd8)
		begin
			buffer <= {1'b0, buffer[7:1]};
			bitn <= bitn + 1'd1;
			txd <= buffer[0];
		end
		else
		begin
			bitn <= 4'd0;
			txd <= 1'b1;
		end
	end
end

endmodule
