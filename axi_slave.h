#pragma once
#include <cstdint>
#include <vector>
#include <fstream>
#include <stdexcept>
#include <iostream>

// One outstanding read and write; address/data accepted independently.
struct AxiSlave {
    static constexpr uint32_t RAM_BASE=0x10000000, VRAM_BASE=0x20000000;
    static constexpr uint32_t UART=0x30000000, KEY=0x30000004, EXIT=0x30000008;
    static constexpr unsigned WIDTH=320, HEIGHT=240;
    std::vector<uint8_t> rom=std::vector<uint8_t>(1024*1024);
    std::vector<uint8_t> ram=std::vector<uint8_t>(1024*1024);
    std::vector<uint32_t> pixels=std::vector<uint32_t>(WIDTH*HEIGHT);
    uint32_t keys=0, exit_code=0;
    bool exited=false;
    bool aw=false, wd=false, bv=false, rv=false;
    uint32_t addr=0, data=0, read_data=0;
    uint8_t strb=0;
    static constexpr uint32_t TIMER = 0x3000000C;
    uint32_t timer_ms = 0;


    void load(const char* path) {
        std::ifstream f(path,std::ios::binary|std::ios::ate);
        if(!f) throw std::runtime_error("Cannot open firmware");
        auto n=f.tellg();
        if(n<=0 || uint64_t(n)>rom.size()) throw std::runtime_error("Firmware empty or exceeds 1 MiB ROM");
        f.seekg(0); f.read(reinterpret_cast<char*>(rom.data()),n);
        if(!f) throw std::runtime_error("Firmware read failed");
    }
    static uint32_t word(const std::vector<uint8_t>& v,uint32_t a) {
        return uint32_t(v.at(a)) | uint32_t(v.at(a+1))<<8 |
               uint32_t(v.at(a+2))<<16 | uint32_t(v.at(a+3))<<24;
    }
    uint32_t fetch(uint32_t a) const {
        if((a&3) || uint64_t(a)+4>rom.size()) throw std::runtime_error("Invalid instruction address");
        return word(rom,a);
    }
    uint32_t read(uint32_t a) const {
        a &= ~3u;
        if(a<rom.size()) return word(rom,a);
        if(a>=RAM_BASE && a-RAM_BASE<ram.size()) return word(ram,a-RAM_BASE);
        if(a>=VRAM_BASE && (a-VRAM_BASE)/4<pixels.size()) return pixels[(a-VRAM_BASE)/4];
        if(a==KEY) return keys;
        if(a==UART || a==EXIT) return 0;
        if (a == TIMER) return timer_ms;
        throw std::runtime_error("Unmapped data read at "+std::to_string(a));
    }
    void write(uint32_t a,uint32_t d,uint8_t s) {
        a &= ~3u; // RTL already aligns WDATA and WSTRB to byte lanes.
        if(a==UART) { if(s&1) { std::cout.put(char(d)); std::cout.flush(); } return; }
        if(a==EXIT) { if(s!=15) throw std::runtime_error("EXIT requires a word store"); exited=true; exit_code=d; return; }
        if(a>=RAM_BASE && a-RAM_BASE<ram.size()) {
            for(unsigned i=0;i<4;i++) if(s&(1u<<i)) ram.at(a-RAM_BASE+i)=uint8_t(d>>(8*i));
            return;
        }
        if(a>=VRAM_BASE && (a-VRAM_BASE)/4<pixels.size()) {
            auto& p=pixels[(a-VRAM_BASE)/4];
            for(unsigned i=0;i<4;i++) if(s&(1u<<i)) p=(p&~(255u<<(8*i)))|(d&(255u<<(8*i)));
            return;
        }
        throw std::runtime_error("Write to ROM or unmapped address "+std::to_string(a));
    }
    template<class CPU> void drive(CPU& c) const {
        c.axi_awready=!aw&&!bv; c.axi_wready=!wd&&!bv;
        c.axi_bvalid=bv; c.axi_bresp=0;
        c.axi_arready=!rv; c.axi_rvalid=rv; c.axi_rdata=read_data; c.axi_rresp=0;
    }
    // Call once using settled PRE-rising-edge signals. drive() follows next cycle.
    template<class CPU> void sample(const CPU& c) {
        if(!c.rst_n) { aw=wd=bv=rv=false; return; }
        if(c.axi_bvalid && c.axi_bready) bv=false;
        if(c.axi_rvalid && c.axi_rready) rv=false;
        if(c.axi_awvalid && c.axi_awready) { addr=c.axi_awaddr; aw=true; }
        if(c.axi_wvalid && c.axi_wready) { data=c.axi_wdata; strb=c.axi_wstrb; wd=true; }
        if(aw&&wd&&!bv) { write(addr,data,strb); aw=wd=false; bv=true; }
        if(c.axi_arvalid && c.axi_arready) { read_data=read(c.axi_araddr); rv=true; }
    }
};
