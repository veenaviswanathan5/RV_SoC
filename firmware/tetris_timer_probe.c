#include <stdint.h>
static void say(const char *s) {
    while(*s) *(volatile uint32_t *)0x30000000u=(uint32_t)(uint8_t)*s++;
}
int main(void) {
    volatile uint32_t *timer=(volatile uint32_t *)0x3000000cu;
    uint32_t first=*timer;
    for(uint32_t i=0;i<2000000u;i++) {
        uint32_t elapsed=(uint32_t)(*timer-first);
        if(elapsed>=20u && elapsed<60000u) {
            say("Tetris timer probe PASS: millisecond register advances\n");return 0;
        }
    }
    say("Tetris timer probe FAIL: no usable time advance at 0x3000000C\n");return 1;
}
