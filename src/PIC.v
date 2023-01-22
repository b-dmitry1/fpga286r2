module PIC(
	input wire clk,
	input wire reset_n,
	
	input wire [11:0] port,
	input wire [15:0] din,
	output reg [15:0] dout,

	input wire cpu_iordin,
	output reg cpu_iordout,
	input wire cpu_iowrin,
	output reg cpu_iowrout,

	input wire inta,
	
	output reg [7:0] irq_vector,
	output wire intr,
	
	input wire irq0,
	input wire irq1
);

// Здесь IRQ0 срабатывает по фронту, а IRQ1 по высокому уровню

reg irq0_toggle;

reg irq_enable;

wire irq = |irq_vector;

assign intr = irq & irq_enable;

wire iord = cpu_iordout ^ cpu_iordin;
wire iowr = cpu_iowrout ^ cpu_iowrin;

wire cs_20h = port == 12'h020;

always @(posedge clk)
begin
	cpu_iordout <= cpu_iordin;
	cpu_iowrout <= cpu_iowrin;
	
	irq_enable <= (~reset_n) | inta ? 1'b0 : iowr && cs_20h ? 1'b1 : irq_enable;
	
	irq_vector <= (~reset_n) || (iowr && cs_20h) ? 8'd0 :
		|irq_vector ? irq_vector : irq0 ^ irq0_toggle ? 8'd8 : irq1 ? 8'd9 : 8'd0;
		
	irq0_toggle <= (irq0 ^ irq0_toggle) && (irq_vector == 8'd8) ? ~irq0_toggle : irq0_toggle;

	dout <= 16'hFFFF;
end

endmodule
