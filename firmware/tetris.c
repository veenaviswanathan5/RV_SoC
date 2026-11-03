/* RV32 falling-block game. No libc, heap, interrupts or RTL changes required.
 * Host contract: 320x240 ARGB8888, keys at +4, milliseconds at +12.
 * Gameplay is a compact Tetris-style implementation, not guideline/SRS rules.
 */
#include <stdint.h>

enum { BW=10, BH=20, CELL=10, BX=16, BY=20 };
enum { LEFT=1, RIGHT=2, UP=4, DOWN=8, SPACE=16, ESC=32 };
enum { TITLE, PLAY, PAUSE, OVER };
#ifdef TETRIS_HOST_TEST
static uint32_t host_pixels[320*240];
#define FB host_pixels
#else
#define FB ((volatile uint32_t *)0x20000000u)
#define KEY_REG (*(volatile uint32_t *)0x30000004u)
#define TIME_REG (*(volatile uint32_t *)0x3000000cu)
#endif

typedef struct {
    uint8_t board[BH][BW];
    uint8_t bag[7];
    int bag_pos, piece, next, rotation, x, y, mode;
    uint32_t rng, score, best, lines;
    uint32_t gravity_time, horizontal_time, soft_time, ground_time;
    uint32_t previous_keys;
    int horizontal_dir, repeating, grounded, chord;
} Game;
static Game g;
static const uint16_t shapes[7]={0x00f0,0x0033,0x0072,0x0036,0x0063,0x0071,0x0074};
static const uint32_t colours[8]={0xff111e30,0xff32d8ed,0xffffd45a,0xffb58aff,
    0xff66dd91,0xffff687d,0xff558fff,0xffffa55b};
static uint8_t cached[BH][BW];
static int last_mode=-1, last_next=-1;
static uint32_t last_score=~0u,last_lines=~0u,last_best=~0u;

