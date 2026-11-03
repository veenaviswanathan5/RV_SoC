module hazardHandler(
  input logic [4:0] rs1E, //new signal, extract from instruction bits in D stage. rs1D
  input logic [4:0] rs2E,
  input logic [4:0] rs1D,
  input logic [4:0] rs2D,
  input logic [4:0] rdM,
  input logic [4:0] rdW,
  input logic [4:0] rdE,
  input logic regWriteM,
  input logic regWriteW,
  input logic resultSrcE0,
  input logic PCSrcE,
  
  //Inputs from Math FSM
  input logic stallF_m,
  input logic stallD_m,
  input logic stallE_m,
  
  //Input from AXI4LiteDataMemory FSM
  input logic stallAXI,
  input logic stall_cache, // NEW: I-Cache stall input
  
  //forward
  output logic [1:0] forwardAE, 
  output logic [1:0] forwardBE,
  
  //flush
  output logic flushE, 
  output logic flushM, // NEW: Added master flushM 
  
  //stall
  output logic stallF,
  output logic stallD,
  output logic stallE, // NEW: Added master stallE
  output logic stallM, // NEW: Added master stallM for Memory stage
  output logic stallW, // NEW: Added master stallW for Writeback stage
  
  //branch
  output logic flushD
);
  
  logic lwStall;
  
  //forward logic
  always_comb begin
    forwardAE = 2'b00;
    forwardBE = 2'b00;

    // MEM stage has priority
    if (regWriteM && (rdM != 5'b0)) begin
      if (rs1E == rdM)
        forwardAE = 2'b10;
      if (rs2E == rdM)
        forwardBE = 2'b10;
    end

    // WB stage
    if (regWriteW && (rdW != 5'b0)) begin
      if ((forwardAE == 2'b00) && (rs1E == rdW))
        forwardAE = 2'b01;
      if ((forwardBE == 2'b00) && (rs2E == rdW))
        forwardBE = 2'b01;
    end
  end
  
  //stall logic
  assign lwStall = (resultSrcE0 && 
                    ((rs1D == rdE) || (rs2D == rdE)) && 
                    (rdE != 5'b0)); //when resultSrcE0 is 1, data is writtenback from dataMem. Also avoid unnecessary (most compilers don't generate this but still) stall when rdE = 0;
                    
  //Centralized Master Stalls for M-Extension, AXI, and I-Cache
  assign stallF = lwStall | stallF_m | stallAXI | stall_cache;
  assign stallD = lwStall | stallD_m | stallAXI | stall_cache;
  assign stallE = stallE_m | stallAXI | stall_cache; // Execute stage freezes purely on math IP calculation or bus stalls
  assign stallM = stallAXI | stall_cache;            // Memory stage freezes during AXI transactions or cache miss
  assign stallW = stallAXI | stall_cache;            // Writeback stage freezes during AXI transactions or cache miss
  
  //branch prediction and flushes
  // FIX: Gate the flushes with ~stallAXI and ~stall_cache to prevent wiping frozen instructions
  assign flushD = (PCSrcE) & ~stallAXI & ~stall_cache; 
  assign flushE = (PCSrcE || lwStall) & ~stallAXI & ~stall_cache; 
  
  // NEW: Master FlushM (Pushes bubbles into memory stage while Execute is frozen)
  // clr has priority over en in pipelineReg. Never clear an older memory
  // instruction while its AXI transaction (or a cache stall) holds the stage.
  assign flushM = stallE_m & ~stallAXI & ~stall_cache;
  
endmodule