CROSS ?= riscv64-unknown-elf-
RTL := $(wildcard rtl/*.sv)
FWFLAGS := -march=rv32im -mabi=ilp32 -O1 -ffreestanding -fno-builtin -fno-pic -msmall-data-limit=0 -mstrict-align -nostdlib -nostartfiles -Wl,--no-relax -T firmware/link.ld
.PHONY: all lint emulator headless firmware test host-test
all: emulator firmware
lint:
	verilator --lint-only -Wall -Wno-fatal --top-module topCPU $(RTL)
emulator:
	verilator --cc --exe --build -j 0 -Wall -Wno-fatal --top-module topCPU --Mdir obj_dir $(RTL) $(abspath main.cpp) -CFLAGS "-std=c++17 $$(sdl2-config --cflags)" -LDFLAGS "$$(sdl2-config --libs)" -o rv_soc
headless:
	verilator --cc --exe --build -j 0 -Wall -Wno-fatal --top-module topCPU --Mdir obj_headless $(RTL) $(abspath main.cpp) -CFLAGS "-std=c++17 -DNO_SDL" -o rv_soc
firmware: firmware/demo.bin firmware/smoke.bin
firmware/%.elf: firmware/%.c firmware/start.S firmware/link.ld
	$(CROSS)gcc $(FWFLAGS) firmware/start.S $< -o $@
	$(CROSS)objdump -d $@ > $(@:.elf=.dis)
firmware/%.bin: firmware/%.elf
	$(CROSS)objcopy -O binary $< $@
host-test:
	$(CXX) -std=c++17 -Wall -Wextra -Werror tests/axi_test.cpp -o /tmp/rv_soc_axi_test
	/tmp/rv_soc_axi_test
test: headless firmware/smoke.bin
	./obj_headless/rv_soc firmware/smoke.bin --headless --cycles 1000000
.SECONDARY:
