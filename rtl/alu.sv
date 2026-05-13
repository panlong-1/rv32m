// Integer ALU (spec §3 EX)
module alu (
  input  logic [3:0]  alu_ctrl,
  input  logic [31:0] a,
  input  logic [31:0] b,
  output logic [31:0] y,
  output logic        zero
);
  localparam logic [3:0] ALU_ADD    = 4'd0;
  localparam logic [3:0] ALU_SUB    = 4'd1;
  localparam logic [3:0] ALU_AND    = 4'd2;
  localparam logic [3:0] ALU_OR     = 4'd3;
  localparam logic [3:0] ALU_XOR    = 4'd4;
  localparam logic [3:0] ALU_SLT    = 4'd5;
  localparam logic [3:0] ALU_SLTU   = 4'd6;
  localparam logic [3:0] ALU_SLL    = 4'd7;
  localparam logic [3:0] ALU_SRL    = 4'd8;
  localparam logic [3:0] ALU_SRA    = 4'd9;
  localparam logic [3:0] ALU_PASS_B = 4'd10;

  logic        use_sub_path;
  logic [31:0] b_addsub;
  logic [32:0] addsub_ext;
  logic [31:0] addsub_y;
  logic        carry_out;
  logic        signed_lt;
  logic        unsigned_lt;

  assign use_sub_path = (alu_ctrl == ALU_SUB) || (alu_ctrl == ALU_SLT) || (alu_ctrl == ALU_SLTU);
  assign b_addsub     = use_sub_path ? ~b : b;
  assign addsub_ext   = {1'b0, a} + {1'b0, b_addsub} + {32'd0, use_sub_path};
  assign addsub_y     = addsub_ext[31:0];
  assign carry_out    = addsub_ext[32];

  // Comparators reuse the subtract path: a - b.
  assign signed_lt   = (a[31] != b[31]) ? a[31] : addsub_y[31];
  assign unsigned_lt = ~carry_out;

  logic [31:0] sll_1;
  logic [31:0] sll_2;
  logic [31:0] sll_4;
  logic [31:0] sll_8;
  logic [31:0] sll_16;

  logic [31:0] srl_1;
  logic [31:0] srl_2;
  logic [31:0] srl_4;
  logic [31:0] srl_8;
  logic [31:0] srl_16;

  logic [31:0] sra_1;
  logic [31:0] sra_2;
  logic [31:0] sra_4;
  logic [31:0] sra_8;
  logic [31:0] sra_16;

  // Five mux stages implement the 32-bit barrel shifter explicitly.
  assign sll_1  = b[0] ? {a[30:0], 1'b0}      : a;
  assign sll_2  = b[1] ? {sll_1[29:0], 2'b0}  : sll_1;
  assign sll_4  = b[2] ? {sll_2[27:0], 4'b0}  : sll_2;
  assign sll_8  = b[3] ? {sll_4[23:0], 8'b0}  : sll_4;
  assign sll_16 = b[4] ? {sll_8[15:0], 16'b0} : sll_8;

  assign srl_1  = b[0] ? {1'b0, a[31:1]}           : a;
  assign srl_2  = b[1] ? {2'b0, srl_1[31:2]}       : srl_1;
  assign srl_4  = b[2] ? {4'b0, srl_2[31:4]}       : srl_2;
  assign srl_8  = b[3] ? {8'b0, srl_4[31:8]}       : srl_4;
  assign srl_16 = b[4] ? {16'b0, srl_8[31:16]}     : srl_8;

  assign sra_1  = b[0] ? {a[31], a[31:1]}          : a;
  assign sra_2  = b[1] ? {{2{sra_1[31]}}, sra_1[31:2]}   : sra_1;
  assign sra_4  = b[2] ? {{4{sra_2[31]}}, sra_2[31:4]}   : sra_2;
  assign sra_8  = b[3] ? {{8{sra_4[31]}}, sra_4[31:8]}   : sra_4;
  assign sra_16 = b[4] ? {{16{sra_8[31]}}, sra_8[31:16]} : sra_8;

  always_comb begin
    unique case (alu_ctrl)
      ALU_ADD:    y = addsub_y;
      ALU_SUB:    y = addsub_y;
      ALU_AND:    y = a & b;
      ALU_OR:     y = a | b;
      ALU_XOR:    y = a ^ b;
      ALU_SLT:    y = {31'd0, signed_lt};
      ALU_SLTU:   y = {31'd0, unsigned_lt};
      ALU_SLL:    y = sll_16;
      ALU_SRL:    y = srl_16;
      ALU_SRA:    y = sra_16;
      ALU_PASS_B: y = b;
      default:    y = 32'd0;
    endcase
  end

  assign zero = (y == 32'd0);
endmodule
