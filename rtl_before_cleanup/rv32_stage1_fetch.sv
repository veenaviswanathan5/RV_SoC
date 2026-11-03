`timescale 1ns / 1ps

module rv32_stage1_fetch (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        stallF,
    input  logic [1:0]  PCSrcE,
    input  logic [31:0] PCTargetE,
    input  logic [31:0] aluResultE,
    input  logic [31:0] instrData,
    
    output logic [31:0] instrAddr,
    output logic [31:0] instrF,
    output logic [31:0] PCF,
    output logic [31:0] PCPlus4F,
    output logic        boot_stall
);

    logic [31:0] PCNextF;

    // Boot Stall Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) boot_stall <= 1'b1;
        else        boot_stall <= 1'b0;
    end

    // PC Next Multiplexer (The Feedback Loop)
    always_comb begin
        case(PCSrcE)
            2'b00: PCNextF = PCPlus4F;   // Default: PC + 4
            2'b01: PCNextF = PCTargetE;  // Jumps (JAL) and Taken Branches
            2'b10: PCNextF = {aluResultE[31:1], 1'b0}; // JALR (ALU calculates rs1 + imm)
            default: PCNextF = PCPlus4F; 
        endcase
    end

    // Host supplies combinational instruction data for the current PC.
    assign instrAddr = PCF;
    assign instrF = instrData;

    // PC Adder
    assign PCPlus4F = PCF + 32'd4;

    // Program Counter Register
    // Program Counter Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PCF <= 32'h00000000; // Firmware linker entry at zero
        end else if (~(stallF | boot_stall)) begin
            PCF <= PCNextF;
        end
    end

endmodule