static int occupied(int piece,int rotation,int x,int y) {
    int n=(piece==0)?4:(piece==1)?2:3;
    if(x<0 || y<0 || x>=n || y>=n) return 0;
    if(piece==1) rotation=0;
    for(int i=0;i<(rotation&3);i++) {
        int old_x=x; x=y; y=n-1-old_x;
    }
    return (shapes[piece]>>(y*4+x))&1;
}
static int fits(int piece,int rotation,int x,int y) {
    for(int row=0;row<4;row++) for(int col=0;col<4;col++) {
        if(!occupied(piece,rotation,col,row)) continue;
        int xx=x+col, yy=y+row;
        if(xx<0 || xx>=BW || yy<0 || yy>=BH) return 0;
        if(g.board[yy][xx]) return 0;
    }
    return 1;
}
static uint32_t random32(void) {
    g.rng ^= g.rng<<13; g.rng ^= g.rng>>17; g.rng ^= g.rng<<5;
    return g.rng;
}
static int take_piece(void) {
    if(g.bag_pos>=7) {
        for(int i=0;i<7;i++) g.bag[i]=(uint8_t)i;
        for(int i=6;i>0;i--) {
            int j=(int)(random32()%(uint32_t)(i+1));
            uint8_t t=g.bag[i]; g.bag[i]=g.bag[j]; g.bag[j]=t;
        }
        g.bag_pos=0;
    }
    return g.bag[g.bag_pos++];
}
static void add_score(uint32_t amount) {
    /* Saturating score avoids a wrapped scoreboard in a very long session. */
    g.score=(~0u-g.score<amount)?~0u:g.score+amount;
    if(g.score>g.best) g.best=g.score;
}
static uint32_t level(void) { return g.lines/10u+1u; }
static uint32_t interval(void) {
    uint32_t l=level(); return l>=13u?100u:760u-(l-1u)*55u;
}
static void spawn(uint32_t now) {
    g.piece=g.next; g.next=take_piece(); g.rotation=0;
    g.x=3; g.y=0; g.grounded=0; g.gravity_time=now;
    g.soft_time=now;
    if(!fits(g.piece,0,g.x,g.y)) g.mode=OVER;
}
static void start_game(uint32_t now) {
    for(int y=0;y<BH;y++) for(int x=0;x<BW;x++) g.board[y][x]=0;
    g.score=0; g.lines=0; g.rng=now^0x6d2b79f5u;
    if(!g.rng) g.rng=1;
    g.bag_pos=7; g.mode=PLAY; g.horizontal_dir=0;
    g.repeating=0; g.chord=0; g.next=take_piece(); spawn(now);
}
static int clear_lines(void) {
    int destination=BH-1, removed=0;
    for(int y=BH-1;y>=0;y--) {
        int full=1;
        for(int x=0;x<BW;x++) if(!g.board[y][x]) full=0;
        if(full) {removed++; continue;}
        for(int x=0;x<BW;x++) g.board[destination][x]=g.board[y][x];
        destination--;
    }
    while(destination>=0) {
        for(int x=0;x<BW;x++) g.board[destination][x]=0;
        destination--;
    }
    return removed;
}
static void lock_piece(uint32_t now) {
    for(int y=0;y<4;y++) for(int x=0;x<4;x++)
        if(occupied(g.piece,g.rotation,x,y))
            g.board[g.y+y][g.x+x]=(uint8_t)(g.piece+1);
    int removed=clear_lines();
    static const uint32_t points[5]={0,100,300,500,800};
    add_score(points[removed]*level());
    g.lines+=(uint32_t)removed;
    spawn(now);
}
static int move_piece(int dx,int dy) {
    if(!fits(g.piece,g.rotation,g.x+dx,g.y+dy)) return 0;
    g.x+=dx; g.y+=dy; return 1;
}
static void rotate_piece(void) {
    /* Simple bounded kicks. This is intentionally not the official SRS table. */
    static const int kicks[7][2]={{0,0},{-1,0},{1,0},{-2,0},{2,0},{0,-1},{0,-2}};
    if(g.piece==1) return;
    int r=(g.rotation+1)&3;
    for(int i=0;i<7;i++) {
        if(fits(g.piece,r,g.x+kicks[i][0],g.y+kicks[i][1])) {
            g.x+=kicks[i][0]; g.y+=kicks[i][1]; g.rotation=r; return;
        }
    }
}
static void hard_drop(uint32_t now) {
    uint32_t distance=0;
    while(move_piece(0,1)) distance++;
    add_score(distance*2u); lock_piece(now);
}
static void update(uint32_t now,uint32_t keys) {
    uint32_t pressed=keys&~g.previous_keys;
    g.previous_keys=keys;
    if(g.mode==TITLE || g.mode==OVER) {
        if(pressed&SPACE) start_game(now);
        return;
    }
    int chord=((keys&(UP|DOWN))==(UP|DOWN));
    if(chord && !g.chord) {
        g.mode=(g.mode==PAUSE)?PLAY:PAUSE;
        g.gravity_time=g.soft_time=g.ground_time=now;
        g.horizontal_dir=0;
    }
    g.chord=chord;
    if(g.mode==PAUSE || chord) return;
    if(pressed&SPACE) {hard_drop(now); return;}
    if(pressed&UP) rotate_piece();
    int direction=((keys&RIGHT)!=0)-((keys&LEFT)!=0);
    if(direction!=g.horizontal_dir) {
        g.horizontal_dir=direction; g.horizontal_time=now; g.repeating=0;
        if(direction) move_piece(direction,0);
    } else if(direction && (uint32_t)(now-g.horizontal_time)>=(g.repeating?65u:180u)) {
        move_piece(direction,0); g.horizontal_time=now; g.repeating=1;
    }
    if((keys&DOWN) && ((pressed&DOWN) || (uint32_t)(now-g.soft_time)>=40u)) {
        if(move_piece(0,1)) add_score(1);
        g.soft_time=now; g.gravity_time=now;
    } else if((uint32_t)(now-g.gravity_time)>=interval()) {
        move_piece(0,1); g.gravity_time=now;
    }
    if(fits(g.piece,g.rotation,g.x,g.y+1)) g.grounded=0;
    else if(!g.grounded) {g.grounded=1; g.ground_time=now;}
    else if((uint32_t)(now-g.ground_time)>=400u) lock_piece(now);
}

