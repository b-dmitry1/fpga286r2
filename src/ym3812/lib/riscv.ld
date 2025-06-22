MEMORY
{
	rom (rx)  : ORIGIN = 0x00000000, LENGTH = 6K
	ram (rwx) : ORIGIN = 0x00001800, LENGTH = 0x700
}

SECTIONS 
{	
	. = ORIGIN(rom);
	.text : 
	{ 
		KEEP(*(.isr_vector .isr_vector.*)) 
		. = ALIGN(2);
		*(.text .text.* .gnu.linkonce.t.*) 		  
		*(.glue_7t)
		*(.glue_7)						
		*(.rodata .rodata* .gnu.linkonce.r.*)								  
		. = ALIGN(4);
	} > rom
	
	. = ALIGN(4); 
	_etext = .;
	_sidata = .; 

	.data :
	{
		PROVIDE (_sdata = .); 
		*(.data .data.*) 
		*(.sdata)
	        . = ALIGN(4);
        	PROVIDE (__ctors_begin = .);
	        KEEP (*(SORT(.ctors*)))
        	KEEP (*(.ctors))
	        PROVIDE (__ctors_end = .);
        	PROVIDE (__preinit_array_start = .);
	        KEEP (*(SORT(.preinit_array.*)))
        	KEEP (*(.preinit_array))
	        PROVIDE (__preinit_array_end = .);
        	PROVIDE (__init_array_start = .);
	        KEEP (*(SORT(.init_array.*)))
        	KEEP (*(.init_array))
	        PROVIDE (__init_array_end = .);
		. = ALIGN(4); 
		PROVIDE (_edata = .);
	} >ram AT >rom

	.bss (NOLOAD) : 
	{
		PROVIDE(_sbss = .); 
		*(.bss .bss.*) 
		*(COMMON) 
		. = ALIGN(4); 
		PROVIDE(_ebss = .); 
	} > ram

	.heap (NOLOAD):
	{
		*(.heap .heap.*)
	} > ram
	
	. = ALIGN(4); 
	_end = . ;
}
PROVIDE(_estack = ORIGIN(ram) + LENGTH(ram));
PROVIDE(_data_load = LOADADDR(.data));
PROVIDE(_rom_size = LENGTH(rom));
PROVIDE(_ram_size = LENGTH(ram));
