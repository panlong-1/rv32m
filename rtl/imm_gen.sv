// Immediate generation (spec §8)
module imm_gen (
  input  logic [31:0] inst,
  input  logic [2:0]  imm_type,
  output logic [31:0] imm
);
  localparam logic [2:0] IMM_NONE = 3'd0;
  localparam logic [2:0] IMM_I    = 3'd1;
  localparam logic [2:0] IMM_S    = 3'd2;
  localparam logic [2:0] IMM_B    = 3'd3;
  localparam logic [2:0] IMM_U    = 3'd4;
  localparam logic [2:0] IMM_J    = 3'd5;

  always_comb begin
    unique case (imm_type)
      IMM_I: imm = {{20{inst[31]}}, inst[31:20]};
      IMM_S: imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
      IMM_B: imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
      IMM_U: imm = {inst[31:12], 12'b0};
      IMM_J: imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
      default: imm = 32'd0;
    endcase
  end
endmodule
