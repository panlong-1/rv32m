// Simple byte-addressable AHB-Lite SRAM model for directed core tests.
module ahb_sram_model #(
  parameter int BYTES = 65536,
  parameter logic TOHOST_ENABLE = 1'b0,
  parameter logic [31:0] TOHOST_ADDR = 32'hF000_0000
) (
  input  logic        hclk,
  input  logic        hresetn,
  input  logic [31:0] haddr,
  input  logic [1:0]  htrans,
  input  logic        hwrite,
  input  logic [2:0]  hsize,
  input  logic [31:0] hwdata,
  output logic [31:0] hrdata,
  output logic        hready,
  output logic        hresp
);
  localparam logic [1:0] HTRANS_IDLE = 2'b00;

  logic [7:0] mem[BYTES];

  logic        data_valid_q;
  logic        write_q;
  logic [2:0]  size_q;
  logic [31:0] addr_q;

  assign hready = 1'b1;
  assign hresp  = 1'b0;

  function automatic logic [31:0] read_word(input logic [31:0] addr);
    logic [31:0] base;
    begin
      base = {addr[31:2], 2'b00};
      read_word = {mem[(base + 3) % BYTES],
                   mem[(base + 2) % BYTES],
                   mem[(base + 1) % BYTES],
                   mem[(base + 0) % BYTES]};
    end
  endfunction

  always_comb begin
    hrdata = read_word(addr_q);
  end

  always @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      data_valid_q <= 1'b0;
      write_q      <= 1'b0;
      size_q       <= 3'b010;
      addr_q       <= 32'd0;
    end else begin
      data_valid_q <= (htrans != HTRANS_IDLE);
      if (htrans != HTRANS_IDLE) begin
        write_q <= hwrite;
        size_q  <= hsize;
        addr_q  <= haddr;
      end

      if (data_valid_q && write_q) begin
        if (TOHOST_ENABLE && (addr_q == TOHOST_ADDR)) begin
          if (hwdata[7:0] == 8'h01) begin
            $display("[PASS] AHB tohost signalled success");
            $finish(0);
          end else begin
            $error("[FAIL] AHB tohost signalled 0x%02h", hwdata[7:0]);
            $finish(1);
          end
        end

        unique case (size_q)
          3'b000: begin
            mem[addr_q % BYTES] <= hwdata[8 * addr_q[1:0] +: 8];
          end
          3'b001: begin
            mem[{addr_q[31:1], 1'b0} % BYTES] <= hwdata[16 * addr_q[1] +: 8];
            mem[({addr_q[31:1], 1'b0} + 1) % BYTES] <= hwdata[16 * addr_q[1] + 8 +: 8];
          end
          default: begin
            mem[{addr_q[31:2], 2'b00} % BYTES] <= hwdata[7:0];
            mem[({addr_q[31:2], 2'b00} + 1) % BYTES] <= hwdata[15:8];
            mem[({addr_q[31:2], 2'b00} + 2) % BYTES] <= hwdata[23:16];
            mem[({addr_q[31:2], 2'b00} + 3) % BYTES] <= hwdata[31:24];
          end
        endcase
      end
    end
  end
endmodule
