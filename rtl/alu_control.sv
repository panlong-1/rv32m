// ALU control — 4-bit ALU operation (spec §7)
module alu_control (
  input  logic       is_lui,
  input  logic [1:0] alu_op,
  input  logic [2:0] funct3,
  input  logic       funct7_30,
  output logic [3:0] alu_ctrl
);
  localparam logic [3:0] ALU_ADD  = 4'd0;
  localparam logic [3:0] ALU_SUB  = 4'd1;
  localparam logic [3:0] ALU_AND  = 4'd2;
  localparam logic [3:0] ALU_OR   = 4'd3;
  localparam logic [3:0] ALU_XOR  = 4'd4;
  localparam logic [3:0] ALU_SLT  = 4'd5;
  localparam logic [3:0] ALU_SLTU = 4'd6;
  localparam logic [3:0] ALU_SLL  = 4'd7;
  localparam logic [3:0] ALU_SRL  = 4'd8;
  localparam logic [3:0] ALU_SRA  = 4'd9;
  localparam logic [3:0] ALU_PASS_B = 4'd10;

  always_comb begin
    if (is_lui)
      alu_ctrl = ALU_PASS_B;
    else unique case (alu_op)
      2'b00: alu_ctrl = ALU_ADD;
      2'b01: alu_ctrl = ALU_SUB;
      2'b10: begin
        unique case (funct3)
          3'b000: alu_ctrl = funct7_30 ? ALU_SUB : ALU_ADD;
          3'b001: alu_ctrl = ALU_SLL;
          3'b010: alu_ctrl = ALU_SLT;
          3'b011: alu_ctrl = ALU_SLTU;
          3'b100: alu_ctrl = ALU_XOR;
          3'b101: alu_ctrl = funct7_30 ? ALU_SRA : ALU_SRL;
          3'b110: alu_ctrl = ALU_OR;
          3'b111: alu_ctrl = ALU_AND;
        endcase
      end
      2'b11: begin
        unique case (funct3)
          3'b000: alu_ctrl = ALU_ADD;
          3'b001: alu_ctrl = ALU_SLL;
          3'b010: alu_ctrl = ALU_SLT;
          3'b011: alu_ctrl = ALU_SLTU;
          3'b100: alu_ctrl = ALU_XOR;
          3'b101: alu_ctrl = funct7_30 ? ALU_SRA : ALU_SRL;
          3'b110: alu_ctrl = ALU_OR;
          3'b111: alu_ctrl = ALU_AND;
        endcase
      end
      default: alu_ctrl = ALU_ADD;
    endcase
  end
endmodule
