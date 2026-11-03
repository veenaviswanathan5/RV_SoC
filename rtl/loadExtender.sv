`timescale 1ns / 1ps

module loadExtender(
  input logic [2:0]  funct3M,
  input logic [31:0] readDataM,
  input logic [1:0]  aluResultM_2bit,
  
  output logic [31:0] readDataM_formatted // Added 'logic' for procedural assignment
);

  always_comb begin
    readDataM_formatted = 32'b0;
    
    case(funct3M) 
      
      // lb : load byte signed
      3'b000 : begin
        case(aluResultM_2bit)
          2'b00 : readDataM_formatted = {{24{readDataM[7]}}, readDataM[7:0]};
          2'b01 : readDataM_formatted = {{24{readDataM[15]}}, readDataM[15:8]};
          2'b10 : readDataM_formatted = {{24{readDataM[23]}}, readDataM[23:16]};
          2'b11 : readDataM_formatted = {{24{readDataM[31]}}, readDataM[31:24]};
        endcase
      end
      
      // lh : load half word signed
      3'b001 : begin
        case(aluResultM_2bit)
          2'b00 : readDataM_formatted = {{16{readDataM[15]}}, readDataM[15:0]};
          2'b10 : readDataM_formatted = {{16{readDataM[31]}}, readDataM[31:16]};
          default : readDataM_formatted = 32'b0;
        endcase
      end
      
      // lw : load word
      3'b010 : begin
        readDataM_formatted = readDataM;
      end
      
      // lbu : load byte unsigned
      3'b100 : begin
        case(aluResultM_2bit)
          2'b00 : readDataM_formatted = {{24{1'b0}}, readDataM[7:0]};
          2'b01 : readDataM_formatted = {{24{1'b0}}, readDataM[15:8]};
          2'b10 : readDataM_formatted = {{24{1'b0}}, readDataM[23:16]};
          2'b11 : readDataM_formatted = {{24{1'b0}}, readDataM[31:24]};
        endcase
      end
      
      // lhu : load half word unsigned
      3'b101 : begin
        case(aluResultM_2bit)
          2'b00 : readDataM_formatted = {{16{1'b0}}, readDataM[15:0]};
          2'b10 : readDataM_formatted = {{16{1'b0}}, readDataM[31:16]};
          default : readDataM_formatted = 32'b0;
        endcase
      end
      
      // default
      default : begin
        readDataM_formatted = 32'b0;
      end
    endcase
  end
endmodule
