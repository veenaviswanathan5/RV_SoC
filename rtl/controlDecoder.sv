`timescale 1ns / 1ps

module controlDecoder(
  input  logic [6:0] opcode,
  input  logic       funct7_0,        // M-extension
  output logic       branch,
  output logic [1:0] resultSrc, 
  output logic       memWrite,
  output logic [2:0] aluOp, 
  output logic       aluSrc,
  output logic [2:0] immSrc,    // RESTORED: 3 bits for U-Type
  output logic       regWrite,
  output logic       jump,      
  output logic       jalr
);

  always_comb begin
    // Defaults
    branch    = 0;
    resultSrc = 2'b00;
    memWrite  = 0;
    aluOp     = 3'b000; // FIXED: 3-bit width
    aluSrc    = 0;
    immSrc    = 3'b000;        
    regWrite  = 0;
    jump      = 0;
    jalr      = 0;

    case(opcode)
      7'b0000011 : begin // lw
        resultSrc = 2'b01; 
        aluSrc    = 1;
        regWrite  = 1;
      end
      7'b0100011 : begin // sw
        resultSrc = 2'b00; 
        memWrite  = 1;
        aluSrc    = 1;
        immSrc    = 3'b001;      
      end
      7'b0110011 : begin // R-type and M-type
        resultSrc = 2'b00; 
        aluOp     = (funct7_0) ? 3'b100 : 3'b010; 
        regWrite  = 1;
      end
      7'b1100011 : begin // branches
        branch    = 1;
        resultSrc = 2'b00; 
        aluOp     = 3'b001; // FIXED: 3-bit width
        immSrc    = 3'b010;      
      end
      7'b0010011 : begin // addi (I-Type ALU)
        resultSrc = 2'b00; 
        aluOp     = 3'b011; // FIXED: 3-bit width
        aluSrc    = 1;      
        immSrc    = 3'b000;    
        regWrite  = 1;
      end
      7'b1101111 : begin // jal 
        jump      = 1;
        resultSrc = 2'b10; 
        immSrc    = 3'b011;      
        regWrite  = 1;
      end
      7'b1100111 : begin // jalr 
        jalr      = 1;      
        resultSrc = 2'b10; 
        aluSrc    = 1;      
        immSrc    = 3'b000;      
        regWrite  = 1;
        aluOp     = 3'b000; // FIXED: 3-bit width
      end
      7'b0110111 : begin // lui
        resultSrc = 2'b00;      
        aluSrc    = 1;          
        immSrc    = 3'b100;      
        regWrite  = 1;
        aluOp     = 3'b000; // FIXED: 3-bit width      
      end
      7'b0010111 : begin // auipc
        regWrite  = 1;
        immSrc    = 3'b100; // U-Type Immediate (Same as LUI)
        
        // Assuming your datapath routes the Branch Target Adder (PC + Imm)
        // back to the register file when resultSrc is 2'b11 (3). 
        resultSrc = 2'b11;  
        
        // Safe defaults for ALU since we are bypassing it with resultSrc=3
        aluSrc    = 1;      
        aluOp     = 3'b000; 
      end

      default: begin end
    endcase
  end
endmodule
