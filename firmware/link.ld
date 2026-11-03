OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
 ROM (rx) : ORIGIN = 0x00000000, LENGTH = 1M
 RAM (rw) : ORIGIN = 0x10000000, LENGTH = 1M
}
SECTIONS {
 .text : { KEEP(*(.text.start)) *(.text*) *(.rodata*) . = ALIGN(4); } > ROM
 .data : {
   _data_start = .; *(.data*) *(.sdata*) . = ALIGN(4); _data_end = .;
 } > RAM AT> ROM
 _data_load = LOADADDR(.data);
 __global_pointer$ = _data_start + 0x800;
 .bss (NOLOAD) : {
   _bss_start = .; *(.bss*) *(.sbss*) *(COMMON) . = ALIGN(4); _bss_end = .;
 } > RAM
 _stack_top = ORIGIN(RAM) + LENGTH(RAM);
 ASSERT(_bss_end <= _stack_top - 4096, "RAM needs at least 4 KiB stack")
}
