#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
prefix="${CROSS:-riscv64-unknown-elf-}"
echo "1/6: Native game tests"
bash scripts/test_tetris_host.sh
echo "2/6: Strict RTL lint"
verilator --lint-only -Wall --top-module topCPU rtl/*.sv
echo "3/6: Existing host AXI and CPU smoke tests"
make host-test
make CROSS="$prefix" test
echo "4/6: Cross-compile timer probe and shared game tests"
make CROSS="$prefix" -B firmware/tetris_timer_probe.bin firmware/tetris_selftest.bin
echo "5/6: Verify timer MMIO"
./obj_headless/rv_soc firmware/tetris_timer_probe.bin --headless --cycles 500000000
echo "6/6: Execute game self-test on the RV32 CPU (may take some time)"
./obj_headless/rv_soc firmware/tetris_selftest.bin --headless --cycles 5000000000
echo "All automated Tetris integration checks passed. Next: build and play."
