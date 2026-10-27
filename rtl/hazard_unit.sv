// Hazard / pipeline control (spec §9)
//
// Pipelined buses (IBUS fetch, DBUS/SBUS address phase in EX, data phase in
// MEM) make the back end simple: only a bus wait state (HREADY low on a bus
// with an active address or data phase) freezes the whole pipeline. Every other
// hazard stops the front end and inserts a bubble behind it, so MEM/WB keep
// draining and a load/store is never issued twice.
//
// Priority: bus_stall > flush > div_busy > load_use > IBUS not ready.
module hazard_unit (
  input  logic        id_ex_mem_read,
  input  logic [4:0]  id_ex_rd,
  input  logic [31:0] if_id_inst,
  input  logic        ex_branch_taken,
  input  logic        ibus_ready,
  input  logic        bus_stall,
  input  logic        div_busy,
  output logic        flush,
  output logic        stall_pc,
  output logic        stall_if_id,
  output logic        bubble_if_id,
  output logic        stall_id_ex,
  output logic        bubble_id_ex,
  output logic        stall_ex_mem,
  output logic        bubble_ex_mem,
  output logic        stall_mem_wb
);
  localparam logic [6:0] OP_STORE = 7'b0100011;
  localparam logic [6:0] OP_BR    = 7'b1100011;
  localparam logic [6:0] OP_JAL   = 7'b1101111;
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

  // A taken branch cannot leave EX while the pipeline is frozen.
  assign flush = ex_branch_taken && !bus_stall;

  always_comb begin
    stall_pc      = 1'b0;
    stall_if_id   = 1'b0;
    bubble_if_id  = 1'b0;
    stall_id_ex   = 1'b0;
    bubble_id_ex  = 1'b0;
    stall_ex_mem  = 1'b0;
    bubble_ex_mem = 1'b0;
    stall_mem_wb  = 1'b0;

    if (bus_stall) begin
      stall_pc     = 1'b1;
      stall_if_id  = 1'b1;
      stall_id_ex  = 1'b1;
      stall_ex_mem = 1'b1;
      stall_mem_wb = 1'b1;
    end else if (flush) begin
      // PC takes the target; IF/ID and ID/EX are cleared by flush.
    end else if (div_busy) begin
      stall_pc      = 1'b1;
      stall_if_id   = 1'b1;
      stall_id_ex   = 1'b1;
      bubble_ex_mem = 1'b1;
    end else if (load_use) begin
      stall_pc     = 1'b1;
      stall_if_id  = 1'b1;
      bubble_id_ex = 1'b1;
    end else if (!ibus_ready) begin
      stall_pc     = 1'b1;
      bubble_if_id = 1'b1;
    end
  end
endmodule
