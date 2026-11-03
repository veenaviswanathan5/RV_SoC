`timescale 1ns / 1ps

module rv32_stage4_memory (
    input  logic        clk,
    input  logic        rst_n,
    
    // CPU Interfaces
    input  logic [1:0]  resultSrcM,
    input  logic        memWriteM,
    input  logic [31:0] aluResultM,
    input  logic [31:0] writeDataM,
    input  logic [2:0]  funct3M,
    
    output logic [31:0] formatted_readDataM,
    output logic        stall_AXI,
    
    // AXI4-Lite Data Memory Interface
    output logic [31:0] axi_awaddr, axi_wdata,
    output logic [3:0]  axi_wstrb,
    output logic        axi_awvalid, axi_wvalid, axi_bready,
    input  logic        axi_awready, axi_wready, axi_bvalid,
    input  logic [1:0]  axi_bresp,
    
    output logic [31:0] axi_araddr,
    output logic        axi_arvalid, axi_rready,
    input  logic        axi_arready, axi_rvalid,
    input  logic [31:0] axi_rdata,
    input  logic [1:0]  axi_rresp
);

    logic [31:0] writeDataM_formatted, raw_readDataM;
    logic [3:0]  axi_wstrb_M;

    storeAligner storeAligner_inst (
        .aluResultM_2bit(aluResultM[1:0]), .writeDataM(writeDataM),
        .funct3M(funct3M), .writeDataM_formatted(writeDataM_formatted), .axi_wstrb(axi_wstrb_M)
    );

    loadExtender loadExtender_inst (
        .funct3M(funct3M), .readDataM(raw_readDataM),
        .aluResultM_2bit(aluResultM[1:0]), .readDataM_formatted(formatted_readDataM)
    );
    
    axi4_lite_fsm axi_fsm_inst (
        .clk(clk), .rst_n(rst_n),
        .resultSrcM(resultSrcM), .memWriteM(memWriteM), .aluResultM(aluResultM),
        .writeDataM(writeDataM_formatted), .axi_wstrb_M(axi_wstrb_M),
        
        .axi_awready(axi_awready), .axi_wready(axi_wready), .axi_bresp(axi_bresp), .axi_bvalid(axi_bvalid),
        .axi_arready(axi_arready), .axi_rdata(axi_rdata), .axi_rresp(axi_rresp), .axi_rvalid(axi_rvalid),
        
        .axi_awaddr(axi_awaddr), .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb),
        .axi_awvalid(axi_awvalid), .axi_wvalid(axi_wvalid), .axi_bready(axi_bready),
        .axi_araddr(axi_araddr), .axi_arvalid(axi_arvalid), .axi_rready(axi_rready),
        
        .axi_readDataM(raw_readDataM), .stall_AXI(stall_AXI)
    );

endmodule
