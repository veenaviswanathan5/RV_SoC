#define TETRIS_HOST_TEST
#include "../firmware/tetris.c"
#include "tetris_checks.h"
#include <stdio.h>
#include <string.h>

static int save_preview(const char *name) {
    reset_test_game();start_game(1234);
    for(int y=16;y<20;y++) for(int x=0;x<BW;x++)
        if((x*3+y)%5!=0 && x!=6) g.board[y][x]=(uint8_t)(1+(x+y)%7);
    g.piece=2;g.rotation=0;g.x=3;g.y=7;g.next=0;
    g.score=1240;g.lines=12;g.best=2800;
    render();
    FILE *f=fopen(name,"wb");if(!f)return 1;
    fprintf(f,"P6\n320 240\n255\n");
    for(int i=0;i<320*240;i++) {
        uint32_t p=FB[i];unsigned char rgb[3]={(unsigned char)(p>>16),(unsigned char)(p>>8),(unsigned char)p};
        if(fwrite(rgb,1,3,f)!=3){fclose(f);return 1;}
    }
    return fclose(f)!=0;
}
int main(int argc,char **argv) {
    int result=run_checks();
    if(result) {fprintf(stderr,"FAIL: tetris_checks.h line %d\n",result);return 1;}
    puts("Tetris tests passed: rules, timing, rendering, 12000-step deterministic input test.");
    if(argc==3 && strcmp(argv[1],"--preview")==0)return save_preview(argv[2]);
    return 0;
}
