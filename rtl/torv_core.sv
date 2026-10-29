// RV32IM five-stage Harvard core (IBUS / DBUS / SBUS). Microarchitecture
// reference: spec/RV32IM_Current_Implementation.md (internal doc version V3).
//
// Stages: IF (pc + imem), ID (decode/regfile), EX (alu / muldiv / branch),
// MEM (load-store unit), WB (register writeback). Hazard unit handles
// load-use, mul/div occupancy, and bus stalls; forwarding covers EX/MEM
// and MEM/WB to EX.

module torv_core (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        ibus_ready,
  output logic [31:0] ibus_addr,
  output logic [31:0] ibus_next_addr,
  input  logic [31:0] ibus_rdata,
  // DBUS/SBUS: valid/addr/we/be are the address phase (EX), wdata/rdata the
  // data phase (MEM); ready is the bus HREADY, dph flags an active data phase.
  output logic        dbus_valid,
  input  logic        dbus_ready,
  input  logic        dbus_dph,
  output logic [31:0] dbus_addr,
  output logic        dbus_we,
  output logic [3:0]  dbus_be,
  output logic [31:0] dbus_wdata,
  input  logic [31:0] dbus_rdata,
  output logic        sbus_valid,
  input  logic        sbus_ready,
  input  logic        sbus_dph,
  output logic [31:0] sbus_addr,
  output logic        sbus_we,
  output logic [3:0]  sbus_be,
  output logic [31:0] sbus_wdata,
  input  logic [31:0] sbus_rdata
);
  localparam logic [31:0] NOP_INSTR = 32'h0000_0013;

  logic [31:0] pc_next;
  logic [31:0] pc;
  logic [31:0] pc_plus4;
  logic        stall_pc_h;
  logic        stall_if_id;
  logic        bubble_if_id;
  logic        stall_id_ex;
  logic        stall_ex_mem;
  logic        stall_mem_wb;
  logic        bubble_ex_mem;
  logic        bubble_id_ex;
  logic        flush;

  logic [31:0] ex_branch_target;
  logic        ex_branch_taken;

  assign pc_next = ex_branch_taken ? ex_branch_target : pc_plus4;

  torv_pc_unit u_pc (
    .clk(clk),
    .rst_n(rst_n),
    .stall_pc(stall_pc_h),
    .pc_next(pc_next),
    .pc(pc),
    .pc_plus4(pc_plus4)
  );

  logic [31:0] if_id_pc;
  logic [31:0] if_id_inst;
  logic [31:0] if_id_pc_p4;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      if_id_pc    <= 32'd0;
      if_id_inst  <= NOP_INSTR;
      if_id_pc_p4 <= 32'd4;
    // Honor stall_if_id before flush: clearing IF/ID during a stall loses state.
    // bubble_if_id: no instruction fetched this cycle (IBUS not ready).
    end else if ((flush || bubble_if_id) && !stall_if_id) begin
      if_id_pc    <= 32'd0;
      if_id_inst  <= NOP_INSTR;
      if_id_pc_p4 <= 32'd0;
    end else if (!stall_if_id) begin
      if_id_pc    <= pc;
      if_id_inst  <= ibus_rdata;
      if_id_pc_p4 <= pc_plus4;
    end
  end

  assign ibus_addr  = pc;
  // PC of the next cycle; the pipelined fetch issues it as the AHB address phase.
  assign ibus_next_addr = stall_pc_h ? pc : pc_next;

  logic        d_reg_write;
  logic        d_mem_read;
  logic        d_mem_write;
  logic [1:0]  d_wb_sel;
  logic        d_alu_src;
  logic [1:0]  d_alu_op;
  logic        d_branch;
  logic        d_jump;
  logic [2:0]  d_imm_type;
  logic        d_muldiv;
  logic        d_is_lui;
  logic        d_is_auipc;
  logic        d_is_jalr;
  logic        d_illegal;

  torv_decoder u_dec (
    .opcode(if_id_inst[6:0]),
    .funct3(if_id_inst[14:12]),
    .funct7(if_id_inst[31:25]),
    .reg_write(d_reg_write),
    .mem_read(d_mem_read),
    .mem_write(d_mem_write),
    .wb_sel(d_wb_sel),
    .alu_src(d_alu_src),
    .alu_op(d_alu_op),
    .branch(d_branch),
    .jump(d_jump),
    .imm_type(d_imm_type),
    .muldiv(d_muldiv),
    .is_lui(d_is_lui),
    .is_auipc(d_is_auipc),
    .is_jalr(d_is_jalr),
    .illegal(d_illegal)
  );

  logic [31:0] d_imm;
  torv_imm_gen u_imm (
    .inst(if_id_inst),
    .imm_type(d_imm_type),
    .imm(d_imm)
  );

  logic [31:0] rf_rs1;
  logic [31:0] rf_rs2;
  logic        mem_wb_reg_write;
  logic [4:0]  mem_wb_rd;
  logic [31:0] wb_wdata;

  torv_regfile u_rf (
    .clk(clk),
    .ra1(if_id_inst[19:15]),
    .ra2(if_id_inst[24:20]),
    .rd1(rf_rs1),
    .rd2(rf_rs2),
    .we(mem_wb_reg_write),
    .wa(mem_wb_rd),
    .wd(wb_wdata)
  );

  logic [31:0] id_rs1_data;
  logic [31:0] id_rs2_data;

  always_comb begin
    id_rs1_data = rf_rs1;
    id_rs2_data = rf_rs2;

    // Model a write-first register file for same-cycle WB/ID dependencies.
    if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == if_id_inst[19:15]))
      id_rs1_data = wb_wdata;
    if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == if_id_inst[24:20]))
      id_rs2_data = wb_wdata;
  end

  logic [31:0] id_ex_pc;
  logic [31:0] id_ex_pc_p4;
  logic [31:0] id_ex_imm;
  logic [31:0] id_ex_rs1;
  logic [31:0] id_ex_rs2;
  logic [4:0]  id_ex_rs1_a;
  logic [4:0]  id_ex_rs2_a;
  logic [4:0]  id_ex_rd;
  logic [2:0]  id_ex_funct3;
  logic [6:0]  id_ex_funct7;
  logic [6:0]  id_ex_opcode;
  logic        id_ex_reg_write;
  logic        id_ex_mem_read;
  logic        id_ex_mem_write;
  logic [1:0]  id_ex_wb_sel;
  logic        id_ex_alu_src;
  logic [1:0]  id_ex_alu_op;
  logic        id_ex_branch;
  logic        id_ex_jump;
  logic        id_ex_muldiv;
  logic        id_ex_is_lui;
  logic        id_ex_is_auipc;
  logic        id_ex_is_jalr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      id_ex_pc        <= 32'd0;
      id_ex_pc_p4     <= 32'd0;
      id_ex_imm       <= 32'd0;
      id_ex_rs1       <= 32'd0;
      id_ex_rs2       <= 32'd0;
      id_ex_rs1_a     <= 5'd0;
      id_ex_rs2_a     <= 5'd0;
      id_ex_rd        <= 5'd0;
      id_ex_funct3    <= 3'd0;
      id_ex_funct7    <= 7'd0;
      id_ex_opcode    <= 7'd0;
      id_ex_reg_write <= 1'b0;
      id_ex_mem_read  <= 1'b0;
      id_ex_mem_write <= 1'b0;
      id_ex_wb_sel    <= 2'b00;
      id_ex_alu_src   <= 1'b0;
      id_ex_alu_op    <= 2'b00;
      id_ex_branch    <= 1'b0;
      id_ex_jump      <= 1'b0;
      id_ex_muldiv    <= 1'b0;
      id_ex_is_lui    <= 1'b0;
      id_ex_is_auipc  <= 1'b0;
      id_ex_is_jalr   <= 1'b0;
    // Honor stall_id_ex before flush (branch+mem stall, Bug1 companion).
    end else if (flush && !stall_id_ex) begin
      id_ex_pc        <= 32'd0;
      id_ex_pc_p4     <= 32'd0;
      id_ex_imm       <= 32'd0;
      id_ex_rs1       <= 32'd0;
      id_ex_rs2       <= 32'd0;
      id_ex_rs1_a     <= 5'd0;
      id_ex_rs2_a     <= 5'd0;
      id_ex_rd        <= 5'd0;
      id_ex_funct3    <= 3'd0;
      id_ex_funct7    <= 7'd0;
      id_ex_opcode    <= 7'd0;
      id_ex_reg_write <= 1'b0;
      id_ex_mem_read  <= 1'b0;
      id_ex_mem_write <= 1'b0;
      id_ex_wb_sel    <= 2'b00;
      id_ex_alu_src   <= 1'b0;
      id_ex_alu_op    <= 2'b00;
      id_ex_branch    <= 1'b0;
      id_ex_jump      <= 1'b0;
      id_ex_muldiv    <= 1'b0;
      id_ex_is_lui    <= 1'b0;
      id_ex_is_auipc  <= 1'b0;
      id_ex_is_jalr   <= 1'b0;
    end else if (!stall_id_ex) begin
      if (bubble_id_ex) begin
        id_ex_pc        <= 32'd0;
        id_ex_pc_p4     <= 32'd0;
        id_ex_imm       <= 32'd0;
        id_ex_rs1       <= 32'd0;
        id_ex_rs2       <= 32'd0;
        id_ex_rs1_a     <= 5'd0;
        id_ex_rs2_a     <= 5'd0;
        id_ex_rd        <= 5'd0;
        id_ex_funct3    <= 3'd0;
        id_ex_funct7    <= 7'd0;
        id_ex_opcode    <= 7'd0;
        id_ex_reg_write <= 1'b0;
        id_ex_mem_read  <= 1'b0;
        id_ex_mem_write <= 1'b0;
        id_ex_wb_sel    <= 2'b00;
        id_ex_alu_src   <= 1'b0;
        id_ex_alu_op    <= 2'b00;
        id_ex_branch    <= 1'b0;
        id_ex_jump      <= 1'b0;
        id_ex_muldiv    <= 1'b0;
        id_ex_is_lui    <= 1'b0;
        id_ex_is_auipc  <= 1'b0;
        id_ex_is_jalr   <= 1'b0;
      end else begin
        id_ex_pc        <= if_id_pc;
        id_ex_pc_p4     <= if_id_pc_p4;
        id_ex_imm       <= d_imm;
        id_ex_rs1       <= id_rs1_data;
        id_ex_rs2       <= id_rs2_data;
        id_ex_rs1_a     <= if_id_inst[19:15];
        id_ex_rs2_a     <= if_id_inst[24:20];
        id_ex_rd        <= if_id_inst[11:7];
        id_ex_funct3    <= if_id_inst[14:12];
        id_ex_funct7    <= if_id_inst[31:25];
        id_ex_opcode    <= if_id_inst[6:0];
        id_ex_reg_write <= d_reg_write;
        id_ex_mem_read  <= d_mem_read;
        id_ex_mem_write <= d_mem_write;
        id_ex_wb_sel    <= d_wb_sel;
        id_ex_alu_src   <= d_alu_src;
        id_ex_alu_op    <= d_alu_op;
        id_ex_branch    <= d_branch;
        id_ex_jump      <= d_jump;
        id_ex_muldiv    <= d_muldiv;
        id_ex_is_lui    <= d_is_lui;
        id_ex_is_auipc  <= d_is_auipc;
        id_ex_is_jalr   <= d_is_jalr;
      end
    end
  end

  // EX/MEM pipeline register
  logic        ex_mem_reg_write;
  logic        ex_mem_mem_read;
  logic        ex_mem_mem_write;
  logic [1:0]  ex_mem_wb_sel;
  logic [4:0]  ex_mem_rd;
  logic [31:0] ex_mem_alu;
  logic [31:0] ex_mem_store_data;
  logic [31:0] ex_mem_pc_p4;
  logic [2:0]  ex_mem_funct3;
  logic        use_sbus_exmem;

  logic [1:0] forward_a;
  logic [1:0] forward_b;

  // Registered forwarding selects (timing: keeps the rd/rs compare out of the
  // EX operand -> branch target / AGU -> AHB address-phase output paths).
  // The selects are a function of ID/EX, EX/MEM and MEM/WB state only, so
  // evaluating forwarding_unit on the next-state values of those fields and
  // registering the result gives exactly the combinational selects.
  logic       ex_mem_reg_write_d;
  logic       ex_mem_mem_read_d;
  logic [4:0] ex_mem_rd_d;
  logic       mem_wb_reg_write_d;
  logic [4:0] mem_wb_rd_d;
  logic [4:0] id_ex_rs1_a_d;
  logic [4:0] id_ex_rs2_a_d;
  logic [1:0] forward_a_d;
  logic [1:0] forward_b_d;

  // Mirrors the ID/EX, EX/MEM and MEM/WB register update conditions below.
  always_comb begin
    id_ex_rs1_a_d = id_ex_rs1_a;
    id_ex_rs2_a_d = id_ex_rs2_a;
    if ((flush || bubble_id_ex) && !stall_id_ex) begin
      id_ex_rs1_a_d = 5'd0;
      id_ex_rs2_a_d = 5'd0;
    end else if (!stall_id_ex) begin
      id_ex_rs1_a_d = if_id_inst[19:15];
      id_ex_rs2_a_d = if_id_inst[24:20];
    end

    ex_mem_reg_write_d = ex_mem_reg_write;
    ex_mem_mem_read_d  = ex_mem_mem_read;
    ex_mem_rd_d        = ex_mem_rd;
    if (!stall_ex_mem) begin
      ex_mem_reg_write_d = bubble_ex_mem ? 1'b0 : id_ex_reg_write;
      ex_mem_mem_read_d  = bubble_ex_mem ? 1'b0 : id_ex_mem_read;
      ex_mem_rd_d        = bubble_ex_mem ? 5'd0 : id_ex_rd;
    end

    mem_wb_reg_write_d = stall_mem_wb ? mem_wb_reg_write : ex_mem_reg_write;
    mem_wb_rd_d        = stall_mem_wb ? mem_wb_rd        : ex_mem_rd;
  end

  torv_forwarding_unit u_fwd (
    .ex_mem_regwrite(ex_mem_reg_write_d),
    .ex_mem_memread(ex_mem_mem_read_d),
    .ex_mem_rd(ex_mem_rd_d),
    .mem_wb_regwrite(mem_wb_reg_write_d),
    .mem_wb_rd(mem_wb_rd_d),
    .id_ex_rs1(id_ex_rs1_a_d),
    .id_ex_rs2(id_ex_rs2_a_d),
    .forward_a(forward_a_d),
    .forward_b(forward_b_d)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      forward_a <= 2'b00;
      forward_b <= 2'b00;
    end else begin
      forward_a <= forward_a_d;
      forward_b <= forward_b_d;
    end
  end

`ifndef SYNTHESIS
  // Simulation check: the registered selects must equal the combinational
  // forwarding decision on the current pipeline state.
  logic [1:0] forward_a_chk;
  logic [1:0] forward_b_chk;
  torv_forwarding_unit u_fwd_chk (
    .ex_mem_regwrite(ex_mem_reg_write),
    .ex_mem_memread(ex_mem_mem_read),
    .ex_mem_rd(ex_mem_rd),
    .mem_wb_regwrite(mem_wb_reg_write),
    .mem_wb_rd(mem_wb_rd),
    .id_ex_rs1(id_ex_rs1_a),
    .id_ex_rs2(id_ex_rs2_a),
    .forward_a(forward_a_chk),
    .forward_b(forward_b_chk)
  );
  always @(posedge clk) begin
    if (rst_n && (forward_a != forward_a_chk || forward_b != forward_b_chk))
      $fatal(1, "registered forwarding select mismatch: a=%b/%b b=%b/%b",
             forward_a, forward_a_chk, forward_b, forward_b_chk);
  end
`endif

  logic [31:0] mem_wb_result;
  logic [31:0] ex_mem_fwd_data;

  always_comb begin
    unique case (ex_mem_wb_sel)
      2'b10: ex_mem_fwd_data = ex_mem_pc_p4;
      default: ex_mem_fwd_data = ex_mem_alu;
    endcase
  end

  logic [31:0] fa_val;
  logic [31:0] fb_val;
  always_comb begin
    unique case (forward_a)
      2'b00: fa_val = id_ex_rs1;
      2'b10: fa_val = ex_mem_fwd_data;
      2'b01: fa_val = wb_wdata;
      default: fa_val = id_ex_rs1;
    endcase
    unique case (forward_b)
      2'b00: fb_val = id_ex_rs2;
      2'b10: fb_val = ex_mem_fwd_data;
      2'b01: fb_val = wb_wdata;
      default: fb_val = id_ex_rs2;
    endcase
  end

  logic [31:0] alu_in_b;
  logic [31:0] alu_in_a;
  assign alu_in_a = id_ex_is_auipc ? id_ex_pc : fa_val;
  assign alu_in_b = id_ex_alu_src ? id_ex_imm : fb_val;

  logic [3:0] alu_ctrl;
  torv_alu_ctrl u_aluctl (
    .is_lui(id_ex_is_lui),
    .alu_op(id_ex_alu_op),
    .funct3(id_ex_funct3),
    .funct7_30(id_ex_funct7[5]),
    .alu_ctrl(alu_ctrl)
  );

  logic [31:0] alu_y;
  logic        alu_zero;
  torv_alu u_alu (
    .alu_ctrl(alu_ctrl),
    .a(alu_in_a),
    .b(alu_in_b),
    .y(alu_y),
    .zero(alu_zero)
  );

  logic        md_busy;
  logic        md_ready;
  logic [31:0] md_result;
  torv_muldiv_unit u_md (
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .valid(id_ex_muldiv),
    .op(id_ex_funct3),
    .rs1(fa_val),
    .rs2(fb_val),
    .busy(md_busy),
    .ready(md_ready),
    .result(md_result)
  );

  logic md_stall;
  assign md_stall = id_ex_muldiv && !md_ready;

  logic [31:0] ex_alu_res;
  assign ex_alu_res = id_ex_muldiv ? md_result : alu_y;

  logic branch_cond;
  always_comb begin
    branch_cond = 1'b0;
    if (id_ex_branch) begin
      unique case (id_ex_funct3)
        3'b000: branch_cond = (fa_val == fb_val);
        3'b001: branch_cond = (fa_val != fb_val);
        3'b100: branch_cond = (signed'(fa_val) < signed'(fb_val));
        3'b101: branch_cond = (signed'(fa_val) >= signed'(fb_val));
        3'b110: branch_cond = (fa_val < fb_val);
        3'b111: branch_cond = (fa_val >= fb_val);
        default: branch_cond = 1'b0;
      endcase
    end
  end

  assign ex_branch_taken = (id_ex_branch && branch_cond) || id_ex_jump;
  assign ex_branch_target = id_ex_is_jalr ? ((fa_val + id_ex_imm) & 32'hFFFF_FFFE) :
                                            (id_ex_pc + id_ex_imm);

  // Load/store address phase is issued from EX; the data phase follows in MEM.
  logic        use_sbus_ex;
  logic        dbus_req_ex;
  logic        sbus_req_ex;
  logic [31:0] store_wdata_ex;
  logic [31:0] mem_addr_ex;

  // Dedicated AGU: loads/stores are always rs1 + imm, so the bus address does
  // not wait for the ALU control decode and operation mux (slow-corner timing:
  // this adder drives the AHB address-phase outputs).
  assign mem_addr_ex = fa_val + id_ex_imm;

  torv_addr_decode u_ad (
    .addr(mem_addr_ex),
    .use_sbus(use_sbus_ex)
  );

  torv_lsu u_lsu (
    .mem_read(id_ex_mem_read),
    .mem_write(id_ex_mem_write),
    .addr(mem_addr_ex),
    .wdata(fb_val),
    .funct3(id_ex_funct3),
    .use_sbus(use_sbus_ex),
    .dbus_valid(dbus_req_ex),
    .dbus_we(dbus_we),
    .dbus_be(dbus_be),
    .dbus_addr(dbus_addr),
    .dbus_wdata(store_wdata_ex),
    .sbus_valid(sbus_req_ex),
    .sbus_we(sbus_we),
    .sbus_be(sbus_be),
    .sbus_addr(sbus_addr),
    .sbus_wdata()
  );

  // A request is only presented while the other data bus is ready, and any
  // load/store in EX stalls while either bus is not ready. The request can then
  // never be accepted on a cycle where EX is held (no repeated access), and
  // bus_stall does not depend on the EX address decode (timing: it fans out to
  // every pipeline register enable).
  logic ex_mem_op;
  logic bus_stall;
  assign ex_mem_op  = id_ex_mem_read || id_ex_mem_write;
  assign dbus_valid = dbus_req_ex && sbus_ready;
  assign sbus_valid = sbus_req_ex && dbus_ready;
  assign bus_stall  = (dbus_dph && !dbus_ready) || (sbus_dph && !sbus_ready) ||
                      (ex_mem_op && !(dbus_ready && sbus_ready));

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex_mem_reg_write  <= 1'b0;
      ex_mem_mem_read   <= 1'b0;
      ex_mem_mem_write  <= 1'b0;
      ex_mem_wb_sel     <= 2'b00;
      ex_mem_rd         <= 5'd0;
      ex_mem_alu        <= 32'd0;
      ex_mem_store_data <= 32'd0;
      ex_mem_pc_p4      <= 32'd0;
      ex_mem_funct3     <= 3'd0;
      use_sbus_exmem    <= 1'b0;
    end else if (!stall_ex_mem) begin
      if (bubble_ex_mem) begin
        ex_mem_reg_write  <= 1'b0;
        ex_mem_mem_read   <= 1'b0;
        ex_mem_mem_write  <= 1'b0;
        ex_mem_wb_sel     <= 2'b00;
        ex_mem_rd         <= 5'd0;
        ex_mem_alu        <= 32'd0;
        ex_mem_store_data <= 32'd0;
        ex_mem_pc_p4      <= 32'd0;
        ex_mem_funct3     <= 3'd0;
        use_sbus_exmem    <= 1'b0;
      end else begin
        ex_mem_reg_write  <= id_ex_reg_write;
        ex_mem_mem_read   <= id_ex_mem_read;
        ex_mem_mem_write  <= id_ex_mem_write;
        ex_mem_wb_sel     <= id_ex_wb_sel;
        ex_mem_rd         <= id_ex_rd;
        ex_mem_alu        <= ex_alu_res;
        ex_mem_store_data <= store_wdata_ex;
        ex_mem_pc_p4      <= id_ex_pc_p4;
        ex_mem_funct3     <= id_ex_funct3;
        use_sbus_exmem    <= use_sbus_ex;
      end
    end
  end

  // Data phase: byte-lane aligned store data from EX/MEM.
  assign dbus_wdata = ex_mem_store_data;
  assign sbus_wdata = ex_mem_store_data;

  torv_hazard_unit u_hz (
    .id_ex_mem_read(id_ex_mem_read),
    .id_ex_rd(id_ex_rd),
    .if_id_inst(if_id_inst),
    .ex_branch_taken(ex_branch_taken),
    .ibus_ready(ibus_ready),
    .bus_stall(bus_stall),
    .div_busy(md_stall),
    .flush(flush),
    .stall_pc(stall_pc_h),
    .stall_if_id(stall_if_id),
    .bubble_if_id(bubble_if_id),
    .stall_id_ex(stall_id_ex),
    .bubble_id_ex(bubble_id_ex),
    .stall_ex_mem(stall_ex_mem),
    .bubble_ex_mem(bubble_ex_mem),
    .stall_mem_wb(stall_mem_wb)
  );

  function automatic logic [31:0] load_extend(
    input logic [31:0] rdata,
    input logic [1:0]  byte_off,
    input logic [2:0]  funct3
  );
    logic [7:0]  b;
    logic [15:0] h;
    begin
      b = rdata >> (8 * byte_off);
      h = byte_off[1] ? rdata[31:16] : rdata[15:0];
      unique case (funct3)
        3'b000: load_extend = {{24{b[7]}}, b};
        3'b001: load_extend = {{16{h[15]}}, h};
        3'b100: load_extend = {24'd0, b};
        3'b101: load_extend = {16'd0, h};
        default: load_extend = rdata;
      endcase
    end
  endfunction

  logic [31:0] mem_rdata_sel;
  logic [31:0] mem_load_data;
  assign mem_rdata_sel = use_sbus_exmem ? sbus_rdata : dbus_rdata;
  assign mem_load_data = load_extend(mem_rdata_sel, ex_mem_alu[1:0], ex_mem_funct3);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_wb_reg_write <= 1'b0;
      mem_wb_rd        <= 5'd0;
      mem_wb_result    <= 32'd0;
    // MEM always retires unless a bus wait state freezes the pipeline; the load
    // data phase completes in this same cycle.
    end else if (!stall_mem_wb) begin
      mem_wb_reg_write <= ex_mem_reg_write;
      mem_wb_rd        <= ex_mem_rd;
      // Write-back select is resolved in MEM so WB forwarding is a plain
      // register (timing: no wb_sel mux ahead of the EX operand muxes).
      mem_wb_result    <= (ex_mem_wb_sel == 2'b01) ? mem_load_data : ex_mem_fwd_data;
    end
  end

  assign wb_wdata = mem_wb_result;

endmodule
