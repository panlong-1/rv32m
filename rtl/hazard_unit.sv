// Hazard / pipeline control (spec §9)
//
// Bus-interaction fixes (2026-05):
//   Bug1 — flush is suppressed while stall_mem is active so a taken branch in EX
//          is not cleared before PC can take the target after DBUS/SBUS stall.
//   Bug2 — front-end stall always freezes ID/EX; IBUS stall holds EX/MEM instead
//          of bubbling a completed beat (pairs with rv32im_core mem_wb gating).
module hazard_unit (
  input  logic        id_ex_mem_read,
  input  logic [4:0]  id_ex_rd,
  input  logic [31:0] if_id_inst,
  input  logic        ex_mem_mem_write,
  input  logic        ex_branch_taken,
  input  logic        ibus_valid,
  input  logic        ibus_ready,
  input  logic        dbus_valid,
  input  logic        dbus_valid_stall,
  input  logic        dbus_ready,
  input  logic        sbus_valid,
  input  logic        sbus_valid_stall,
  input  logic        sbus_ready,
  input  logic        div_busy,
  output logic        flush,
  output logic        stall_pc,
  output logic        stall_if_id,
  output logic        stall_id_ex,
  output logic        stall_ex_mem,
  output logic        bubble_ex_mem,
  output logic        bubble_id_ex
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

  logic [6:0] op;
  logic [4:0] rs1_f;
  logic [4:0] rs2_f;
  logic       uses_rs1;
  logic       uses_rs2;

  assign op    = if_id_inst[6:0];
  assign rs1_f = if_id_inst[19:15];
  assign rs2_f = if_id_inst[24:20];

  always_comb begin
    uses_rs1 = 1'b1;
    uses_rs2 = 1'b0;
    unique case (op)
      OP_JAL, OP_LUI, OP_AUIPC: uses_rs1 = 1'b0;
      default: uses_rs1 = 1'b1;
    endcase
    unique case (op)
      OP_REG, OP_STORE, OP_BR: uses_rs2 = 1'b1;
      default: uses_rs2 = 1'b0;
    endcase
  end

  logic load_use;
  assign load_use = id_ex_mem_read && (id_ex_rd != 5'd0) &&
      (((id_ex_rd == rs1_f) && uses_rs1) || ((id_ex_rd == rs2_f) && uses_rs2));

  logic ibus_stall;
  logic dbus_stall;
  logic sbus_stall;
  logic mem_bus_stall;

  assign ibus_stall     = ibus_valid && !ibus_ready;
  assign dbus_stall = (dbus_valid_stall || dbus_valid) && !dbus_ready;
  assign sbus_stall = (sbus_valid_stall || sbus_valid) && !sbus_ready;
  assign mem_bus_stall  = dbus_stall || sbus_stall;

  logic stall_mem;
  logic stall_front;
  assign stall_mem  = mem_bus_stall || div_busy;
  assign stall_front = ibus_stall || load_use || div_busy;

  logic dbus_done;
  logic sbus_done;
  assign dbus_done = dbus_ready && (dbus_valid || dbus_valid_stall);
  assign sbus_done = sbus_ready && (sbus_valid || sbus_valid_stall);

  always_comb begin
    // Do not flush while MEM is stalled: PC is frozen and clearing ID/EX would
    // drop the branch before the target is captured (Bug1: branch+mem stall).
    flush       = ex_branch_taken && !stall_mem;
    stall_pc    = 1'b0;
    stall_if_id = 1'b0;
    stall_id_ex = 1'b0;
    stall_ex_mem = 1'b0;
    bubble_ex_mem = 1'b0;
    bubble_id_ex = 1'b0;

    // Memory must stall the entire pipeline (including on a flush cycle) until
    // the pending DBUS/SBUS beat completes. If flush is checked first, a taken
    // branch could suppress stall_mem and corrupt EX/MEM while the bridge is
    // still busy — seen as an infinite SBUS retry on early SBUS stores.
    if (stall_mem) begin
      stall_pc     = 1'b1;
      stall_if_id  = 1'b1;
      stall_id_ex  = 1'b1;
      stall_ex_mem = 1'b1;
    end else if (flush) begin
    end else if (load_use) begin
      stall_pc     = 1'b1;
      stall_if_id  = 1'b1;
      bubble_id_ex = 1'b1;
    end else if (stall_front) begin
      stall_pc     = 1'b1;
      stall_if_id  = 1'b1;
      // Always stall ID/EX on front-end stall (removed IBUS+store hack that let
      // ID/EX advance while IF/ID was frozen and duplicated the ID instruction).
      stall_id_ex  = 1'b1;
      if (!dbus_done && !sbus_done) begin
        // If ID/EX is frozen by the front-end stall, keep EX/MEM from
        // re-capturing the same instruction after a completed beat was bubbled.
        stall_ex_mem = (dbus_valid || sbus_valid || stall_id_ex);
      end else if (ibus_stall) begin
        // Hold EX/MEM during IBUS back-pressure (avoid bubble_ex_mem re-issue).
        stall_ex_mem = 1'b1;
      end else begin
        bubble_ex_mem = 1'b1;
      end
    end
  end
endmodule
