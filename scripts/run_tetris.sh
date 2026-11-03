#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ ! -f firmware/tetris.bin || ! -x obj_dir/rv_soc ]]; then
    echo "Build first: bash scripts/build_tetris.sh" >&2
    exit 1
fi
# A generous cycle budget for interactive sessions; Escape/window close exits.
exec ./obj_dir/rv_soc firmware/tetris.bin --cycles "${TETRIS_MAX_CYCLES:-100000000000}"
