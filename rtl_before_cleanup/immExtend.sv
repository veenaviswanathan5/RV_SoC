module immExtend(
  // Input: Bits 31 down to 7 of the instruction
  input  logic [31:7] instr, 
  input  logic [2:0]  immSrc,  // EXPANDED to 3 bits
  output logic [31:0] immExt
);

  always_comb begin
    case(immSrc)
      // I-Type: {{20{Sign}}, Inst[31:20]}
      3'b000 : immExt = { {20{instr[31]}}, instr[31:20] }; 

      // S-Type: {{20{Sign}}, Inst[31:25], Inst[11:7]}
      3'b001 : immExt = { {20{instr[31]}}, instr[31:25], instr[11:7] }; 

      // B-Type: {{20{Sign}}, Inst[7], Inst[30:25], Inst[11:8], 0}
      3'b010 : immExt = { {20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0 }; 
      
      // J-Type (JAL): {{12{Sign}}, Inst[19:12], Inst[20], Inst[30:21], 0}
      3'b011 : immExt = { {12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0 };
      
      // U-Type (LUI, AUIPC) - NEW: {Inst[31:12], 12'b0}
      3'b100 : immExt = { instr[31:12], 12'b0 };

      default : immExt = '0; 
    endcase
  end

endmodule