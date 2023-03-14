# The FPGA - CPU interface

80286 CPU have 5 main transaction types: Memory Read, Memory Write, I/O Read, I/O Write, and an Interrupt Acknowledge.
Each cycle is identified by combination of signals S0, S1, M/IO, COD/INTA appearing on the CPU's buses.

When S0 and/or S1 goes low it is safe to fetch address and transaction type.

### Memory read

Appearing when the CPU is requesting code or reading memory. Identified by S0 = 1, S1 = 0, M/IO = 1.

We need to redirect a "read" command to RAM controller or ROM BIOS. When done, we'll send the result to the CPU's data bus.

### Memory write

Appearing when the CPU is writing to a memory. Identified by S0 = 0, S1 = 1, M/IO = 1.

We need to wait until S0 goes high and redirect a value from the CPU's data bus and a "write" command to RAM controller.

### I/O read

Appearing when the CPU is reading data from an external device. Identified by S0 = 1, S1 = 0, M/IO = 0.

We need to redirect a "read" command to a selected device. When done, we'll send the result to the CPU's data bus.

If the CPU is trying to read from a non-existing device it is better to return all one's like an original PC does.

### I/O write

Appearing when the CPU is writing to an external device. Identified by S0 = 0, S1 = 1, M/IO = 0.

We need to wait until S0 goes high and redirect a value from the CPU's data bus and a "write" command to a selected device.

### Interrupt Acknowledge

Appearing when the CPU acknowledges an interrupt. Identified by S0 = 0, S1 = 0, M/IO = 0, COD/INTA = 0.

We need to ask an interrupt controller what interrupt number is requested and send it to the CPU's data bus.

The CPU (for some reason) is performing this cycle twice. Ok, we'll repeat the number one more time.

### Ready signal

Some devices like SDRAM or SPI bus controller are working much slower than the CPU so we need to "extend" read/write cycles.

If the requested device cannot execute command immediately - it indicates "not ready" state by pulling CPU's "ready" signal to an inactive state.
The CPU can wait for the tranaction to end indefinitely. The "ready" signal should be synchronized to the CPU's clock.

A small program in the "Main.v" file performs all this actions.

### System reset

On power-up or by user's request (push the button) the CPU's reset procedure is performed.
The CPU will do it's own initialization routines for about 50 clock cycles, and we should keep the clock running for this period.

After that, the CPU will fill its instruction queue by performing 4 x 16 bit reads from address 0xFFFFF0. This address is a mirror for 0x0FFFF0 where the system BIOS lives.
A very first command usually located in this address in the BIOS is a long jump to a BIOS's entry point, but you can place there any command you want - the CPU will execute it in an usual way.
