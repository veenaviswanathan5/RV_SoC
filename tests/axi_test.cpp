#include "../axi_slave.h"
#include <cassert>
struct CPU {
    unsigned rst_n=1;
    unsigned axi_awready=0,axi_wready=0,axi_bvalid=0,axi_bresp=0,axi_arready=0,axi_rvalid=0,axi_rdata=0,axi_rresp=0;
    unsigned axi_bready=0,axi_rready=0,axi_awvalid=0,axi_awaddr=0,axi_wvalid=0,axi_wdata=0,axi_wstrb=0,axi_arvalid=0,axi_araddr=0;
};
int main() {
    AxiSlave s; CPU c;
    auto tick=[&] {s.drive(c); s.sample(c);};
    // W arrives before AW; no store until both are accepted.
    c.axi_wvalid=1; c.axi_wdata=0x11223344; c.axi_wstrb=15; tick();
    assert(s.read(s.RAM_BASE)==0 && !s.bv);
    c.axi_wvalid=0; tick(); assert(!c.axi_wready);
    c.axi_awvalid=1; c.axi_awaddr=s.RAM_BASE; tick();
    assert(s.read(s.RAM_BASE)==0x11223344 && s.bv);
    c.axi_awvalid=0;
    for(int i=0;i<5;i++) {tick(); assert(c.axi_bvalid && !c.axi_awready && !c.axi_wready);}
    c.axi_bready=1; tick(); c.axi_bready=0;
    // AW arrives first; byte lane masking preserves other bytes.
    c.axi_awvalid=1; c.axi_awaddr=s.RAM_BASE+1; tick(); c.axi_awvalid=0;
    assert(!s.bv);
    c.axi_wvalid=1; c.axi_wdata=0x0000aa00; c.axi_wstrb=2; tick(); c.axi_wvalid=0;
    assert(s.read(s.RAM_BASE)==0x1122aa44);
    c.axi_bready=1; tick(); c.axi_bready=0;
    c.axi_arvalid=1; c.axi_araddr=s.RAM_BASE+1; tick(); c.axi_arvalid=0;
    for(int i=0;i<5;i++) {tick(); assert(c.axi_rvalid && c.axi_rdata==0x1122aa44 && !c.axi_arready);}
    c.axi_rready=1; tick(); assert(!s.rv);
    s.write(s.VRAM_BASE,0xff123456,15); s.write(s.VRAM_BASE+2,0x00ab0000,4);
    assert(s.pixels[0]==0xffab3456);
    c.rst_n=0; tick(); assert(!s.aw&&!s.wd&&!s.bv&&!s.rv);
    bool threw=false; try{s.write(0,1,15);}catch(const std::runtime_error&){threw=true;} assert(threw);
    s.write(s.EXIT,0,15); assert(s.exited && s.exit_code==0);
    std::cout<<"AXI slave tests passed\n";
}
