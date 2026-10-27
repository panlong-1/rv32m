// TORV — AHB-Lite slave wrapper around an IHP SG13G2 single-port SRAM macro
// (RM_IHPSG13_1P_<WORDS>x32_c2_bm_bist).
//
// Zero wait states:
// - Read: the accepted address phase drives the macro address directly, so
//   A_DOUT is valid in the data phase.
// - Write: HWDATA only exists in the data phase. If the port is free that
//   cycle (no read address phase), the write goes straight to the macro;
//   otherwise it is parked in a one-entry write buffer and drained on the next
//   free cycle. Every write address phase leaves the port free, so the buffer
//   is always empty again before the next write needs it.
// - A read that hits the buffer, or the write completing in the same cycle,
//   gets those bytes merged into its data (store then load is coherent).
//
// Word-indexed by haddr[AW+1:2]; higher address bits alias (legacy TORV tests).
module torv_ahb_sram #(
  parameter int WORDS = 1024 // 256, 512 or 1024 (one macro)
) (
  input  logic        hclk,
  input  logic        hresetn,
  input  logic        hsel,
  input  logic [31:0] haddr,
  input  logic [1:0]  htrans,
  input  logic        hwrite,
  input  logic [2:0]  hsize,
  input  logic [31:0] hwdata,
  input  logic        hready_in,
  output logic [31:0] hrdata,
  output logic        hready,
  output logic        hresp
);
  localparam int AW = $clog2(WORDS);

  assign hready = 1'b1;
  assign hresp  = 1'b0;

  function automatic logic [31:0] lane_mask(input logic [2:0] size, input logic [1:0] off);
    unique case (size)
      3'b000:  lane_mask = 32'h0000_00FF << (8 * off);
      3'b001:  lane_mask = off[1] ? 32'hFFFF_0000 : 32'h0000_FFFF;
      default: lane_mask = 32'hFFFF_FFFF;
    endcase
  endfunction

  logic          accept;
  logic          rd_now;
  logic [AW-1:0] a_word;
  assign accept = hsel && hready_in && htrans[1];
  assign rd_now = accept && !hwrite;
  assign a_word = haddr[AW+1:2];

  // Write data phase (address/mask registered from its address phase)
  logic          wr_dph_q;
  logic [AW-1:0] wr_addr_q;
  logic [31:0]   wr_mask_q;
  // One-entry write buffer
  logic          wb_valid_q;
  logic [AW-1:0] wb_addr_q;
  logic [31:0]   wb_data_q;
  logic [31:0]   wb_mask_q;
  // Read data phase merge (bytes newer than the macro contents)
  logic [31:0]   rd_mask_q;
  logic [31:0]   rd_data_q;

  logic wr_data_now;
  logic direct_wr;
  logic drain;
  assign wr_data_now = wr_dph_q && hready_in;
  assign direct_wr   = wr_data_now && !rd_now;
  assign drain       = wb_valid_q && !rd_now && !direct_wr;

  logic [31:0] buf_hit_mask;
  logic [31:0] inc_hit_mask;
  assign buf_hit_mask = (wb_valid_q && (wb_addr_q == a_word)) ? wb_mask_q : 32'd0;
  assign inc_hit_mask = (wr_data_now && (wr_addr_q == a_word)) ? wr_mask_q : 32'd0;

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      wr_dph_q   <= 1'b0;
      wr_addr_q  <= '0;
      wr_mask_q  <= 32'd0;
      wb_valid_q <= 1'b0;
      wb_addr_q  <= '0;
      wb_data_q  <= 32'd0;
      wb_mask_q  <= 32'd0;
      rd_mask_q  <= 32'd0;
      rd_data_q  <= 32'd0;
    end else begin
      if (hready_in) begin
        wr_dph_q <= accept && hwrite;
        if (accept && hwrite) begin
          wr_addr_q <= a_word;
          wr_mask_q <= lane_mask(hsize, haddr[1:0]);
        end
      end

      if (wr_data_now && rd_now) begin
        wb_valid_q <= 1'b1;
        wb_addr_q  <= wr_addr_q;
        wb_data_q  <= hwdata;
        wb_mask_q  <= wr_mask_q;
      end else if (drain) begin
        wb_valid_q <= 1'b0;
      end

      if (rd_now) begin
        rd_mask_q <= buf_hit_mask | inc_hit_mask;
        rd_data_q <= (hwdata & inc_hit_mask) | (wb_data_q & ~inc_hit_mask);
      end
    end
  end

