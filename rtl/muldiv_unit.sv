// RV32M multiply/divide (spec §3 EX, §9.1)
// MUL* uses one shared combinational 33x33 multiplier. DIV/REM uses an
// iterative restoring divider to avoid synthesizing a large combinational / %.
module muldiv_unit (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        flush,
  input  logic        valid,
  input  logic [2:0]  op,
  input  logic [31:0] rs1,
  input  logic [31:0] rs2,
  output logic        busy,
  output logic        ready,
  output logic [31:0] result
);
  logic        is_divrem;
  logic        is_signed_divrem;
  assign is_divrem        = op[2];
  assign is_signed_divrem = (op == 3'b100) || (op == 3'b110);

  logic signed [32:0] mul_a;
  logic signed [32:0] mul_b;
  logic signed [65:0] mul_p;
  logic [31:0]        mul_result;

  always_comb begin
    unique case (op)
      3'b000, 3'b001: begin // MUL/MULH signed x signed
        mul_a = {rs1[31], rs1};
        mul_b = {rs2[31], rs2};
      end
      3'b010: begin // MULHSU signed x unsigned
        mul_a = {rs1[31], rs1};
        mul_b = {1'b0, rs2};
      end
      3'b011: begin // MULHU unsigned x unsigned
        mul_a = {1'b0, rs1};
        mul_b = {1'b0, rs2};
      end
      default: begin
        mul_a = 33'd0;
        mul_b = 33'd0;
      end
    endcase
  end
  assign mul_p = mul_a * mul_b;

  always_comb begin
    unique case (op)
      3'b000: mul_result = mul_p[31:0];
      3'b001,
      3'b010,
      3'b011: mul_result = mul_p[63:32];
      default: mul_result = 32'd0;
    endcase
  end

  logic        active_r;
  logic        ready_r;
  logic [5:0]  iter_r;
  logic [2:0]  op_r;
  logic [31:0] divisor_r;
  logic [31:0] quotient_r;
  logic [32:0] remainder_r;
  logic        quot_neg_r;
  logic        rem_neg_r;
  logic [31:0] result_r;

  logic [31:0] abs_rs1;
  logic [31:0] abs_rs2;
  logic        rs1_neg;
  logic        rs2_neg;

  always_comb begin
    rs1_neg = rs1[31];
    rs2_neg = rs2[31];
    abs_rs1 = (is_signed_divrem && rs1_neg) ? (~rs1 + 32'd1) : rs1;
    abs_rs2 = (is_signed_divrem && rs2_neg) ? (~rs2 + 32'd1) : rs2;
  end

  logic [32:0] rem_shift;
  logic [31:0] quot_shift;
  logic [32:0] rem_next;
  logic [31:0] quot_next;

  always_comb begin
    rem_shift  = {remainder_r[31:0], quotient_r[31]};
    quot_shift = {quotient_r[30:0], 1'b0};
    if (rem_shift >= {1'b0, divisor_r}) begin
      rem_next  = rem_shift - {1'b0, divisor_r};
      quot_next = {quot_shift[31:1], 1'b1};
    end else begin
      rem_next  = rem_shift;
      quot_next = quot_shift;
    end
  end

  function automatic logic [31:0] finish_result(
    input logic [2:0]  div_op,
    input logic [31:0] q_abs,
    input logic [31:0] r_abs,
    input logic        q_neg,
    input logic        r_neg
  );
    logic [31:0] q_signed;
    logic [31:0] r_signed;
    begin
      q_signed = q_neg ? (~q_abs + 32'd1) : q_abs;
      r_signed = r_neg ? (~r_abs + 32'd1) : r_abs;
      unique case (div_op)
        3'b100: finish_result = q_signed;
        3'b101: finish_result = q_abs;
        3'b110: finish_result = r_signed;
        3'b111: finish_result = r_abs;
        default: finish_result = 32'd0;
      endcase
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active_r    <= 1'b0;
      ready_r     <= 1'b0;
      iter_r      <= 6'd0;
      op_r        <= 3'd0;
      divisor_r   <= 32'd0;
      quotient_r  <= 32'd0;
      remainder_r <= 33'd0;
      quot_neg_r  <= 1'b0;
      rem_neg_r   <= 1'b0;
      result_r    <= 32'd0;
    end else if (flush) begin
      active_r    <= 1'b0;
      ready_r     <= 1'b0;
      iter_r      <= 6'd0;
      op_r        <= 3'd0;
      divisor_r   <= 32'd0;
      quotient_r  <= 32'd0;
      remainder_r <= 33'd0;
      quot_neg_r  <= 1'b0;
      rem_neg_r   <= 1'b0;
      result_r    <= 32'd0;
    end else begin
      if (ready_r) begin
        ready_r <= 1'b0;
      end else if (active_r) begin
        quotient_r  <= quot_next;
        remainder_r <= rem_next;
        if (iter_r == 6'd31) begin
          active_r <= 1'b0;
          ready_r  <= 1'b1;
          result_r <= finish_result(op_r, quot_next, rem_next[31:0], quot_neg_r, rem_neg_r);
        end else begin
          iter_r <= iter_r + 6'd1;
        end
      end else if (valid && is_divrem) begin
        op_r   <= op;
        iter_r <= 6'd0;

        if (rs2 == 32'd0) begin
          ready_r  <= 1'b1;
          result_r <= (op == 3'b100 || op == 3'b101) ? 32'hFFFF_FFFF : rs1;
        end else if ((op == 3'b100 || op == 3'b110) &&
                     (rs1 == 32'h8000_0000) && (rs2 == 32'hFFFF_FFFF)) begin
          ready_r  <= 1'b1;
          result_r <= (op == 3'b100) ? 32'h8000_0000 : 32'd0;
        end else begin
          active_r    <= 1'b1;
          ready_r     <= 1'b0;
          divisor_r   <= abs_rs2;
          quotient_r  <= abs_rs1;
          remainder_r <= 33'd0;
          quot_neg_r  <= is_signed_divrem && (rs1_neg ^ rs2_neg);
          rem_neg_r   <= is_signed_divrem && rs1_neg;
        end
      end
    end
  end

  assign ready  = valid && !is_divrem ? 1'b1 : ready_r;
  assign busy   = active_r || (valid && is_divrem && !ready_r);
  assign result = (valid && !is_divrem) ? mul_result : result_r;
endmodule
