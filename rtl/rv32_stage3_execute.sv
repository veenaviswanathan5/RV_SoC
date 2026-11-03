`timescale 1ns / 1ps
//make sure to add retime flag for yosys to put the pipeline registers in the combinational path instead of after it.
module rv32_stage3_execute (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        pipeline_hold,
    
    // Control & Data Inputs
    input  logic        jumpE, branchE, jalrE, aluSrcAE, aluSrcBE,
    input  logic [3:0]  aluControlE,
    input  logic [31:0] rd1E, rd2E, PCE, immExtE,
    input  logic [2:0]  funct3E,
    input  logic [1:0]  forwardAE, forwardBE,
    input  logic [31:0] resultW, aluResultM,
    
    // M-Extension Inputs
    input  logic        is_mulE, is_mul_upperE, is_divE, is_remE, is_rs1_signedE, is_rs2_signedE,
    
    // Outputs
    output logic [31:0] aluResultE, writeDataE, PCTargetE,
    output logic [1:0]  PCSrcE,
    output logic        stallF_m, stallD_m, stallE_m
);

    logic        zeroE, notEqualE, greaterE, lesserE, greaterUnsignedE, lesserUnsignedE, TakeBranchE;
    logic [31:0] srcAE, srcBE, forwardedAE, forwardedBE;
    logic [31:0] aluOutE, mulOutE, divOutE;
    
    // M-Ext Wires
    logic [32:0] mul_A_33, mul_B_33, mul_A_33_held, mul_B_33_held;
    logic [65:0] mul_P_66;
    logic        ce_mul, ce_div, math_start;
    logic        divisor_tvalid, dout_tvalid, dividend_tvalid;
    logic [39:0] divisor_tdata_40, dividend_tdata_40;
    logic [79:0] dout_tdata_80;


    // 3-Way Forwarding Multiplexers
    always_comb begin
        case(forwardAE)
            2'b00: forwardedAE = rd1E;
            2'b01: forwardedAE = resultW;
            2'b10: forwardedAE = aluResultM;
            default: forwardedAE = rd1E;
        endcase
    end
    
    always_comb begin
        case(forwardBE)
            2'b00: forwardedBE = rd2E;
            2'b01: forwardedBE = resultW;
            2'b10: forwardedBE = aluResultM;
            default: forwardedBE = rd2E;
        endcase
    end

    // Branch Evaluation
    always_comb begin
        case(funct3E)
            3'b000: TakeBranchE = zeroE;
            3'b001: TakeBranchE = notEqualE;
            3'b100: TakeBranchE = lesserE;
            3'b101: TakeBranchE = greaterE;
            3'b110: TakeBranchE = lesserUnsignedE;
            3'b111: TakeBranchE = greaterUnsignedE;
            default: TakeBranchE = 1'b0;
        endcase
    end

    always_comb begin
        if (jalrE) PCSrcE = 2'b10;
        else if ((branchE & TakeBranchE) | jumpE) PCSrcE = 2'b01;
        else PCSrcE = 2'b00;
    end

    // M-Extension Handling
    assign mul_A_33 = is_rs1_signedE ? {srcAE[31], srcAE} : {1'b0, srcAE};
    assign mul_B_33 = is_rs2_signedE ? {srcBE[31], srcBE} : {1'b0, srcBE};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_A_33_held <= 33'b0;
            mul_B_33_held <= 33'b0;
        end else if (math_start) begin 
            mul_A_33_held <= mul_A_33; 
            mul_B_33_held <= mul_B_33;
        end
    end

    assign mulOutE = is_mul_upperE ? mul_P_66[63:32] : mul_P_66[31:0];
    assign divOutE = is_remE ? dout_tdata_80[31:0] : dout_tdata_80[71:40];
    assign aluResultE = is_mulE ? mulOutE : is_divE ? divOutE : aluOutE;

    assign srcAE = aluSrcAE ? PCE : forwardedAE; 
    assign srcBE = aluSrcBE ? immExtE : forwardedBE; 
    assign writeDataE = forwardedBE;
    assign PCTargetE = PCE + immExtE;                              

    ALU aluInstance(
        .srcA(srcAE), .srcB(srcBE), .ALUControl(aluControlE), .ALUResult(aluOutE),
        .zero(zeroE), .notEqual(notEqualE), .greater(greaterE), .lesser(lesserE),
        .greaterUnsigned(greaterUnsignedE), .lesserUnsigned(lesserUnsignedE)
    );

    fsm_m_extension fsmInstance (
        .clk(clk), .rst_n(rst_n), .pipeline_hold(pipeline_hold), .is_mul(is_mulE), .is_div(is_divE),
        .ce_mul(ce_mul), .ce_div(ce_div), .dout_tvalid(dout_tvalid),
        .divisor_tvalid(divisor_tvalid), .dividend_tvalid(dividend_tvalid),
        .stallF(stallF_m), .stallD(stallD_m), .stallE(stallE_m), .math_start(math_start)
    );
   
   
    // Set PIPELINE_STAGES to match whatever latency FSM was originally expecting.
    multiplier_33x33 #(
        .PIPELINE_STAGES(5)
    ) your_multiplier_instance (
        .CLK(clk), 
        .CE(ce_mul), 
        .A(mul_A_33_held), 
        .B(mul_B_33_held), 
        .P(mul_P_66)    
    );
    
    assign dividend_tdata_40 = {7'b0000000, mul_A_33};
    assign divisor_tdata_40  = {7'b0000000, mul_B_33};
    
    // Reset aborts an in-flight division together with the pipeline.
    divider_33x33 your_divider_instance (
        .aclk(clk), .aresetn(rst_n),
        .aclken(ce_div),                                 
        
        .s_axis_divisor_tvalid(divisor_tvalid),          
        .s_axis_divisor_tdata(divisor_tdata_40),         
        
        .s_axis_dividend_tvalid(dividend_tvalid),        
        .s_axis_dividend_tdata(dividend_tdata_40),       
        
        .m_axis_dout_tvalid(dout_tvalid),                
        .m_axis_dout_tdata(dout_tdata_80)                
    );

    // RV32 selects only the architectural 32-bit result. Other bits belong
    // to sign extension or the divider's padded stream interface.
    logic unused_math_bits;
    assign unused_math_bits = ^{mul_P_66[65:64],
                               dout_tdata_80[79:72], dout_tdata_80[39:32]};
endmodule