`ifndef SYNTHESIS
  always @(posedge hclk) begin
    if (hresetn && wr_data_now && rd_now && wb_valid_q)
      $error("torv_ahb_sram: write buffer overrun");
  end
`endif

  logic          m_men;
  logic          m_wen;
  logic          m_ren;
  logic [AW-1:0] m_addr;
  logic [31:0]   m_din;
  logic [31:0]   m_bm;
  logic [31:0]   m_dout;

  assign m_ren  = rd_now;
  assign m_wen  = direct_wr || drain;
  assign m_men  = m_ren || m_wen;
  assign m_addr = rd_now ? a_word : (direct_wr ? wr_addr_q : wb_addr_q);
  assign m_din  = direct_wr ? hwdata : wb_data_q;
  assign m_bm   = direct_wr ? wr_mask_q : wb_mask_q;

  assign hrdata = (m_dout & ~rd_mask_q) | (rd_data_q & rd_mask_q);

  // Same block name in every branch: testbench backdoor path is
  // <inst>.g_macro.u_macro.i_SRAM_1P_behavioral_bm_bist.memory
  generate
    if (WORDS == 1024) begin : g_macro
      RM_IHPSG13_1P_1024x32_c2_bm_bist u_macro (
        .A_CLK(hclk), .A_MEN(m_men), .A_WEN(m_wen), .A_REN(m_ren),
        .A_ADDR(m_addr), .A_DIN(m_din), .A_DLY(1'b1), .A_DOUT(m_dout), .A_BM(m_bm),
        .A_BIST_CLK(1'b0), .A_BIST_EN(1'b0), .A_BIST_MEN(1'b0), .A_BIST_WEN(1'b0),
        .A_BIST_REN(1'b0), .A_BIST_ADDR('0), .A_BIST_DIN(32'd0), .A_BIST_BM(32'd0)
      );
    end else if (WORDS == 512) begin : g_macro
      RM_IHPSG13_1P_512x32_c2_bm_bist u_macro (
        .A_CLK(hclk), .A_MEN(m_men), .A_WEN(m_wen), .A_REN(m_ren),
        .A_ADDR(m_addr), .A_DIN(m_din), .A_DLY(1'b1), .A_DOUT(m_dout), .A_BM(m_bm),
        .A_BIST_CLK(1'b0), .A_BIST_EN(1'b0), .A_BIST_MEN(1'b0), .A_BIST_WEN(1'b0),
        .A_BIST_REN(1'b0), .A_BIST_ADDR('0), .A_BIST_DIN(32'd0), .A_BIST_BM(32'd0)
      );
    end else if (WORDS == 256) begin : g_macro
      RM_IHPSG13_1P_256x32_c2_bm_bist u_macro (
        .A_CLK(hclk), .A_MEN(m_men), .A_WEN(m_wen), .A_REN(m_ren),
        .A_ADDR(m_addr), .A_DIN(m_din), .A_DLY(1'b1), .A_DOUT(m_dout), .A_BM(m_bm),
        .A_BIST_CLK(1'b0), .A_BIST_EN(1'b0), .A_BIST_MEN(1'b0), .A_BIST_WEN(1'b0),
        .A_BIST_REN(1'b0), .A_BIST_ADDR('0), .A_BIST_DIN(32'd0), .A_BIST_BM(32'd0)
      );
    end else begin : g_macro_unsupported
      $error("torv_ahb_sram: WORDS must be 256, 512 or 1024");
    end
  endgenerate
endmodule
