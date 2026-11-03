`timescale 1ns / 1ps

module ALU #(
    parameter WIDTH = 32
)(
    input  logic [WIDTH-1:0] srcA, srcB,
    output logic [WIDTH-1:0] ALUResult,
    input  logic [3:0]       ALUControl,
    output logic             zero,
    output logic             notEqual,
    output logic             greater,         // Signed Greater or Equal (BGE)
    output logic             lesser,          // Signed Less Than (BLT)
    output logic             greaterUnsigned, // NEW: Unsigned Greater or Equal (BGEU)
    output logic             lesserUnsigned   // NEW: Unsigned Less Than (BLTU)
);

    always_comb begin
        case (ALUControl)
          4'b0000: ALUResult = srcA + srcB;  // ADD
          
          4'b1000: ALUResult = srcA - srcB;  // SUB
          
          4'b0111: ALUResult = srcA & srcB;  // AND
          
          4'b0110: ALUResult = srcA | srcB;  // OR
          
          4'b0100: ALUResult = srcA ^ srcB;  // XOR
          
          4'b0010: ALUResult = {{(WIDTH-1){1'b0}}, ($signed(srcA) < $signed(srcB))}; // SLT
   
          4'b0011: ALUResult = {{(WIDTH-1){1'b0}}, (srcA < srcB)}; // SLTU
        
          4'b0001: ALUResult = srcA << srcB[4:0]; // SLL
          
          4'b0101: ALUResult = srcA >> srcB[4:0]; // SRL
          
          4'b1101: ALUResult = $signed(srcA) >>> srcB[4:0]; // SRA
          
          default: ALUResult = '0;
        endcase
    end
      
  assign zero = (ALUResult == '0);
  assign notEqual = ~zero; 
  
  // Signed Comparisons
  assign lesser = ($signed(srcA) < $signed(srcB)); 
  assign greater = ($signed(srcA) >= $signed(srcB)); 
  
  // NEW: Unsigned Comparisons
  assign lesserUnsigned  = (srcA < srcB);
  assign greaterUnsigned = (srcA >= srcB);

endmodule
