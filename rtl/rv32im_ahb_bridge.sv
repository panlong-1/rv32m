// Single-beat AHB-Lite bridge for the core's simple valid/ready bus.
//
// IBUS: req_addr (core PC) can change while a fetch is in flight (branch, jalr,
// flush). When STRICT_ADDR_MATCH=1, req_ready only pulses if req_addr still
// equals addr_q so IF never latches a stale instruction.
//
// DBUS/SBUS: req_addr is the LSU address and is not guaranteed stable against
// ex_mem updates in the same clock phase as ST_DONE; leave STRICT_ADDR_MATCH=0
// so the memory beat can complete.
//
// ST_DONE always returns to IDLE on hready (even when req_ready is suppressed
// by STRICT_ADDR_MATCH) so the master can re-issue; req_ready is combinational
// for the full cycle in ST_DONE with matching conditions.
module rv32im_ahb_bridge #(
  parameter logic STRICT_ADDR_MATCH = 1'b0
) (
  input  logic        hclk,
  input  logic        hresetn,

  input  logic        req_valid,
  output logic        req_ready,
  input  logic [31:0] req_addr,
  input  logic        req_we,
  input  logic [3:0]  req_be,
  input  logic [31:0] req_wdata,
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

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_ADDR,
    ST_DATA,
    ST_DONE
  } state_t;

  state_t state;
  logic [31:0] addr_q;
  logic        we_q;
  logic [2:0]  size_q;
  logic [31:0] wdata_q;
  logic [31:0] rdata_q;

  function automatic logic [2:0] be_to_hsize(input logic [3:0] be);
    begin
      unique case (be)
        4'b0001, 4'b0010, 4'b0100, 4'b1000: be_to_hsize = 3'b000;
        4'b0011, 4'b1100:                   be_to_hsize = 3'b001;
        default:                             be_to_hsize = 3'b010;
      endcase
    end
  endfunction

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      state   <= ST_IDLE;
      addr_q  <= 32'd0;
      we_q    <= 1'b0;
      size_q  <= 3'b010;
      wdata_q <= 32'd0;
      rdata_q <= 32'd0;
    end else begin
      unique case (state)
        ST_IDLE: begin
          if (req_valid) begin
            addr_q  <= req_addr;
            we_q    <= req_we;
            size_q  <= be_to_hsize(req_be);
            wdata_q <= req_wdata;
            state   <= ST_ADDR;
          end
        end
        ST_ADDR: begin
          if (hready)
            state <= ST_DATA;
        end
        ST_DATA: begin
          if (hready) begin
            rdata_q <= hrdata;
            state <= ST_DONE;
          end
        end
        ST_DONE: begin
          if (hready)
            state <= ST_IDLE;
        end
        default: state <= ST_IDLE;
      endcase
    end
  end

  assign haddr  = addr_q;
  assign hwrite = we_q;
  assign hsize  = size_q;
  assign hburst = 3'b000;
  assign hprot  = 4'b0011;
  assign hwdata = wdata_q;
  assign htrans = (state == ST_ADDR) ? HTRANS_NONSEQ : HTRANS_IDLE;

  assign req_ready = (state == ST_DONE) && hready && !hresp &&
      (!STRICT_ADDR_MATCH || (req_addr == addr_q));
  assign req_rdata = rdata_q;
endmodule
