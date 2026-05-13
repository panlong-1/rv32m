// PC register and next-PC mux (spec §3 stage IF, §5)
module pc_unit (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        stall_pc,
  input  logic [31:0] pc_next,
  output logic [31:0] pc,
  output logic [31:0] pc_plus4
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pc <= 32'h0000_0000;
    else if (!stall_pc)
      pc <= pc_next;
  end

  assign pc_plus4 = pc + 32'd4;
endmodule
