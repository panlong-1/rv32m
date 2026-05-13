// Main decoder — Phase 1 subset (spec §6–7)
module decoder (
  input  logic [6:0] opcode,
  input  logic [2:0] funct3,
  input  logic [6:0] funct7,
  output logic       reg_write,
  output logic       mem_read,
  output logic       mem_write,
  output logic [1:0] wb_sel,
  output logic       alu_src,
  output logic [1:0] alu_op,
  output logic       branch,
  output logic       jump,
  output logic [2:0] imm_type,
  output logic       muldiv,
  output logic       is_lui,
  output logic       is_auipc,
  output logic       is_jalr,
  output logic       illegal
);
  localparam logic [6:0] OP_LOAD  = 7'b0000011;
  localparam logic [6:0] OP_STORE = 7'b0100011;
  localparam logic [6:0] OP_BR    = 7'b1100011;
  localparam logic [6:0] OP_JAL   = 7'b1101111;
  localparam logic [6:0] OP_JALR  = 7'b1100111;
  localparam logic [6:0] OP_IMM   = 7'b0010011;
  localparam logic [6:0] OP_AUIPC = 7'b0010111;
  localparam logic [6:0] OP_REG   = 7'b0110011;
  localparam logic [6:0] OP_LUI   = 7'b0110111;

  localparam logic [2:0] IMM_NONE = 3'd0;
  localparam logic [2:0] IMM_I    = 3'd1;
  localparam logic [2:0] IMM_S    = 3'd2;
  localparam logic [2:0] IMM_B    = 3'd3;
  localparam logic [2:0] IMM_U    = 3'd4;
  localparam logic [2:0] IMM_J    = 3'd5;

  always_comb begin
    reg_write = 1'b0;
    mem_read  = 1'b0;
    mem_write = 1'b0;
    wb_sel    = 2'b00;
    alu_src   = 1'b0;
    alu_op    = 2'b00;
    branch    = 1'b0;
    jump      = 1'b0;
    imm_type  = IMM_NONE;
    muldiv    = 1'b0;
    illegal   = 1'b0;
    is_lui    = 1'b0;
    is_auipc  = 1'b0;
    is_jalr   = 1'b0;

    unique case (opcode)
      OP_REG: begin
        imm_type = IMM_NONE;
        alu_src  = 1'b0;
        if (funct7 == 7'b0000001) begin
          muldiv    = 1'b1;
          reg_write = 1'b1;
          wb_sel    = 2'b00;
          alu_op    = 2'b10;
        end else begin
          reg_write = 1'b1;
          wb_sel    = 2'b00;
          alu_op    = 2'b10;
        end
      end
      OP_IMM: begin
        reg_write = 1'b1;
        wb_sel    = 2'b00;
        alu_src   = 1'b1;
        alu_op    = 2'b11;
        imm_type  = IMM_I;
      end
      OP_LOAD: begin
        reg_write = 1'b1;
        mem_read  = 1'b1;
        wb_sel    = 2'b01;
        alu_src   = 1'b1;
        alu_op    = 2'b00;
        imm_type  = IMM_I;
      end
      OP_STORE: begin
        mem_write = 1'b1;
        alu_src   = 1'b1;
        alu_op    = 2'b00;
        imm_type  = IMM_S;
      end
      OP_BR: begin
        branch   = 1'b1;
        alu_src  = 1'b0;
        alu_op   = 2'b01;
        imm_type = IMM_B;
      end
      OP_JAL: begin
        reg_write = 1'b1;
        jump      = 1'b1;
        wb_sel    = 2'b10;
        imm_type  = IMM_J;
      end
      OP_JALR: begin
        reg_write = 1'b1;
        jump      = 1'b1;
        wb_sel    = 2'b10;
        alu_src   = 1'b1;
        alu_op    = 2'b00;
        imm_type  = IMM_I;
        is_jalr   = 1'b1;
      end
      OP_LUI: begin
        reg_write = 1'b1;
        wb_sel    = 2'b00;
        alu_src   = 1'b1;
        alu_op    = 2'b00;
        imm_type  = IMM_U;
        is_lui    = 1'b1;
      end
      OP_AUIPC: begin
        reg_write = 1'b1;
        wb_sel    = 2'b00;
        alu_src   = 1'b1;
        alu_op    = 2'b00;
        imm_type  = IMM_U;
        is_auipc  = 1'b1;
      end
      default: illegal = 1'b1;
    endcase
  end
endmodule
