# RV32 Tetris — installation, validation, and project completion

This is an additive firmware package for your working RV_SoC timer baseline.
It does not replace the RTL, main.cpp, axi_slave.h, Makefile, startup assembly,
or linker script. Keep RV_SoC_timer_baseline.tar.gz for your later LVGL work.
All new code is supplied: no manual source edits are needed.

## 1. Install

Extract RV_SoC_Tetris_addon.zip to a temporary folder. Copy its contents into
~/RV_SoC, merging firmware/, tests/, and scripts/ with the existing folders.
Do not replace the whole firmware or tests directory: existing files remain.
The zip contains only new Tetris-related files and documentation.

Alternatively, put the downloaded ZIP directly in your Ubuntu home directory:

```bash
cd ~/RV_SoC
python3 -m zipfile -e ~/RV_SoC_Tetris_addon.zip .
```

The following should now exist:

```text
firmware/tetris.c
firmware/tetris_selftest.c
firmware/tetris_timer_probe.c
tests/tetris_checks.h
tests/tetris_host_test.c
scripts/build_tetris.sh
scripts/test_tetris_host.sh
scripts/verify_tetris.sh
scripts/run_tetris.sh
TETRIS_GUIDE.md
TETRIS_VALIDATION.txt
tetris_preview.png
```

## 2. Run the automated checks

```bash
cd ~/RV_SoC
bash scripts/verify_tetris.sh
```

This script stops at the first failed command. It runs:
1. Native game-logic/render tests.
2. Strict RTL lint (no -Wno-fatal).
3. Existing host AXI tests and the CPU smoke test.
4. Cross-compilation of the timer probe and game self-test.
5. The timer probe on your CPU, in headless mode.
6. Shared game tests on your CPU, in headless mode.

Expected messages include:

```text
Tetris tests passed: rules, timing, rendering, 12000-step deterministic input test.
AXI slave tests passed
OK
Firmware exit: 0
Tetris timer probe PASS: millisecond register advances
Firmware exit: 0
Tetris RV32 self-test PASS
Firmware exit: 0
All automated Tetris integration checks passed. Next: build and play.
```

The game self-test is much larger than the original smoke test. It prints a
start message and may run silently for a while. Its five-billion-cycle limit
is a watchdog, not an expected runtime or target cycle count.
If a check fails, retain the full output; do not bypass it and assume success.
A failure naming tetris_checks.h reports the failed check's source line.

## 3. Build and play

```bash
bash scripts/build_tetris.sh
bash scripts/run_tetris.sh
```

The build script uses the existing Makefile firmware rule and SDL emulator
target. It forces a rebuild of game firmware and reports its ELF size.
The run script gives interactive play a generous 100-billion-cycle budget.
It does not rebuild automatically. After any future source changes, run the
build script again before launching.

Click the SDL window to give it keyboard focus. Press Space to start.

| Control | Action |
|---|---|
| Left / Right | Move; holding repeats after 180 ms, then every 65 ms |
| Up | Rotate clockwise once per press |
| Down | Soft drop, once per 40 ms while held |
| Space | Hard drop; on title/game-over screens, start/restart |
| Up + Down together | Toggle pause; release both before toggling again |
| Escape | Return from firmware with status zero |
| Window close | Stop the host emulator |

If one arrow of the pause chord arrives first, a rotation/drop can occur before
the second key arrives. This is an intentional compromise to use the six keys
already exposed by your existing host. No additional host key mapping is needed.

## 4. Implemented game rules

- 10-column, 20-row board and all seven tetrominoes.
- Shuffled seven-piece bags, seeded from start time.
- Next-piece preview and outlined landing-position preview.
- Clockwise rotation with a small horizontal/upward kick search.
- Full-row removal with board compaction.
- Line scores: 100 / 300 / 500 / 800 times the level before the clear.
- Soft-drop score: one per cell; hard-drop score: two per cell.
- One level per ten cleared lines. Gravity begins at 760 ms per row and
  decreases by 55 ms per level to a 100 ms floor.
- A 400 ms grounded lock delay. Sliding while still grounded does not renew it.
- Pause, game over when spawn is blocked, and restart.
- Best score persists across restarts within one emulator session. It is not
  written to disk and resets when the process exits.
- No sound, hold queue, counterclockwise rotation, hidden spawn rows, T-spins,
  combo bonuses or official SRS behavior. This is a compact educational
  Tetris-style game, not a guideline-compliant implementation.

## 5. Architecture and compatibility

All game logic, collision detection, score calculation, text and tile drawing
execute as bare-metal RV32IM instructions on your custom CPU.
The C++ host only supplies memory, the timer, keyboard state, and SDL rendering.

