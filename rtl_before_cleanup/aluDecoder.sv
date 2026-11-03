module aluDecoder(
  input  logic [2:0] aluOp,       // from main control
  input  logic [2:0] funct3,      // instr[14:12]
  input  logic       funct7_5,    // instr[30]
  input  logic       funct7_0,    // instr[25]
  output logic [3:0] ALUControl,  // EXPANDED to 4 bits
  
  // M-Extension Control Signals
  output logic is_mul,
  output logic is_mul_upper,      // 0 = lower 32 bits, 1 = upper 32 bits
  output logic is_div,            // triggers the divider FSM
  output logic is_rem,            // 0 = quotient, 1 = remainder
  output logic is_rs1_signed,
  output logic is_rs2_signed
);

  always_comb begin
    // Defaults to prevent inferred latches
    ALUControl    = 4'b0000;
    is_mul        = 0;
    is_mul_upper  = 0;
    is_div        = 0;
    is_rem        = 0;
    is_rs1_signed = 0;
    is_rs2_signed = 0;

    case (aluOp)
      // 000: lw/sw/lui/auipc/jal/jalr -> ADD
      3'b000: ALUControl = 4'b0000;

      // 001: branches -> SUB 
      3'b001: ALUControl = 4'b1000;

      // 010: R-type
      3'b010: begin
        case (funct3)
          3'b000: ALUControl = (funct7_5) ? 4'b1000 : 4'b0000; // SUB / ADD (fixed syntax error here)
          3'b001: ALUControl = 4'b0001; // SLL
          3'b010: ALUControl = 4'b0010; // SLT
          3'b011: ALUControl = 4'b0011; // SLTU
          3'b100: ALUControl = 4'b0100; // XOR
          3'b101: ALUControl = (funct7_5) ? 4'b1101 : 4'b0101; // SRA / SRL
          3'b110: ALUControl = 4'b0110; // OR
          3'b111: ALUControl = 4'b0111; // AND
          default: ALUControl = 4'b0000;
        endcase
      end

      // 011: I-Type ALU (Immediate)
      3'b011: begin
        case (funct3)
          3'b000: ALUControl = 4'b0000; // ADDI 
          3'b001: ALUControl = 4'b0001; // SLLI 
          3'b010: ALUControl = 4'b0010; // SLTI
          3'b011: ALUControl = 4'b0011; // SLTIU
          3'b100: ALUControl = 4'b0100; // XORI
          3'b101: ALUControl = (funct7_5) ? 4'b1101 : 4'b0101; // SRAI / SRLI
          3'b110: ALUControl = 4'b0110; // ORI
          3'b111: ALUControl = 4'b0111; // ANDI
          default: ALUControl = 4'b0000;
        endcase
      end

      // 100: M-Type (Multiply/Divide Extension)
      3'b100: begin
        ALUControl = 4'b0000; // Standard ALU doesn't matter, force it to ADD to save power
        case (funct3)
          3'b000: begin // mul
            is_mul        = 1;
            is_mul_upper  = 0;
            is_rs1_signed = 1;
            is_rs2_signed = 1;
          end
          3'b001: begin // mulh
            is_mul        = 1;
            is_mul_upper  = 1;
            is_rs1_signed = 1;
            is_rs2_signed = 1;
          end
          3'b010: begin // mulhsu
            is_mul        = 1;
            is_mul_upper  = 1;
            is_rs1_signed = 1;
            is_rs2_signed = 0; // rs1 signed, rs2 unsigned
          end
          3'b011: begin // mulhu
            is_mul        = 1;
            is_mul_upper  = 1;
            is_rs1_signed = 0;
            is_rs2_signed = 0;
          end
          3'b100: begin // div
            is_div        = 1;
            is_rem        = 0;
            is_rs1_signed = 1;
            is_rs2_signed = 1;
          end
          3'b101: begin // divu
            is_div        = 1;
            is_rem        = 0;
            is_rs1_signed = 0;
            is_rs2_signed = 0;
          end
          3'b110: begin // rem
            is_div        = 1;
            is_rem        = 1;
            is_rs1_signed = 1;
            is_rs2_signed = 1;
          end
          3'b111: begin // remu
            is_div        = 1;
            is_rem        = 1;
            is_rs1_signed = 0;
            is_rs2_signed = 0;
          end
        endcase
      end

      default: ALUControl = 4'b0000;
    endcase
  end
endmodule