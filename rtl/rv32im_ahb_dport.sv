// Pipelined AHB-Lite data port (DBUS / SBUS master).
//
// The core presents the address phase from EX (req_*) and drives the data
// phase from MEM (dph_wdata), so a zero-wait slave completes a load/store in
// the MEM stage without stalling, and back-to-back accesses overlap.
//
// A request is accepted on the clock edge where HREADY is high; the core only
// presents it when the instruction will leave EX on that same edge, so every
// load/store is issued exactly once (no replay of peripheral side effects).
// While HREADY is low the core freezes, keeping the address phase stable.
module rv32im_ahb_dport (
  input  logic        hclk,
  input  logic        hresetn,

  // Address phase (EX stage)
  input  logic        req_valid,
  input  logic [31:0] req_addr,
  input  logic        req_we,
  input  logic [3:0]  req_be,
  // Data phase (MEM stage)
  input  logic [31:0] dph_wdata,
  output logic        dph_active,
  output logic [31:0] dph_rdata,
  output logic        bus_ready,

  output logic [31:0] haddr,
  output logic [1:0]  htrans,
  output logic        hwrite,
  output logic [2:0]  hsize,
  output logic [2:0]  hburst,
  output logic [3:0]  hprot,
  output logic [31:0] hwdata,
  input  logic [31:0] hrdata,
  input  logic        hready,
  input  logic        hresp
);
  localparam logic [1:0] HTRANS_IDLE   = 2'b00;
  localparam logic [1:0] HTRANS_NONSEQ = 2'b10;

  function automatic logic [2:0] be_to_hsize(input logic [3:0] be);
    begin
      unique case (be)
        4'b0001, 4'b0010, 4'b0100, 4'b1000: be_to_hsize = 3'b000;
        4'b0011, 4'b1100:                   be_to_hsize = 3'b001;
        default:                             be_to_hsize = 3'b010;
      endcase
    end
  endfunction

  logic dph_q;

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn)
      dph_q <= 1'b0;
    else if (hready)
      dph_q <= req_valid;
  end

  assign haddr  = req_addr;
  assign htrans = req_valid ? HTRANS_NONSEQ : HTRANS_IDLE;
  assign hwrite = req_we;
  assign hsize  = be_to_hsize(req_be);
  assign hburst = 3'b000;
  assign hprot  = 4'b0011; // data access, privileged
  assign hwdata = dph_wdata;

  assign dph_active = dph_q;
  assign dph_rdata  = hrdata;
  // HRESP is not modelled (all TORV slaves answer OKAY).
  assign bus_ready  = hready;
endmodule
