module rv32_stage5_writeback(
    input  logic [1:0]  resultSrcW,
    input  logic [31:0] aluResultW,
    input  logic [31:0] readDataW,
    input  logic [31:0] PCPlus4W,
    input  logic [31:0] PCTargetW,   
    input  logic        regWriteW,
    input  logic [4:0]  rdW,
    output logic [31:0] resultW
);

    always_comb begin
        case(resultSrcW)
            2'b01: resultW = readDataW;  // Data from AXI Memory
            default: resultW = aluResultW; // Correct data for ALU, JAL, and AUIPC
        endcase
    end
endmodule