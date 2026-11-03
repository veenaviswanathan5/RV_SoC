#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
test_binary=$(mktemp /tmp/rv_tetris_test.XXXXXX)
trap 'rm -f "$test_binary"' EXIT
flags=(-std=c11 -O2 -Wall -Wextra -Werror)
if [[ "${SANITIZE:-0}" == 1 ]]; then
    flags+=(-g -fsanitize=address,undefined -fno-omit-frame-pointer)
fi
"${CC:-cc}" "${flags[@]}" tests/tetris_host_test.c -o "$test_binary"
"$test_binary" "$@"
