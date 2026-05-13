// 32 x 32 register file, x0 hardwired (spec §12)
module regfile (
  input  logic        clk,
  input  logic [4:0]  ra1,
  input  logic [4:0]  ra2,
  output logic [31:0] rd1,
  output logic [31:0] rd2,
  input  logic        we,
  input  logic [4:0]  wa,
  input  logic [31:0] wd
);
  logic [31:0] mem[31:1];

  always_comb begin
    rd1 = (ra1 == 5'd0) ? 32'd0 : mem[ra1];
    rd2 = (ra2 == 5'd0) ? 32'd0 : mem[ra2];
  end

  always_ff @(posedge clk) begin
    if (we && (wa != 5'd0))
      mem[wa] <= wd;
  end
endmodule
