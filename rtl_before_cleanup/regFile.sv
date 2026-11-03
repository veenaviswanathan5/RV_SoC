module regFile #(
    parameter WIDTH = 32
)(
    input  logic             clk, 
    input  logic             we,
    input  logic [4:0]       a1, a2, a3,
    input  logic [WIDTH-1:0] wd3,
    output logic [WIDTH-1:0] rd1, rd2
);

    logic [WIDTH-1:0] rf [31:0];

    // =========================================================================
    // NEW: FPGA Initialization Block
    // Clears the metastatic 'X' states in simulation and forces Vivado 
    // to initialize the distributed RAM to zero in the bitstream.
    // =========================================================================
    initial begin
        for (int i = 0; i < 32; i++) begin
            rf[i] = {WIDTH{1'b0}};
        end
    end

    // Synchronous write on positive edge
    always_ff @(posedge clk) begin
        if (we && a3 != 5'b0) begin
            rf[a3] <= wd3;
        end
    end
    
    // Asynchronous read with internal bypass (write-through)
    assign rd1 = (a1 == 5'b0) ? {WIDTH{1'b0}} : ((we && a3 != 5'b0 && a1 == a3) ? wd3 : rf[a1]);
    assign rd2 = (a2 == 5'b0) ? {WIDTH{1'b0}} : ((we && a3 != 5'b0 && a2 == a3) ? wd3 : rf[a2]);

endmodule