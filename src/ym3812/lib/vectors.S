.text
.section .isr_vector
.align 2

	j entry
	.word  _rom_size
	.word  _ram_size

entry:
	la sp, _estack

	la t0, _sidata
	la t1, _sdata
	la t2, _edata + 4

data_loop:
	bgeu t1, t2, data_end
	lw t3, 0(t0)
	sw t3, 0(t1)
	addi t0, t0, 4
	addi t1, t1, 4
	j data_loop
data_end:

	la t0, _sbss
	la t1, _ebss
bss_loop:
	bgeu t0, t1, bss_end
	sw zero, 0(t0)
	addi t0, t0, 4
	j bss_loop
bss_end:

	li a0, 0
  	li a1, 0
	j main
