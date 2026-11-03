#include <stdint.h>
#define REG(a) (*(volatile uint32_t *)(a))
int main(void) {
    volatile uint32_t *fb=(volatile uint32_t *)0x20000000;
    const char *s="RV32 framebuffer demo\n";
    while(*s) REG(0x30000000)=(uint32_t)*s++;
    for(unsigned y=0;y<240;y++) for(unsigned x=0;x<320;x++)
        fb[y*320+x]=0xff000000u|((x&255)<<16)|((y&255)<<8)|0x40;
    for(;;) {
        uint32_t k=REG(0x30000004);
        fb[0]=(k&16)?0xffffffff:0xff000000;
        if(k&32) return 0; // Escape exits; Space changes top-left pixel.
    }
}
