module PIT(
	input wire clk,
	input wire reset_n,
	
	input wire [11:0] port,
	input wire [15:0] din,
	output reg [15:0] dout,
	input wire cpu_iordin,
	output reg cpu_iordout,
	input wire cpu_iowrin,
	output reg cpu_iowrout,
	
	output reg irq0,
	
	output reg t1out,
	output reg t2out
);

localparam
	PRESCALER = 7'd42;

reg cs_40h;
reg cs_41h;
reg cs_42h;
reg cs_43h;

reg [6:0] div;


reg [6:0] control1;
reg [6:0] control2;
reg [6:0] control3;
reg [15:0] preset1;
reg [15:0] preset2;
reg [15:0] preset3;
reg [15:0] value1;
reg [15:0] value2;
reg [15:0] value3;
reg [15:0] latch1;
reg [15:0] latch2;
reg [15:0] latch3;

wire iord = cpu_iordout ^ cpu_iordin;
wire iowr = cpu_iowrout ^ cpu_iowrin;

wire [7:0] iodin = port[0] ? din[15:8] : din[7:0];

always @(posedge clk)
begin
	cpu_iordout <= cpu_iordin;
	cpu_iowrout <= cpu_iowrin;
	
	cs_40h <= port == 12'h040;
	cs_41h <= port == 12'h041;
	cs_42h <= port == 12'h042;
	cs_43h <= port == 12'h043;

	control1 <= ~reset_n ? 7'd0 : iowr && cs_43h && (iodin[7:6] == 2'd0) ? {1'b0, iodin[5:0]} :
		(iowr || iord) && cs_40h && (~(control1[5] ^ control1[4])) ? {~control1[6], control1[5:0]} : control1;
	control2 <= ~reset_n ? 7'd0 : iowr && cs_43h && (iodin[7:6] == 2'd1) ? {1'b0, iodin[5:0]} :
		(iowr || iord) && cs_41h && (~(control2[5] ^ control2[4])) ? {~control2[6], control2[5:0]} : control2;
	control3 <= ~reset_n ? 7'd0 : iowr && cs_43h && (iodin[7:6] == 2'd2) ? {1'b0, iodin[5:0]} :
		(iowr || iord) && cs_42h && (~(control3[5] ^ control3[4])) ? {~control3[6], control3[5:0]} : control3;
		
	preset1 <= ~reset_n ? 16'hFFFF : iowr && cs_40h && (&control1[5:4]) ? {control1[6] ? iodin : preset1[15:8], ~control1[6] ? iodin : preset1[7:0]} :
		iowr && cs_40h && (^control1[5:4]) ? {control1[5] ? iodin : preset1[15:8], control1[4] ? iodin : preset1[7:0]} : preset1;
	preset2 <= ~reset_n ? 16'h0012 : iowr && cs_41h && (&control2[5:4]) ? {control2[6] ? iodin : preset2[15:8], ~control2[6] ? iodin : preset2[7:0]} :
		iowr && cs_41h && (^control2[5:4]) ? {control2[5] ? iodin : preset2[15:8], control2[4] ? iodin : preset2[7:0]} : preset2;
	preset3 <= ~reset_n ? 16'hFFFF : iowr && cs_42h && (&control3[5:4]) ? {control3[6] ? iodin : preset3[15:8], ~control3[6] ? iodin : preset3[7:0]} :
		iowr && cs_42h && (^control3[5:4]) ? {control3[5] ? iodin : preset3[15:8], control3[4] ? iodin : preset3[7:0]} : preset3;
		
	value1 <= div == PRESCALER ? (|value1 ? value1 - 16'd1 : (|preset1 ? preset1 : 16'hFFFF)) : value1;
	value2 <= div == PRESCALER ? (|value2 ? value2 - 16'd1 : (|preset2 ? preset2 : 16'hFFFF)) : value2;
	value3 <= div == PRESCALER ? (|value3 ? value3 - 16'd1 : (|(preset3 >> 1) ? preset3 : 16'hFFFF)) : value3;
	
	div <= div == PRESCALER ? 7'd0 : div + 7'd1;
	
	irq0 <= (div == PRESCALER) && (value1 == 16'd0) ? ~irq0 : irq0;

	t1out <= (div == PRESCALER) && (value2 == 16'd0) ? ~t1out : t1out;
	
	t2out <= (div == PRESCALER) && (value3 == 16'd0) ? ~t2out : t2out;

	dout <= {2{
		cs_40h && ((~control1[5]) || (control1[5] & (~control1[6]))) ? value1[7:0] :
		cs_40h && (((~control1[4]) && control1[5]) || (control1[5] & (control1[6]))) ? value1[15:8] :
		cs_41h && ((~control2[5]) || (control2[5] & (~control2[6]))) ? value2[7:0] :
		cs_41h && (((~control2[4]) && control2[5]) || (control2[5] & (control2[6]))) ? value2[15:8] :
		cs_42h && ((~control3[5]) || (control3[5] & (~control3[6]))) ? value3[7:0] :
		cs_42h && (((~control3[4]) && control3[5]) || (control3[5] & (control3[6]))) ? value3[15:8] :
		8'hFF
		}};
end

endmodule
