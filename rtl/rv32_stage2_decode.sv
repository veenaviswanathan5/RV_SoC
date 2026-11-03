`timescale 1ns / 1ps

module rv32_stage2_decode (
    input  logic        clk,
    input  logic [31:0] instrD,
    input  logic        regWriteW,
    input  logic [4:0]  rdW,
    input  logic [31:0] resultW,
    
    output logic        regWriteD,
    output logic [1:0]  resultSrcD,
    output logic        memWriteD,
    output logic        jumpD,
    output logic        branchD,
    output logic        jalrD,
    output logic [3:0]  aluControlD,
    output logic        aluSrcAD,
    output logic        aluSrcBD,
    output logic [31:0] safe_rd1D,
    output logic [31:0] rd2D,
    output logic [31:0] immExtD,
    output logic [4:0]  rdD,
    output logic [4:0]  safe_rs1D,
    output logic [2:0]  funct3D,
    
    // M-Extension Control
    output logic        is_mulD,
    output logic        is_mul_upperD,
    output logic        is_divD,
    output logic        is_remD,
    output logic        is_rs1_signedD,
    output logic        is_rs2_signedD
);

    logic [31:0] rd1D;
    logic [2:0]  immSrcD;
    logic [2:0]  aluOpD;
    logic [2:0]  funct3_safe;
    logic        funct7_5_safe, funct7_0_safe;
    logic        is_luiD;

    assign rdD = instrD[11:7];
    assign funct3D = instrD[14:12]; 
    assign aluSrcAD = 1'b0; // Tie-off for AUIPC support

    // Safe funct masking
    always_comb begin
        if (instrD[6:0] == 7'b0110111 || instrD[6:0] == 7'b0010111 || instrD[6:0] == 7'b1101111) begin
            funct3_safe   = 3'b000;
            funct7_5_safe = 1'b0;
            funct7_0_safe = 1'b0;
        end else begin
            funct3_safe   = instrD[14:12];
            funct7_5_safe = instrD[30];
            funct7_0_safe = instrD[25];
        end
    end

    controlDecoder ctrlDecInst (
        .opcode(instrD[6:0]), .funct7_0(funct7_0_safe),
        .branch(branchD), .resultSrc(resultSrcD), .memWrite(memWriteD),
        .aluOp(aluOpD), .aluSrc(aluSrcBD), .immSrc(immSrcD),
        .regWrite(regWriteD), .jump(jumpD), .jalr(jalrD)
    );

    aluDecoder aluDecInst (
        .aluOp(aluOpD), .funct3(funct3_safe), .funct7_5(funct7_5_safe), .funct7_0(funct7_0_safe),
        .ALUControl(aluControlD),
        .is_mul(is_mulD), .is_mul_upper(is_mul_upperD), .is_div(is_divD), .is_rem(is_remD),
        .is_rs1_signed(is_rs1_signedD), .is_rs2_signed(is_rs2_signedD)
    );
    
    regFile regFileInstance(
        .clk(clk), .we(regWriteW), .a3(rdW), .wd3(resultW),       
        .a1(instrD[19:15]), .a2(instrD[24:20]), .rd1(rd1D), .rd2(rd2D)
    );
    
    immExtend immExtendInstance(
        .instr(instrD[31:7]), .immSrc(immSrcD), .immExt(immExtD)
    );
    
    // LUI Uninitialized Register Trap
    assign is_luiD = (instrD[6:0] == 7'b0110111);
    assign safe_rd1D = is_luiD ? 32'b0 : rd1D;
    assign safe_rs1D = is_luiD ? 5'b0 : instrD[19:15];

endmodule
