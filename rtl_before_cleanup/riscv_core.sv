`timescale 1ns / 1ps

module riscv_core(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        cpu_stall, 
    
    // Instruction Memory Interface
    output logic [31:0] instrAddr,
    input  logic [31:0] instrData,
    
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

    // Hazard Wires
    logic stallF, stallD, stallE, flushD, flushE, flushM, stallM, stallW;
    logic stallF_m, stallD_m, stallE_m, stall_AXI;
    logic [1:0] forwardAE, forwardBE;

    // Stage 1 (Fetch) Wires
    logic [31:0] PCF, PCPlus4F, instrF;
    logic        boot_stall;

    // Stage 2 (Decode) Wires
    logic [31:0] instrD, PCD, PCPlus4D, immExtD, safe_rd1D, rd2D;
    logic [4:0]  rdD, safe_rs1D;
    logic [3:0]  aluControlD;
    logic [2:0]  funct3D;
    logic [1:0]  resultSrcD;
    logic        regWriteD, memWriteD, jumpD, branchD, jalrD, aluSrcAD, aluSrcBD;
    logic        is_mulD, is_mul_upperD, is_divD, is_remD, is_rs1_signedD, is_rs2_signedD;

    // Stage 3 (Execute) Wires
    logic [31:0] PCE, PCPlus4E, rd1E, rd2E, immExtE, aluResultE, writeDataE, PCTargetE;
    logic [4:0]  rdE, rs1E, rs2E;
    logic [3:0]  aluControlE;
    logic [2:0]  funct3E;
    logic [1:0]  resultSrcE, PCSrcE;
    logic        regWriteE, memWriteE, jumpE, branchE, jalrE, aluSrcAE, aluSrcBE;
    logic        is_mulE, is_mul_upperE, is_divE, is_remE, is_rs1_signedE, is_rs2_signedE;

    // Stage 4 (Memory) Wires
    logic [31:0] PCPlus4M, PCTargetM, aluResultM, writeDataM, formatted_readDataM;
    logic [4:0]  rdM;
    logic [2:0]  funct3M;
    logic [1:0]  resultSrcM;
    logic        regWriteM, memWriteM;

    // Stage 5 (Writeback) Wires
    logic [31:0] PCPlus4W, PCTargetW, aluResultW, readDataW, resultW;
    logic [4:0]  rdW;
    logic [1:0]  resultSrcW;
    logic        regWriteW;

    // -----------------------------------------------------------------------
    // STAGE INSTANTIATIONS
    // -----------------------------------------------------------------------

    rv32_stage1_fetch stage1 (
        .clk(clk), .rst_n(rst_n), .stallF(stallF),
        .PCSrcE(PCSrcE), .PCTargetE(PCTargetE), .aluResultE(aluResultE),
        .instrData(instrData), .instrAddr(instrAddr), .instrF(instrF),
        .PCF(PCF), .PCPlus4F(PCPlus4F), .boot_stall(boot_stall)
    );

    pipelineReg #(.WIDTH(96)) pipelineReg_F_D (
        .clk(clk), .rst_n(rst_n), .en(~stallD), .clr(flushD | boot_stall),
        .d({(flushD ? 32'h00000013 : instrF), PCF, PCPlus4F}), 
        .q({instrD, PCD, PCPlus4D}) 
    );

    rv32_stage2_decode stage2 (
        .clk(clk), .instrD(instrD),
        .regWriteW(regWriteW), .rdW(rdW), .resultW(resultW),
        .regWriteD(regWriteD), .resultSrcD(resultSrcD), .memWriteD(memWriteD),
        .jumpD(jumpD), .branchD(branchD), .jalrD(jalrD),
        .aluControlD(aluControlD), .aluSrcAD(aluSrcAD), .aluSrcBD(aluSrcBD),
        .safe_rd1D(safe_rd1D), .rd2D(rd2D), .immExtD(immExtD),
        .rdD(rdD), .safe_rs1D(safe_rs1D), .funct3D(funct3D),
        .is_mulD(is_mulD), .is_mul_upperD(is_mul_upperD), .is_divD(is_divD), 
        .is_remD(is_remD), .is_rs1_signedD(is_rs1_signedD), .is_rs2_signedD(is_rs2_signedD)
    );

    pipelineReg #(.WIDTH(197)) pipelineReg_D_E (
        .clk(clk), .rst_n(rst_n), .en(~stallE), .clr(flushE),
        .d({(regWriteD & ~flushE), resultSrcD, (memWriteD & ~flushE), (jumpD & ~flushE), 
            (branchD & ~flushE), (jalrD & ~flushE), aluControlD, aluSrcAD, aluSrcBD, 
            safe_rd1D, rd2D, PCD, immExtD, PCPlus4D, rdD, funct3D, safe_rs1D, instrD[24:20], 
            is_mulD, is_mul_upperD, is_divD, is_remD, is_rs1_signedD, is_rs2_signedD}),
        .q({regWriteE, resultSrcE, memWriteE, jumpE, branchE, jalrE,
            aluControlE, aluSrcAE, aluSrcBE, rd1E, rd2E, PCE, immExtE, PCPlus4E, rdE, funct3E,
            rs1E, rs2E, is_mulE, is_mul_upperE, is_divE, is_remE, is_rs1_signedE, is_rs2_signedE})
    );

    rv32_stage3_execute stage3 (
        .clk(clk), .rst_n(rst_n), .pipeline_hold(stall_AXI | cpu_stall),
        .jumpE(jumpE), .branchE(branchE), .jalrE(jalrE), .aluSrcAE(aluSrcAE), .aluSrcBE(aluSrcBE),
        .aluControlE(aluControlE), .rd1E(rd1E), .rd2E(rd2E), .PCE(PCE), .immExtE(immExtE),
        .funct3E(funct3E), .forwardAE(forwardAE), .forwardBE(forwardBE),
        .resultW(resultW), .aluResultM(aluResultM),
        .is_mulE(is_mulE), .is_mul_upperE(is_mul_upperE), .is_divE(is_divE), .is_remE(is_remE), 
        .is_rs1_signedE(is_rs1_signedE), .is_rs2_signedE(is_rs2_signedE),
        .aluResultE(aluResultE), .writeDataE(writeDataE), .PCTargetE(PCTargetE),
        .PCSrcE(PCSrcE), .stallF_m(stallF_m), .stallD_m(stallD_m), .stallE_m(stallE_m)
    );

    hazardHandler hazardUnitInstance (
        .rs1E(rs1E), .rs2E(rs2E), .rs1D(instrD[19:15]), .rs2D(instrD[24:20]),
        .rdM(rdM), .rdW(rdW), .rdE(rdE),
        .regWriteM(regWriteM), .regWriteW(regWriteW),
        .resultSrcE0(resultSrcE == 2'b01), .PCSrcE(PCSrcE != 2'b00),
        .forwardAE(forwardAE), .forwardBE(forwardBE),
        .stallF_m(stallF_m), .stallD_m(stallD_m), .stallE_m(stallE_m),
        .stallAXI(stall_AXI), .stall_cache(cpu_stall),
        .flushE(flushE), .flushM(flushM), .flushD(flushD),
        .stallF(stallF), .stallD(stallD), .stallE(stallE), .stallM(stallM), .stallW(stallW) 
    );

    // =======================================================================
    // UNIVERSAL FORWARDING MULTIPLEXER
    // =======================================================================
    logic [31:0] trueResultE;
    always_comb begin
        case (resultSrcE)
            2'b00: trueResultE = aluResultE; // Normal ALU Operations
            2'b01: trueResultE = aluResultE; // Memory Load Addresses
            2'b10: trueResultE = PCPlus4E;   // JAL / JALR Return Addresses
            2'b11: trueResultE = PCTargetE;  // AUIPC Calculated Addresses
            default: trueResultE = aluResultE;
        endcase
    end

    pipelineReg #(.WIDTH(140)) EX_MEM_Reg (
        .clk(clk), .rst_n(rst_n), .en(~stallM), .clr(flushM), 
        .d({(regWriteE & ~flushM), resultSrcE, (memWriteE & ~flushM), 
            trueResultE, writeDataE, rdE, PCPlus4E, funct3E, PCTargetE}), // <-- swapped here!
        .q({regWriteM, resultSrcM, memWriteM, aluResultM, writeDataM, rdM, PCPlus4M, funct3M, PCTargetM}) 
    );

    rv32_stage4_memory stage4 (
        .clk(clk), .rst_n(rst_n),
        .resultSrcM(resultSrcM), .memWriteM(memWriteM), .aluResultM(aluResultM), 
        .writeDataM(writeDataM), .funct3M(funct3M),
        .formatted_readDataM(formatted_readDataM), .stall_AXI(stall_AXI),
        .axi_awaddr(axi_awaddr), .axi_wdata(axi_wdata), .axi_wstrb(axi_wstrb),
        .axi_awvalid(axi_awvalid), .axi_wvalid(axi_wvalid), .axi_bready(axi_bready),
        .axi_awready(axi_awready), .axi_wready(axi_wready), .axi_bvalid(axi_bvalid), .axi_bresp(axi_bresp),
        .axi_araddr(axi_araddr), .axi_arvalid(axi_arvalid), .axi_rready(axi_rready),
        .axi_arready(axi_arready), .axi_rvalid(axi_rvalid), .axi_rdata(axi_rdata), .axi_rresp(axi_rresp)
    );

    pipelineReg #(.WIDTH(136)) MEM_WB_Reg (
        .clk(clk), .rst_n(rst_n), .en(~stallW), .clr(1'b0), 
        .d({regWriteM, resultSrcM, aluResultM, formatted_readDataM, rdM, PCPlus4M, PCTargetM}),
        .q({regWriteW, resultSrcW, aluResultW, readDataW, rdW, PCPlus4W, PCTargetW})
    );

    rv32_stage5_writeback stage5 (
        .resultSrcW(resultSrcW), .aluResultW(aluResultW), .readDataW(readDataW), 
        .PCPlus4W(PCPlus4W), .PCTargetW(PCTargetW),
        .regWriteW(regWriteW), .rdW(rdW),
        .resultW(resultW)
    );

endmodule