// Pipelined AHB-Lite instruction fetch (IBUS master).
//
// The address phase of the next fetch overlaps the data phase of the current
// one, so a zero-wait IMEM delivers one instruction per cycle.
//
// req_next_addr is the PC the core will hold in the next cycle (stall ? pc :
// pc_next). It is issued as the address phase now, so its data phase lines up
// with req_addr (the current PC) one cycle later. req_ready only fires when the
// in-flight data phase belongs to req_addr; after a redirect the stale beat is
// dropped and the new PC is already on the bus.
//
// HTRANS is IDLE while HREADY is low: no NONSEQ is presented during a wait
// state, so HADDR may follow the core freely and the extended data phase
// (and the slave's registered address) stay untouched.
module rv32im_ahb_fetch (
  input  logic        hclk,
  input  logic        hresetn,

  output logic        req_ready,
  input  logic [31:0] req_addr,
  input  logic [31:0] req_next_addr,
  output logic [31:0] req_rdata,

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

  logic        dph_valid_q;
  logic [31:0] dph_addr_q;

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      dph_valid_q <= 1'b0;
      dph_addr_q  <= 32'd0;
    end else if (hready) begin
      dph_valid_q <= 1'b1;
      dph_addr_q  <= req_next_addr;
    end
  end

  assign haddr  = req_next_addr;
  assign htrans = hready ? HTRANS_NONSEQ : HTRANS_IDLE;
  assign hwrite = 1'b0;
  assign hsize  = 3'b010;
  assign hburst = 3'b000;
  assign hprot  = 4'b0010; // opcode fetch, privileged
  assign hwdata = 32'd0;

  assign req_ready = dph_valid_q && hready && !hresp && (dph_addr_q == req_addr);
  assign req_rdata = hrdata;
endmodule
