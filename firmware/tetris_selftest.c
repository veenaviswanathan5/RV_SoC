/* Same checks as the host test, executed by the custom RISC-V CPU.
 * TETRIS_HOST_TEST selects an ordinary RAM framebuffer, so this is headless.
 */
#define TETRIS_HOST_TEST
#include "tetris.c"
#include "../tests/tetris_checks.h"
static void put_string(const char *s) {
    while(*s) *(volatile uint32_t *)0x30000000u=(uint32_t)(uint8_t)*s++;
}
static void put_number(unsigned n) {
    char digits[11];int i=10;digits[i]=0;
    do {digits[--i]=(char)('0'+n%10);n/=10;}while(n);
    put_string(&digits[i]);
}
int main(void) {
    put_string("Tetris RV32 self-test starting\n");
    int result=run_checks();
    if(result) {put_string("FAIL tetris_checks.h line ");put_number((unsigned)result);put_string("\n");return result;}
    put_string("Tetris RV32 self-test PASS\n");return 0;
}
