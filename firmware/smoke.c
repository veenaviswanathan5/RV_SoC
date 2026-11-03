#include <stdint.h>
static volatile uint32_t initialized=0x12345678;
static volatile uint32_t zeroed;
static volatile int32_t a=-37,b=5;
static volatile uint32_t u=0x80000000u,v=3;
int main(void) {
    if(initialized!=0x12345678 || zeroed!=0) return 1;
    volatile uint32_t *p=(volatile uint32_t *)0x10001000;
    *p=0x11223344;
    ((volatile uint8_t *)p)[1]=0xaa;
    ((volatile uint16_t *)p)[1]=0xbbcc;
    if(*p!=0xbbccaa44) return 2;
    if(a*b!=-185 || a/b!=-7 || a%b!=-2) return 3;
    if(u/v!=715827882u || u%v!=2) return 4;
    b=0;
    int32_t q,r,aa=a,bb=b;
    __asm__ volatile("div %0,%1,%2" : "=r"(q) : "r"(aa),"r"(bb));
    __asm__ volatile("rem %0,%1,%2" : "=r"(r) : "r"(aa),"r"(bb));
    if(q!=-1 || r!=aa) return 5; // Assembly avoids C division-by-zero UB.
    *(volatile uint32_t *)0x20000000=0xff00ff00;
    *(volatile uint32_t *)0x30000000='O';
    *(volatile uint32_t *)0x30000000='K';
    *(volatile uint32_t *)0x30000000='\n';
    return 0;
}
