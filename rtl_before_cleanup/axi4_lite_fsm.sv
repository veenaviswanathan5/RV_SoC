`timescale 1ns / 1ps

module axi4_lite_fsm(
  input logic         clk,
  input logic         rst_n,

  // CPU Pipeline Data
  input logic [1:0]   resultSrcM,
  input logic         memWriteM,
  input logic [31:0]  aluResultM,   // The target address calculated by the ALU
  input logic [31:0]  writeDataM,   // The data the CPU wants to store
  input logic [3:0]   axi_wstrb_M,  // NEW: Aligned write strobe from storeAligner
  
  // Inputs: Controller to CPU
  // For sw (Write Channel)
  input logic         axi_awready,
  input logic         axi_wready,
  input logic [1:0]   axi_bresp,
  input logic         axi_bvalid,
  
  // For lw (Read Channel)
  input logic         axi_arready,
  input logic [31:0]  axi_rdata,
  input logic [1:0]   axi_rresp,
  input logic         axi_rvalid,
  
  // Outputs: CPU to Controller
  // For sw (Write Channel)
  output logic [31:0] axi_awaddr,
  output logic [31:0] axi_wdata,
  output logic [3:0]  axi_wstrb,
  output logic        axi_awvalid,
  output logic        axi_wvalid,
  output logic        axi_bready,
  
  // For lw (Read Channel)
  output logic [31:0] axi_araddr,
  output logic        axi_arvalid,
  output logic        axi_rready,
  
  // Outputs: FSM to CPU Internal Wires
  output logic [31:0] axi_readDataM,
  output logic        stall_AXI
);
  
  // Holding registers
  logic [31:0] axi_addr_reg;
  logic [31:0] axi_writeData_reg;
  logic [31:0] axi_readData_reg; 
  logic [3:0]  axi_wstrb_reg;       // NEW: Holding register for the write strobe
  
  // THE FIX: Independent tracking flags for decoupled AW and W handshakes
  logic aw_done;
  logic w_done;

  // NEW FIX: A 1-cycle recovery flag to satisfy AXI reset protocol
  logic reset_recovery;
    
  // FSM State Encoding
  // THE FIX: Replaced STORE_AW and STORE_W with a unified STORE state
  typedef enum logic [2:0] {
    IDLE    = 3'b000,
    LOAD_1  = 3'b001,  // arvalid
    LOAD_2  = 3'b010,  // rready
    LOAD_3  = 3'b011,  // Airlock state for stable handoff
    STORE   = 3'b100,  // Unified Address & Data Phase (awvalid & wvalid)
    STORE_B = 3'b101   // Response Phase (bready)
  } state_t;

  state_t state, next_state;
  
  // FSM register and Holding Registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= IDLE;
      axi_addr_reg      <= 32'b0;
      axi_writeData_reg <= 32'b0;
      axi_readData_reg  <= 32'b0;
      axi_wstrb_reg     <= 4'b0000;
      aw_done           <= 1'b0;
      w_done            <= 1'b0;
      reset_recovery    <= 1'b0;
    end else begin
      state <= next_state;
      reset_recovery <= 1'b1; // Activates on the first clock cycle after reset
      
      // Capture Address, Write Data, and Strobe exactly when the instruction arrives
      if (state == IDLE) begin
        axi_addr_reg      <= aluResultM;
        axi_writeData_reg <= writeDataM;
        axi_wstrb_reg     <= axi_wstrb_M; 
      end

      // THE FIX: Reset flags when entering STORE, latch them when channels handshake
      if (next_state == STORE && state != STORE) begin
        aw_done <= 1'b0;
        w_done  <= 1'b0;
      end else if (state == STORE) begin
        if (axi_awvalid && axi_awready) aw_done <= 1'b1;
        if (axi_wvalid && axi_wready)   w_done  <= 1'b1;
      end
      
      // Capture the volatile Read Data exactly when AXI says it is valid
      if (state == LOAD_2 && axi_rvalid && axi_rresp == 2'b00) begin
        axi_readData_reg <= axi_rdata; 
      end
    end
  end
  
  // FSM next state and output logic 
  always_comb begin
    // 1. Default State Transition
    next_state = state;

    // 2. Default AXI Control Signals (All VALID/READY handshakes inactive)
    axi_awvalid = 1'b0;
    axi_wvalid  = 1'b0;
    axi_bready  = 1'b0;
    axi_arvalid = 1'b0;
    axi_rready  = 1'b0;
    axi_wstrb   = 4'b0000;

    // 3. Default AXI Data/Addr Buses
    axi_awaddr  = axi_addr_reg;
    axi_araddr  = axi_addr_reg;
    axi_wdata   = axi_writeData_reg;
    
    // 4. Default CPU Internal Signals
    stall_AXI = (state != IDLE) || (memWriteM || (resultSrcM == 2'b01));
    axi_readDataM = axi_readData_reg; 
    
    case(state)
        IDLE: begin
          // NEW FIX: Only process CPU requests AFTER the 1-cycle reset recovery
          if (reset_recovery) begin
            if (memWriteM) begin
              next_state = STORE; // THE FIX: Go straight to Unified STORE
            end else if (resultSrcM == 2'b01) begin
              next_state = LOAD_1;
            end
          end
        end
        
        // --- THE FIX: UNIFIED DECOUPLED WRITE SEQUENCE ---
        STORE: begin
          stall_AXI   = 1'b1;          
          axi_awaddr  = axi_addr_reg;
          axi_wdata   = axi_writeData_reg;
          axi_wstrb   = axi_wstrb_reg; 
          
          // Assert valid ONLY if that specific channel hasn't finished yet
          axi_awvalid = !aw_done;
          axi_wvalid  = !w_done;
          
          // Transition ONLY when both channels are completed
          // (Either previously finished, or finishing on this exact clock cycle)
          if ((aw_done || axi_awready) && (w_done || axi_wready)) begin
            next_state = STORE_B;
          end
        end
        
        STORE_B: begin
          stall_AXI  = 1'b1;            
          axi_bready = 1'b1;             // "I am ready for the write receipt"
          
          if (axi_bvalid) begin
            // THE SAFETY PATCH: Drop the data and survive, even if Vivado throws an error
            stall_AXI  = 1'b0;         
            next_state = IDLE;        
          end
        end
        // --------------------------------
        
        LOAD_1: begin 
         stall_AXI   = 1'b1;          
         axi_araddr  = axi_addr_reg;  
         axi_arvalid = 1'b1;          
         
         if (axi_arready) begin     
           next_state  = LOAD_2;
         end
       end
      
       LOAD_2: begin
         stall_AXI  = 1'b1;
         axi_rready = 1'b1;
    
         if (axi_rvalid) begin
           if (axi_rresp == 2'b00) begin
             next_state = LOAD_3; 
           end else begin
             next_state = LOAD_1; 
           end
         end
       end
       
       LOAD_3: begin
         stall_AXI = 1'b0;
         next_state = IDLE;
       end
       
    endcase
  end
endmodule