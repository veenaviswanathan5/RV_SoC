`timescale 1ns / 1ps

module divider_33x33 (
    input  logic        aclk,
    input  logic        aresetn,
    input  logic        aclken,
    
    // Divisor (Denominator)
    input  logic        s_axis_divisor_tvalid,
    input  logic [39:0] s_axis_divisor_tdata,
    
    // Dividend (Numerator)
    input  logic        s_axis_dividend_tvalid,
    input  logic [39:0] s_axis_dividend_tdata,
    
    // Output
    output logic        m_axis_dout_tvalid,
    output logic [79:0] m_axis_dout_tdata
);

    // Iterative Restoring Divider Registers
    logic [32:0] Q; // Quotient
    logic [33:0] R; // Remainder
    logic [32:0] D; // Denominator
    logic [5:0]  count;
    
    logic        busy;
    logic        done_pulse;

    // -------------------------------------------------------------------
    // RISC-V SIGN HANDLING
    // -------------------------------------------------------------------
    logic sign_q, sign_r;
    logic is_div_by_zero;

    // Combinational Absolute Value Conversion
    // RV32IM sign-extends to the 33rd bit (bit 32) for signed operations.
    logic [32:0] abs_dividend;
    logic [32:0] abs_divisor;
    
    assign abs_dividend = s_axis_dividend_tdata[32] ? (~s_axis_dividend_tdata[32:0] + 1'b1) : s_axis_dividend_tdata[32:0];
    assign abs_divisor  = s_axis_divisor_tdata[32]  ? (~s_axis_divisor_tdata[32:0]  + 1'b1) : s_axis_divisor_tdata[32:0];

    // Combinational lookahead for the subtraction step
    logic [33:0] next_R;
    assign next_R = {R[32:0], Q[32]} - {1'b0, D};

    // Final Sign Re-application
    logic [32:0] final_Q;
    logic [32:0] final_R;
    
    // RISC-V Spec: x / 0 = -1 (all 1s). Otherwise, apply calculated sign.
    assign final_Q = is_div_by_zero ? 33'h1FFFFFFFF : (sign_q ? (~Q + 1'b1) : Q);
    
    // RISC-V Spec: x % 0 = x. The Restoring Divider naturally leaves the absolute dividend in R.
    assign final_R = sign_r ? (~R[32:0] + 1'b1) : R[32:0];

    // Quotient occupies bits 72:40; remainder occupies bits 32:0.
    assign m_axis_dout_tdata = {7'b0, final_Q, 7'b0, final_R};
    assign m_axis_dout_tvalid = done_pulse;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            Q <= '0;
            R <= '0;
            D <= '0;
            count <= '0;
            busy <= 1'b0;
            done_pulse <= 1'b0;
            sign_q <= 1'b0;
            sign_r <= 1'b0;
            is_div_by_zero <= 1'b0;
        end else if (aclken) begin
            if (!busy) begin
                done_pulse <= 1'b0;
                if (s_axis_divisor_tvalid && s_axis_dividend_tvalid) begin
                    Q     <= abs_dividend;
                    D     <= abs_divisor;
                    R     <= 34'b0;
                    count <= 6'd33;
                    busy  <= 1'b1;
                    
                    // Latch the signs and edge cases
                    sign_q <= s_axis_dividend_tdata[32] ^ s_axis_divisor_tdata[32];
                    sign_r <= s_axis_dividend_tdata[32];
                    is_div_by_zero <= (s_axis_divisor_tdata[32:0] == 0);
                end
            end else begin
                if (count > 0) begin
                    if (next_R[33]) begin 
                        // Subtraction underflowed: Restore R
                        R <= {R[32:0], Q[32]};
                        Q <= {Q[31:0], 1'b0};
                    end else begin
                        // Subtraction succeeded: Keep new R
                        R <= next_R;
                        Q <= {Q[31:0], 1'b1};
                    end
                    count <= count - 1'b1;
                end else begin
                    busy       <= 1'b0;
                    done_pulse <= 1'b1;
                end
            end
        end
    end
endmodule