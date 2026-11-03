`timescale 1ns / 1ps

module fsm_m_extension(
  input  logic clk,
  input  logic rst_n,
  input  logic pipeline_hold, // Older memory transaction or external stall
  input  logic is_mul,
  input  logic is_div,
  output logic ce_mul,
  output logic ce_div,
  input  logic dout_tvalid,
  output logic divisor_tvalid,
  output logic dividend_tvalid,
  output logic stallF,
  output logic stallD,
  output logic stallE,
  output logic math_start // 1. ADD THIS PORT
);
  
  //State definitions
  typedef enum logic [3:0] {
    IDLE       = 4'b0000,
    MUL_1      = 4'b0001,
    MUL_2      = 4'b0010,
    MUL_3      = 4'b0011,
    MUL_4      = 4'b0100,
    MUL_5      = 4'b0101,
    MUL_READY  = 4'b1000,
    DIV_STALL  = 4'b1001,
    DIV_READY  = 4'b1010,
    MUL_START  = 4'b1111
  } state_t;
  
  state_t state, next_state;
  
  
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end
    
  
  
  always_comb begin 
    // Defaults prevent inferred latches.
    ce_mul          = 1'b0;
    ce_div          = 1'b0;
    stallF          = 1'b0;
    stallD          = 1'b0;
    stallE          = 1'b0;
    divisor_tvalid  = 1'b0;
    dividend_tvalid = 1'b0;
    next_state      = state; // Default to staying in current state
    math_start      = 1'b0; // 2. ADD DEFAULT VALUE
    
    case(state)
      
      IDLE: begin
        if (is_mul) begin
          ce_mul = 1'b1;      
          stallF = 1'b1;
          stallD = 1'b1;
          stallE = 1'b1;
          next_state = MUL_1;
          math_start = 1'b1;  // 3. PULSE HIGH FOR MULTIPLIER
        end else if (is_div) begin
          ce_div          = 1'b1;      
          stallF          = 1'b1;
          stallD          = 1'b1;
          stallE          = 1'b1;
          divisor_tvalid  = 1'b1;
          dividend_tvalid = 1'b1;
          next_state      = DIV_STALL;
          math_start = 1'b1;  // 3. PULSE HIGH FOR DIVIDER
        end
      end
      
      MUL_START: begin
        ce_mul = 1'b1;      
        stallF = 1'b1;
        stallD = 1'b1;
        stallE = 1'b1;
        next_state = MUL_1;
      end
      
      MUL_1: begin
        ce_mul = 1'b1;      
        stallF = 1'b1;
        stallD = 1'b1;
        stallE = 1'b1;
        next_state = MUL_2;
      end
      
      MUL_2: begin
        // FIXED: Must keep signals asserted
        ce_mul = 1'b1;      
        stallF = 1'b1;
        stallD = 1'b1;
        stallE = 1'b1;
        next_state = MUL_3;
      end

      MUL_3: begin
        ce_mul = 1'b1;      
        stallF = 1'b1;
        stallD = 1'b1;
        stallE = 1'b1;
        next_state = MUL_4;
      end

      MUL_4: begin
        ce_mul = 1'b1;      
        stallF = 1'b1;
        stallD = 1'b1;
        stallE = 1'b1;
        next_state = MUL_5;
      end

      MUL_5: begin
        ce_mul = 1'b1;      
        stallF = 1'b1;
        stallD = 1'b1;
        stallE = 1'b1;
        next_state = MUL_READY;
      end

      MUL_READY: begin
        // Outputs drop to 0 naturally via defaults. Data is latched this cycle.
        next_state = IDLE;
      end
      
      
      DIV_STALL: begin
        ce_div = 1'b1;
        // Keep Execute frozen through completion. DIV_READY is the single
        // cycle in which this instruction may advance into Memory.
        stallF = 1'b1;
        stallD = 1'b1;
        stallE = 1'b1;
        if (dout_tvalid) next_state = DIV_READY;
      end

      DIV_READY: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase

    // Do not capture operands or consume a completed operation until the
    // rest of the pipeline can advance. Forwarded load data may not be ready.
    if (pipeline_hold) begin
      next_state = state;
      ce_mul = 1'b0;
      ce_div = 1'b0;
      math_start = 1'b0;
      divisor_tvalid = 1'b0;
      dividend_tvalid = 1'b0;
    end
  end
endmodule
