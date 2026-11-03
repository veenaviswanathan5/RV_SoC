#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for file in Makefile axi_slave.h main.cpp firmware/start.S firmware/link.ld rtl/topCPU.sv; do
    if [[ ! -f "$file" ]]; then
        echo "Missing $file. Copy the addon CONTENTS into your existing RV_SoC project." >&2
        exit 1
    fi
done
prefix="${CROSS:-riscv64-unknown-elf-}"
for tool in verilator sdl2-config "${prefix}gcc" "${prefix}objcopy" "${prefix}size"; do
    command -v "$tool" >/dev/null || { echo "Required command missing: $tool" >&2; exit 1; }
done
# Force rebuild: existing Makefile pattern does not track included C/header files.
make CROSS="$prefix" -B firmware/tetris.bin
"${prefix}size" firmware/tetris.elf
make emulator
echo "Built firmware/tetris.bin and obj_dir/rv_soc."
