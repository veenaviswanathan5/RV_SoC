/* Shared tests: compiled both natively and as bare-metal RV32 firmware. */
#define CHECK(condition) do { if(!(condition)) return __LINE__; } while(0)
static void reset_test_game(void) {
    unsigned char *p=(unsigned char *)&g;
    for(unsigned i=0;i<sizeof(g);i++) p[i]=0;
    last_mode=-1; invalidate();
}
static int run_checks(void) {
    reset_test_game();
    /* Every rotation of every piece contains exactly four squares. */
    for(int p=0;p<7;p++) for(int r=0;r<4;r++) {
        int n=0;
        for(int y=0;y<4;y++) for(int x=0;x<4;x++) n+=occupied(p,r,x,y);
        CHECK(n==4);
        CHECK(fits(p,r,3,0));
        CHECK(!fits(p,r,-4,0)); CHECK(!fits(p,r,10,0)); CHECK(!fits(p,r,3,20));
    }
    /* Each bag is a permutation; the generator is seeded reproducibly. */
    g.rng=12345; g.bag_pos=7;
    for(int b=0;b<32;b++) {
        unsigned seen=0;
        for(int i=0;i<7;i++) {int p=take_piece();CHECK(p>=0&&p<7);seen|=1u<<p;}
        CHECK(seen==127);
    }
    /* Line compaction, including four-line clears and surviving blocks. */
    for(int count=1;count<=4;count++) {
        reset_test_game();
        g.board[BH-count-1][2]=5;
        for(int y=BH-count;y<BH;y++) for(int x=0;x<BW;x++) g.board[y][x]=1;
        CHECK(clear_lines()==count);
        CHECK(g.board[19][2]==5);
        for(int y=0;y<19;y++) for(int x=0;x<BW;x++) CHECK(g.board[y][x]==0);
    }
    reset_test_game();
    for(int x=0;x<BW;x++) {g.board[17][x]=1;g.board[19][x]=2;}
    g.board[18][0]=3;g.board[16][1]=4;
    CHECK(clear_lines()==2);CHECK(g.board[19][0]==3 && g.board[18][1]==4);
    /* Wall kicks and fully obstructed rotation. */
    reset_test_game();g.piece=0;g.rotation=1;g.x=-2;g.y=2;
    CHECK(fits(0,1,-2,2));rotate_piece();CHECK(g.rotation==2);CHECK(fits(g.piece,g.rotation,g.x,g.y));
    for(int y=0;y<BH;y++) for(int x=0;x<BW;x++) g.board[y][x]=1;
    g.piece=2;g.rotation=0;g.x=3;g.y=4;
    for(int y=0;y<4;y++) for(int x=0;x<4;x++) if(occupied(2,0,x,y)) g.board[4+y][3+x]=0;
    rotate_piece();CHECK(g.rotation==0 && g.x==3 && g.y==4);
    /* Hard drop settles the piece, scores distance, then spawns. */
    reset_test_game();start_game(100);g.piece=1;g.rotation=0;g.x=3;g.y=0;
    hard_drop(101);CHECK(g.score==36);CHECK(g.board[18][3]==2 && g.board[19][4]==2);
    CHECK(g.mode==PLAY);
    /* Four-line clear gives 800 points at level one. */
    reset_test_game();start_game(100);
    for(int y=16;y<20;y++) for(int x=0;x<BW;x++) g.board[y][x]=(x==5)?0:3;
    g.piece=0;g.rotation=1;g.x=3;g.y=16;
    CHECK(fits(0,1,3,16));lock_piece(200);CHECK(g.lines==4 && g.score==800);
    /* Game over on blocked spawn; restart clears board but retains best. */
    reset_test_game();start_game(100);g.best=999;
    for(int x=0;x<BW;x++) for(int y=0;y<4;y++) g.board[y][x]=1;
    spawn(200);CHECK(g.mode==OVER);
    update(300,SPACE);CHECK(g.mode==PLAY && g.score==0 && g.best==999);
    for(int y=0;y<BH;y++) for(int x=0;x<BW;x++) CHECK(g.board[y][x]==0);
    /* Delayed auto-repeat does not repeat immediately on a held arrow. */
    reset_test_game();start_game(0);g.piece=1;g.x=3;g.y=0;
    update(1,LEFT);CHECK(g.x==2);update(100,LEFT);CHECK(g.x==2);
    update(181,LEFT);CHECK(g.x==1);update(246,LEFT);CHECK(g.x==0);
    update(247,0);update(248,RIGHT);CHECK(g.x==1);
    /* Pause freezes gravity. Resume resets timing; held chord doesn't toggle. */
    update(300,UP|DOWN);CHECK(g.mode==PAUSE);int y_before=g.y;
    update(10000,UP|DOWN);CHECK(g.mode==PAUSE && g.y==y_before);
    update(10001,0);update(10002,UP|DOWN);CHECK(g.mode==PLAY);
    update(10003,0);CHECK(g.y==y_before);
    /* Timers compare elapsed unsigned milliseconds through 32-bit wrap. */
    reset_test_game();start_game(0xffffff00u);g.piece=1;g.x=3;g.y=0;
    update(0x00000200u,0);CHECK(g.y==1);
    /* Ground delay: no lock before 400 ms, then exactly one lock. */
    reset_test_game();start_game(0);g.piece=1;g.x=3;g.y=18;
    update(10,0);CHECK(g.grounded);update(409,0);CHECK(!g.board[19][3]);
    update(410,0);CHECK(g.board[19][3]==2);
    /* Held hard drop does not drop multiple consecutive pieces. */
    reset_test_game();start_game(0);update(1,SPACE);uint32_t score=g.score;
    update(2,SPACE);CHECK(g.score==score);
    CHECK(interval()==760);g.lines=120;CHECK(interval()==100);
    g.score=~0u-1u;add_score(8);CHECK(g.score==~0u);
    /* Renderer clips its rectangles and renders without allocation. */
    reset_test_game();start_game(10);render();
    CHECK(FB[(BY+19*CELL+5)*320+BX+5]!=0);
    rect(-10,-10,20,20,0xffabcdef);CHECK(FB[0]==0xffabcdef);
    rect(319,239,20,20,0xff123456);CHECK(FB[320*240-1]==0xff123456);
    /* Deterministic mixed-input runs exercise game-state invariants. */
    reset_test_game();start_game(0);uint32_t rnd=0x12345678,now=0;
    for(int i=0;i<12000;i++) {
        rnd^=rnd<<13;rnd^=rnd>>17;rnd^=rnd<<5;
        now+=17u;uint32_t keys=(rnd>>8)&31u;
        update(now,keys);
        if(g.mode==PLAY || g.mode==PAUSE) CHECK(fits(g.piece,g.rotation,g.x,g.y));
        for(int y=0;y<BH;y++) for(int x=0;x<BW;x++) CHECK(g.board[y][x]<=7);
        if(i%127==0) render();
        if(g.mode==OVER) {update(now+1,0);update(now+2,SPACE);}
    }
    return 0;
}
#undef CHECK
