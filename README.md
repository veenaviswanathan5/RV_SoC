# RV32 Virtual SoC starter

This package contains copies of all 20 uploaded RTL modules, a C++ AXI4-Lite
slave, SDL2 display wrapper, firmware startup/linker files, and tests.
Use it as a separate working directory first; keep your existing wrapper as a backup.

## Important interface correction

The supplied topCPU already has clk/rst_n and AXI data ports, but instructions
arrive on instrAddr/instrData, NOT over AXI. This version preserves that design.
The host supplies combinational instruction data at the current PC. Converting
instruction fetch to AXI requires a fetch controller and stall/flush integration;
simply removing the native ports is not sufficient.

No instantiated Xilinx memory or clock IP was found in these sources.
The multiplier and divider are supplied portable RTL modules.
Only rtl/rv32_stage1_fetch.sv was changed:
- Reset PC: 0x00054844 -> 0, matching the linker and binary loader.
- instrAddr: predictive next PC -> current PC, matching the PC captured by IF/ID.
- JALR target: clear bit zero.
The remaining RTL is copied unchanged. Initial blocks in the register file and
reset synchronizer are retained; they are usable in this simulation setup.

## Run in WSL/Linux

From the extracted RV_Soc directory:

```sh
make host-test
make lint
make test
```

Expected smoke-test success: `OK`, `Firmware exit: 0`, process status zero.
This is an expected result, not a result obtained on the authoring host.
If it fails, save the entire build/runtime output before trying the demo.
The exit status 1 indicates failure; 2 means no firmware exit before the cycle
limit (or a simulation finish). The printed firmware code identifies the check:
1 startup/data/BSS, 2 byte/halfword stores, 3 signed M operations,
4 unsigned division/remainder, 5 division by zero.

After smoke passes:

```sh
make all
./obj_dir/rv_soc firmware/demo.bin --cycles 1000000000
```

Expected display: a 320x240 gradient scaled to a 640x480 window.
Space changes the top-left pixel; Escape exits. Closing the window also stops.
A cycle limit is a watchdog, not a real-time duration. WSL needs working GUI
support for SDL; `make test` uses no display or SDL dependency.
If your compiler prefix differs, use `make CROSS=your-prefix- test`.
Compile for RV32IM/ILP32; do not enable compressed instructions.

## Memory map

| Range / address | Purpose |
|---|---|
| 0x00000000–0x000FFFFF | 1 MiB ROM, binary loaded at zero, native instruction fetch and AXI data reads |
| 0x10000000–0x100FFFFF | 1 MiB RAM, stack starts at 0x10100000 and grows downward |
| 0x20000000–0x2004AFFF | 320x240 framebuffer, 32-bit pixels 0xAARRGGBB, row-major |
| 0x30000000 | Write low byte to host stdout |
| 0x30000004 | Read key bitmask: Left=1, Right=2, Up=4, Down=8, Space=16, Escape=32 |
| 0x30000008 | Word write: exit, zero=success, nonzero=failure |

ROM is read-only to firmware. The .bin stores text, rodata, and the initial .data
image in ROM; startup copies .data to RAM and zeros .bss. No ELF parser is used.
The framebuffer uses four bytes per pixel, including alpha; write alpha 0xff.
AXI data accesses return aligned words because the RTL load extender selects
byte/halfword lanes. Store data/strobes are already shifted by storeAligner.
Firmware must use naturally aligned halfword/word accesses. Cross-word
misaligned accesses are not implemented.

## Timing and errors

Each cycle drives the slave inputs, evaluates the CPU low phase, supplies the
instruction for instrAddr, evaluates again, snapshots AXI handshakes, and then
evaluates the rising edge. Updated slave state is driven next cycle. AW and W
are buffered independently; B and R remain valid until acknowledged. Responses
are OKAY for supported accesses. Illegal/unmapped accesses stop the host with
an error instead of returning a bus error that the supplied CPU may retry or
ignore. Reset is held for eight cycles, including the top-level synchronizer.

## Validation and limits

Executed here: C++ AXI tests compiled with -Wall -Wextra -Werror and passed.
They cover W-before-AW, AW-before-W, response backpressure, aligned read data,
byte strobes, framebuffer masking, reset, ROM protection, and exit MMIO.
Make recipes were checked with a dry run.
Not executed here: Verilator lint/build, cross-compilation, RTL smoke test,
or SDL window rendering. The authoring host lacks those dependencies.
This is a starter integration, not a claim of RV32IM ISA compliance. Further
CPU tests should cover all branch/jump paths, forwarding, load-use hazards,
M-extension overlap with AXI stalls, multiplication high halves, and division
overflow. The smoke test is deliberately small and is not a compliance suite.
Verilator warnings remain visible with -Wno-fatal for initial bring-up; inspect
width, latch, combinational-loop and missing-port warnings before relying on it.

No interrupts, timer MMIO, heap/libc, traps, or LVGL port are added. Once the
smoke test and gradient work, add LVGL's display flush, input and tick hooks,
and a memory allocation strategy. SDL wall time does not define CPU frequency.

References:
- https://verilator.org/guide/latest/exe_verilator.html
- https://wiki.libsdl.org/SDL2/MigrationGuide
