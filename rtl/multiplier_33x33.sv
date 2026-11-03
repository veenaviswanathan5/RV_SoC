`timescale 1ns / 1ps

module multiplier_33x33 #(
    parameter PIPELINE_STAGES = 3
)(
    input  logic        CLK,
    input  logic        CE,    // Clock Enable to stall the pipeline
    input  logic [32:0] A,
    input  logic [32:0] B,
    output logic [65:0] P
);

    logic signed [65:0] mult_result;
    assign mult_result = $signed(A) * $signed(B);

    logic [65:0] pipe_regs [PIPELINE_STAGES-1:0];

    // Removed SCLR entirely. Yosys can now freely retime these registers 
    // backward into the multiplier combinational logic.
    always_ff @(posedge CLK) begin
        if (CE) begin
            pipe_regs[0] <= mult_result;
            for (int i = 1; i < PIPELINE_STAGES; i++) begin
                pipe_regs[i] <= pipe_regs[i-1];
            end
        end
    end

    assign P = (PIPELINE_STAGES > 0) ? pipe_regs[PIPELINE_STAGES-1] : mult_result;

endmodule
