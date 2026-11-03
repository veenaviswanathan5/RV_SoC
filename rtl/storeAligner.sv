`timescale 1ns / 1ps

module storeAligner(
  input  logic [1:0]  aluResultM_2bit,
  input  logic [31:0] writeDataM,
  input  logic [2:0]  funct3M,
  
  output logic [31:0] writeDataM_formatted,
  output logic [3:0]  axi_wstrb
);

  always_comb begin
    // Default assignment to prevent inferred hardware latches
    // If it's not a store instruction, put 0 on the bus and disable write strobes.
    writeDataM_formatted = 32'b0;
    axi_wstrb            = 4'b0000;

    case(funct3M)
      
      // Store Byte (SB)
      3'b000 : begin 
        case(aluResultM_2bit)
          2'b00 : begin
            writeDataM_formatted = writeDataM;
            axi_wstrb = 4'b0001;
          end
          2'b01 : begin
            writeDataM_formatted = writeDataM << 8;
            axi_wstrb = 4'b0010;
          end
          2'b10 : begin
            writeDataM_formatted = writeDataM << 16;
            axi_wstrb = 4'b0100;
          end
          2'b11 : begin
            writeDataM_formatted = writeDataM << 24;
            axi_wstrb = 4'b1000;
          end
        endcase
      end
      
      // Store Half-Word (SH)
      3'b001 : begin
        case(aluResultM_2bit)
          2'b00 : begin
            writeDataM_formatted = writeDataM; 
            axi_wstrb = 4'b0011;
          end
          2'b10 : begin
            writeDataM_formatted = writeDataM << 16;
            axi_wstrb = 4'b1100;
          end
          default : begin
            // If the C code tries to misalign a half-word (e.g., offset 01), 
            writeDataM_formatted = 32'b0;
            axi_wstrb = 4'b0000; 
          end
        endcase
      end
      
      // Store Word (SW)
      3'b010 : begin
        writeDataM_formatted = writeDataM;
        axi_wstrb = 4'b1111; 
      end

      // If funct3M is anything else, the top-level default applies.
      default: begin
        writeDataM_formatted = 32'b0;
        axi_wstrb = 4'b0000;
      end
      
    endcase
  end
endmodule