| Address | Required behavior |
|---|---|
| 0x00000000 | ROM entry point; firmware loaded at zero |
| 0x10000000 | RAM; existing 1 MiB region is sufficient for this package |
| 0x20000000 | 320x240 ARGB8888 framebuffer; 1280-byte row stride |
| 0x30000000 | UART-like console output, low byte |
| 0x30000004 | Keys: Left=1, Right=2, Up=4, Down=8, Space=16, Escape=32 |
| 0x30000008 | Exit code written by existing startup code after main returns |
| 0x3000000C | Monotonically advancing 32-bit elapsed milliseconds |

The game relies on the timer implementation you already added. The timer probe
checks that this register advances; it cannot establish its exact calibration.
The source uses unsigned elapsed-time comparisons to tolerate timer wraparound.
It needs no allocator, printf, filesystem, operating system, interrupt, or LVGL.
Only changed board cells and changed HUD values are normally redrawn; mode
transitions redraw the screen. This limits AXI framebuffer traffic.
The main loop polls at roughly 16 ms host intervals. It does not try to execute
a large burst of catch-up updates after slow rendering.

The self-test uses an ordinary 307,200-byte RAM framebuffer, rather than VRAM,
so the same render checks work natively and in headless RV32 execution.
The playable game writes directly to VRAM and does not allocate that buffer.

## 6. Manual acceptance checklist

After automated checks pass, record these observations:

- Title screen and HUD are legible; Space starts.
- Arrow keys move the piece and stop at board edges/settled blocks.
- Up rotates; landing outline matches the position reached by a hard drop.
- Down accelerates falling; holding Space does not repeatedly drop new pieces.
- Complete a line; it disappears, blocks above shift down, and score increases.
- Next-piece preview matches the next spawned piece.
- Pause freezes the board; resume does not cause an immediate long catch-up drop.
- Play until game over; Space restarts with zero score and retained best score.
- Escape exits with `Firmware exit: 0`.
- Re-run existing `make test` after the game session.

A static preview is included. It was rendered by the actual C drawing code on
the host with a constructed board, not captured from the Verilated CPU.

## 7. Finish and present the project

Once the checks above pass, your application milestone is complete. Prepare:

1. A source-only archive including RTL, emulator, firmware, tests, and guides.
2. A README memory-map table and exact build/run commands.
3. Saved strict-lint, host-test, CPU-smoke, timer, and game-test output.
4. Tool versions (verilator --version, riscv64-unknown-elf-gcc --version,
   g++ --version, sdl2-config --version).
5. A short demonstration recording showing movement, rotation, a cleared line,
   pause/resume, game over/restart, and clean exit.
6. A report describing native instruction fetch plus AXI4-Lite data access,
   startup/data/BSS initialization, MMIO, dirty-cell rendering, and limitations.

You can capture test output with exit status preserved:

```bash
cd ~/RV_SoC
set -o pipefail
bash scripts/verify_tetris.sh 2>&1 | tee tetris_verification.log
```

Save the completed source tree:

```bash
cd ~/RV_SoC
tar --exclude=obj_dir --exclude=obj_headless --exclude=rtl_before_cleanup \
    -czf ../RV_SoC_tetris_complete.tar.gz .
```

Reproducibility check: extract that archive into a new empty directory, run
verify_tetris.sh, build_tetris.sh, and run_tetris.sh there. Do not rely on old
obj_dir outputs. The build scripts compile from the included sources.

Passing this package's tests does not prove full RV32IM compliance. If your
assessment requires CPU verification beyond an application demonstration,
add instruction-level tests for all instructions, forwarding/stall corner
cases, and randomized AXI delays. The existing host AXI test is not equivalent
to testing the CPU under arbitrary bus timing. The CPU still has no architectural
write-error trap path; the existing host stops invalid accesses instead.

## 8. Return to the timer baseline for LVGL later

Restore into a separate directory so Tetris remains available:

```bash
mkdir -p ~/RV_SoC_LVGL
tar -xzf ~/RV_SoC_timer_baseline.tar.gz -C ~/RV_SoC_LVGL
cd ~/RV_SoC_LVGL
verilator --lint-only -Wall --top-module topCPU rtl/*.sv
make host-test
make test
```

If your backup is stored elsewhere, use its actual path. That baseline already
has the display, keyboard and timer needed for the subsequent LVGL port.
Keep LVGL work independent until its firmware and runtime configuration pass.

## Troubleshooting

- Missing Makefile/start.S/topCPU: addon was extracted in the wrong directory.
  Its contents belong inside the existing RV_SoC folder.
- Unmapped read at 0x3000000C: the timer-enabled axi_slave.h is not installed.
- Title appears but Space never starts: first check timer probe and window focus.
- Cycle-limit exit: a watchdog fired; that is not a test pass. Keep the full log.
- Missing SDL/toolchain commands: the scripts print the absent command.
- A different compiler prefix can be supplied as CROSS=your-prefix- before the
  build/verify command. Continue using RV32IM/ILP32, without compressed opcodes.
- No manual code edits are part of installation. For a failure, share its log
  and the affected current source rather than applying speculative changes.
