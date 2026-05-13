// RV32IM 5-stage Harvard core (IBUS/DBUS/SBUS) — spec V3

module rv32im_core (
  input  logic        clk,
  input  logic        rst_n,
  output logic        ibus_valid,
  input  logic        ibus_ready,
  output logic [31:0] ibus_addr,
  input  logic [31:0] ibus_rdata,
  output logic        dbus_valid,
  input  logic        dbus_ready,
  output logic [31:0] dbus_addr,
  output logic        dbus_we,
  output logic [3:0]  dbus_be,
  output logic [31:0] dbus_wdata,
  input  logic [31:0] dbus_rdata,
  output logic        sbus_valid,
  input  logic        sbus_ready,
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
  logic        stall_id_ex;
  logic        stall_ex_mem;
  logic        bubble_ex_mem;
  logic        bubble_id_ex;
  logic        flush;

  logic [31:0] ex_branch_target;
  logic        ex_branch_taken;

  assign pc_next = ex_branch_taken ? ex_branch_target : pc_plus4;

  pc_unit u_pc (
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
    end else if (flush) begin
      if_id_pc    <= 32'd0;
      if_id_inst  <= NOP_INSTR;
      if_id_pc_p4 <= 32'd0;
    end else if (!stall_if_id) begin
      if_id_pc    <= pc;
      if_id_inst  <= ibus_rdata;
      if_id_pc_p4 <= pc_plus4;
    end
  end

  assign ibus_valid = 1'b1;
  assign ibus_addr  = pc;

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

  decoder u_dec (
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
  imm_gen u_imm (
    .inst(if_id_inst),
    .imm_type(d_imm_type),
    .imm(d_imm)
  );

  logic [31:0] rf_rs1;
  logic [31:0] rf_rs2;
  logic        mem_wb_reg_write;
  logic [4:0]  mem_wb_rd;
  logic [31:0] wb_wdata;

  regfile u_rf (
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
    end else if (flush) begin
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

  forwarding_unit u_fwd (
    .ex_mem_regwrite(ex_mem_reg_write),
    .ex_mem_memread(ex_mem_mem_read),
    .ex_mem_rd(ex_mem_rd),
    .mem_wb_regwrite(mem_wb_reg_write),
    .mem_wb_rd(mem_wb_rd),
    .id_ex_rs1(id_ex_rs1_a),
    .id_ex_rs2(id_ex_rs2_a),
    .forward_a(forward_a),
    .forward_b(forward_b)
  );

  logic [31:0] mem_wb_alu;
  logic [31:0] mem_wb_mem;
  logic [1:0]  mem_wb_wb_sel;
  logic [31:0] mem_wb_pc_p4;
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
  alu_control u_aluctl (
    .is_lui(id_ex_is_lui),
    .alu_op(id_ex_alu_op),
    .funct3(id_ex_funct3),
    .funct7_30(id_ex_funct7[5]),
    .alu_ctrl(alu_ctrl)
  );

  logic [31:0] alu_y;
  logic        alu_zero;
  alu u_alu (
    .alu_ctrl(alu_ctrl),
    .a(alu_in_a),
    .b(alu_in_b),
    .y(alu_y),
    .zero(alu_zero)
  );

  logic        md_busy;
  logic        md_ready;
  logic [31:0] md_result;
  muldiv_unit u_md (
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

  logic dbus_valid_w;
  logic sbus_valid_w;
  logic dbus_valid_r;
  logic sbus_valid_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dbus_valid_r <= 1'b0;
      sbus_valid_r <= 1'b0;
    end else begin
      dbus_valid_r <= dbus_valid_w;
      sbus_valid_r <= sbus_valid_w;
    end
  end

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
      end else begin
        ex_mem_reg_write  <= id_ex_reg_write;
        ex_mem_mem_read   <= id_ex_mem_read;
        ex_mem_mem_write  <= id_ex_mem_write;
        ex_mem_wb_sel     <= id_ex_wb_sel;
        ex_mem_rd         <= id_ex_rd;
        ex_mem_alu        <= ex_alu_res;
        ex_mem_store_data <= id_ex_mem_write ? fb_val : 32'd0;
        ex_mem_pc_p4      <= id_ex_pc_p4;
        ex_mem_funct3     <= id_ex_funct3;
      end
    end
  end

  addr_decode u_ad (
    .addr(ex_mem_alu),
    .use_sbus(use_sbus_exmem)
  );

  lsu u_lsu (
    .mem_read(ex_mem_mem_read),
    .mem_write(ex_mem_mem_write),
    .addr(ex_mem_alu),
    .wdata(ex_mem_store_data),
    .funct3(ex_mem_funct3),
    .use_sbus(use_sbus_exmem),
    .dbus_valid(dbus_valid_w),
    .dbus_we(dbus_we),
    .dbus_be(dbus_be),
    .dbus_addr(dbus_addr),
    .dbus_wdata(dbus_wdata),
    .sbus_valid(sbus_valid_w),
    .sbus_we(sbus_we),
    .sbus_be(sbus_be),
    .sbus_addr(sbus_addr),
    .sbus_wdata(sbus_wdata)
  );

  assign dbus_valid = dbus_valid_w;
  assign sbus_valid = sbus_valid_w;

  hazard_unit u_hz (
    .id_ex_mem_read(id_ex_mem_read),
    .id_ex_rd(id_ex_rd),
    .if_id_inst(if_id_inst),
    .ex_mem_mem_write(ex_mem_mem_write),
    .ex_branch_taken(ex_branch_taken),
    .ibus_valid(ibus_valid),
    .ibus_ready(ibus_ready),
    .dbus_valid(dbus_valid_w),
    .dbus_valid_stall(dbus_valid_r),
    .dbus_ready(dbus_ready),
    .sbus_valid(sbus_valid_w),
    .sbus_valid_stall(sbus_valid_r),
    .sbus_ready(sbus_ready),
    .div_busy(md_stall),
    .flush(flush),
    .stall_pc(stall_pc_h),
    .stall_if_id(stall_if_id),
    .stall_id_ex(stall_id_ex),
    .stall_ex_mem(stall_ex_mem),
    .bubble_ex_mem(bubble_ex_mem),
    .bubble_id_ex(bubble_id_ex)
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
      mem_wb_alu       <= 32'd0;
      mem_wb_mem       <= 32'd0;
      mem_wb_wb_sel    <= 2'b00;
      mem_wb_pc_p4     <= 32'd0;
    end else if (!stall_ex_mem) begin
      mem_wb_reg_write <= ex_mem_reg_write;
      mem_wb_rd        <= ex_mem_rd;
      mem_wb_alu       <= ex_mem_alu;
      mem_wb_mem       <= mem_load_data;
      mem_wb_wb_sel    <= ex_mem_wb_sel;
      mem_wb_pc_p4     <= ex_mem_pc_p4;
    end
  end

  always_comb begin
    unique case (mem_wb_wb_sel)
      2'b00: wb_wdata = mem_wb_alu;
      2'b01: wb_wdata = mem_wb_mem;
      2'b10: wb_wdata = mem_wb_pc_p4;
      default: wb_wdata = mem_wb_alu;
    endcase
  end

endmodule