/* Small built-in 5x7 font: columns, least-significant bit at the top. */
static const uint8_t font[36][5]={
 {0x3e,0x51,0x49,0x45,0x3e},{0,0x42,0x7f,0x40,0},{0x42,0x61,0x51,0x49,0x46},
 {0x21,0x41,0x45,0x4b,0x31},{0x18,0x14,0x12,0x7f,0x10},{0x27,0x45,0x45,0x45,0x39},
 {0x3c,0x4a,0x49,0x49,0x30},{1,0x71,9,5,3},{0x36,0x49,0x49,0x49,0x36},
 {6,0x49,0x49,0x29,0x1e},
 {0x7e,0x11,0x11,0x11,0x7e},{0x7f,0x49,0x49,0x49,0x36},
 {0x3e,0x41,0x41,0x41,0x22},{0x7f,0x41,0x41,0x22,0x1c},
 {0x7f,0x49,0x49,0x49,0x41},{0x7f,9,9,9,1},{0x3e,0x41,0x49,0x49,0x7a},
 {0x7f,8,8,8,0x7f},{0,0x41,0x7f,0x41,0},{0x20,0x40,0x41,0x3f,1},
 {0x7f,8,0x14,0x22,0x41},{0x7f,0x40,0x40,0x40,0x40},
 {0x7f,2,0x0c,2,0x7f},{0x7f,4,8,0x10,0x7f},{0x3e,0x41,0x41,0x41,0x3e},
 {0x7f,9,9,9,6},{0x3e,0x41,0x51,0x21,0x5e},{0x7f,9,0x19,0x29,0x46},
 {0x46,0x49,0x49,0x49,0x31},{1,1,0x7f,1,1},{0x3f,0x40,0x40,0x40,0x3f},
 {0x1f,0x20,0x40,0x20,0x1f},{0x3f,0x40,0x38,0x40,0x3f},
 {0x63,0x14,8,0x14,0x63},{7,8,0x70,8,7},{0x61,0x51,0x49,0x45,0x43}
};
static void rect(int x,int y,int w,int h,uint32_t colour) {
    /* Clipping keeps renderer safe if future layouts change. */
    if(x<0) {w+=x;x=0;} if(y<0) {h+=y;y=0;}
    if(x+w>320) w=320-x;
    if(y+h>240) h=240-y;
    for(int yy=0;yy<h;yy++) for(int xx=0;xx<w;xx++) FB[(y+yy)*320+x+xx]=colour;
}
static void text(int x,int y,const char *s,uint32_t colour,int scale) {
    while(*s) {
        int index=(*s>='0'&&*s<='9')?*s-'0':(*s>='A'&&*s<='Z')?*s-'A'+10:-1;
        if(index>=0) for(int col=0;col<5;col++) for(int row=0;row<7;row++)
            if(font[index][col]&(1u<<row)) rect(x+col*scale,y+row*scale,scale,scale,colour);
        x+=6*scale; s++;
    }
}
static void number(int x,int y,uint32_t n) {
    char digits[11]; int i=10; digits[i]=0;
    do {digits[--i]=(char)('0'+n%10u);n/=10u;} while(n);
    text(x,y,&digits[i],0xffe3edf7,1);
}
static void tile(int x,int y,uint8_t value) {
    rect(x,y,CELL,CELL,0xff0b1322);
    if(value&0x80) {
        uint32_t c=0xff37516c;
        rect(x+1,y+1,8,1,c);rect(x+1,y+8,8,1,c);
        rect(x+1,y+1,1,8,c);rect(x+8,y+1,1,8,c);
    } else if(value) {
        rect(x+1,y+1,8,8,colours[value]);
        rect(x+2,y+2,6,1,0xffe3edf7);
    } else rect(x+1,y+1,8,8,colours[0]);
}
static void invalidate(void) {
    for(int y=0;y<BH;y++) for(int x=0;x<BW;x++) cached[y][x]=255;
    last_score=last_lines=last_best=~0u;last_next=-1;
}
static void render(void) {
    int mode_changed=(last_mode!=g.mode);
    if(mode_changed) {
        rect(0,0,320,240,0xff080f1c);
        text(16,6,"RV32",0xff7fa4c6,1);
        text(140,18,"TETRIS",0xffe3edf7,2);
        text(140,38,"BARE METAL RV32IM",0xff7fa4c6,1);
        rect(BX-2,BY-2,104,204,0xff37516c);
        text(140,54,"SCORE",0xff7fa4c6,1);
        text(140,78,"LINES",0xff7fa4c6,1);
        text(224,78,"LEVEL",0xff7fa4c6,1);
        text(140,102,"BEST",0xff7fa4c6,1);
        text(140,126,"NEXT",0xff7fa4c6,1);
        text(140,176,"ARROWS MOVE",0xff7fa4c6,1);
        text(140,187,"UP ROTATE  DOWN SOFT",0xff7fa4c6,1);
        text(140,198,"SPACE DROP",0xff7fa4c6,1);
        text(140,209,"UP AND DOWN PAUSE",0xff7fa4c6,1);
        text(140,220,"ESC EXIT",0xff7fa4c6,1);
        invalidate(); last_mode=g.mode;
    }
    uint8_t view[BH][BW];
    for(int y=0;y<BH;y++) for(int x=0;x<BW;x++) view[y][x]=g.board[y][x];
    if(g.mode==PLAY || g.mode==PAUSE) {
        int gy=g.y;
        while(fits(g.piece,g.rotation,g.x,gy+1)) gy++;
        for(int y=0;y<4;y++) for(int x=0;x<4;x++) if(occupied(g.piece,g.rotation,x,y)) {
            view[gy+y][g.x+x]=0x80;
        }
        for(int y=0;y<4;y++) for(int x=0;x<4;x++) if(occupied(g.piece,g.rotation,x,y))
            view[g.y+y][g.x+x]=(uint8_t)(g.piece+1);
    }
    for(int y=0;y<BH;y++) for(int x=0;x<BW;x++) if(view[y][x]!=cached[y][x]) {
        tile(BX+x*CELL,BY+y*CELL,view[y][x]); cached[y][x]=view[y][x];
    }
    if(g.score!=last_score) {rect(140,65,120,9,0xff080f1c);number(140,65,g.score);last_score=g.score;}
    if(g.lines!=last_lines) {
        rect(140,89,170,9,0xff080f1c);number(140,89,g.lines);number(224,89,level());last_lines=g.lines;
    }
    if(g.best!=last_best) {rect(140,113,120,9,0xff080f1c);number(140,113,g.best);last_best=g.best;}
    if(g.next!=last_next || mode_changed) {
        rect(140,137,45,35,0xff080f1c);
        if(g.mode!=TITLE) for(int y=0;y<4;y++) for(int x=0;x<4;x++)
            if(occupied(g.next,0,x,y)) tile(140+x*CELL,137+y*CELL,(uint8_t)(g.next+1));
        last_next=g.next;
    }
    if(mode_changed && g.mode!=PLAY) {
        rect(BX+3,94,94,48,0xff162941);
        const char *message=g.mode==TITLE?"READY":g.mode==PAUSE?"PAUSED":"GAME OVER";
        text(BX+8,102,message,0xffe3edf7,1);
        text(BX+8,120,g.mode==PAUSE?"UP AND DOWN":"PRESS SPACE",0xff66dd91,1);
    }
}
#ifndef TETRIS_HOST_TEST
static void console(const char *s) {
    while(*s) *(volatile uint32_t *)0x30000000u=(uint32_t)(uint8_t)*s++;
}
int main(void) {
    console("RV32 Tetris: SPACE starts, ESC exits. Timer MMIO 0x3000000C.\n");
    g.mode=TITLE;
    render();
    uint32_t last_frame=TIME_REG;
    for(;;) {
        uint32_t keys=KEY_REG, now=TIME_REG;
        if(keys&ESC) {console("Tetris exited normally.\n");return 0;}
        /* No catch-up bursts after a slow frame; this is a host-paced game. */
        if((uint32_t)(now-last_frame)>=16u) {
            last_frame=now; update(now,keys); render();
        }
    }
}
#endif
