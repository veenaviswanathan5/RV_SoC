module pipelineReg #(
  parameter WIDTH = 32 //Override in top_module as per requirement
)(
  input  logic clk,
  input  logic rst_n,
  input  logic en,
  input  logic clr,
  input  logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);
  
  //sync flop, async reset
  always_ff@(posedge clk or negedge rst_n) begin 
    
    if (!rst_n) begin
      q <= {WIDTH{1'b0}};
    end
    
   
    else if(clr)begin      
      q <= {WIDTH{1'b0}};      
    end
    
    
    else if(en)begin      
      q <= d;
    end
    
  end
endmodule