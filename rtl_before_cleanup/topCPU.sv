`timescale 1ns / 1ps

module topCPU(
  input  logic        clk,        
  input  logic        rst_n,      
  
  // Instruction Memory Interface (Direct Native Mapping)
  output logic [31:0] instrAddr,
  input  logic [31:0] instrData,
  
  // AXI4-Lite Data Memory Interface 
  // For sw (Write Channel)
  output logic [31:0] axi_awaddr,
  output logic [31:0] axi_wdata,
  output logic [3:0]  axi_wstrb,
  output logic        axi_awvalid,
  output logic        axi_wvalid,
  output logic        axi_bready,
  input  logic        axi_awready,
  input  logic        axi_wready,
  input  logic [1:0]  axi_bresp,
  input  logic        axi_bvalid,
  
  // For lw (Read Channel)
  output logic [31:0] axi_araddr,
  output logic        axi_arvalid,
  output logic        axi_rready,
  input  logic        axi_arready,
  input  logic [31:0] axi_rdata,
  input  logic [1:0]  axi_rresp,
  input  logic        axi_rvalid
);
  
  // =========================================================================
  // Synchronized System Clocks and Resets
  // =========================================================================
  logic sys_clk;
  
  assign sys_clk = clk;

  logic rst_sync_1 = 0, cpu_rst_n = 0;
  always_ff @(posedge sys_clk) begin
    rst_sync_1 <= rst_n;
    cpu_rst_n  <= rst_sync_1;
  end 
  
  // =========================================================================
  // 2. Custom Peripherals
  // =========================================================================
  
  // Directly tied to 1'b0 because I-Cache has been stripped for native memory testing
  logic        cpu_stall;
  assign cpu_stall = 1'b0;

  riscv_core core_inst (
    .clk(sys_clk),
    .rst_n(cpu_rst_n), 
    .cpu_stall(cpu_stall), 
    .instrAddr(instrAddr),
    .instrData(instrData), 
    .axi_awaddr(axi_awaddr),
    .axi_wdata(axi_wdata),
    .axi_wstrb(axi_wstrb),
    .axi_awvalid(axi_awvalid),
    .axi_wvalid(axi_wvalid),
    .axi_bready(axi_bready),
    .axi_awready(axi_awready),
    .axi_wready(axi_wready),
    .axi_bresp(axi_bresp),
    .axi_bvalid(axi_bvalid),
    .axi_araddr(axi_araddr),
    .axi_arvalid(axi_arvalid),
    .axi_rready(axi_rready),
    .axi_arready(axi_arready),
    .axi_rdata(axi_rdata),
    .axi_rresp(axi_rresp),
    .axi_rvalid(axi_rvalid)
    
  );

endmodule