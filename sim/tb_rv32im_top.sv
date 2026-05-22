// Self-checking simulation top for rv32im_core (VCS-legal single drivers per array)
`timescale 1ns / 1ps
module tb_rv32im_top;
  logic clk;
  logic rst_n;

  logic        ibus_valid;
  logic        ibus_ready;
  logic [31:0] ibus_addr;
  logic [31:0] ibus_rdata;

  logic        dbus_valid;
  logic        dbus_ready;
  logic [31:0] dbus_addr;
  logic        dbus_we;
  logic [3:0]  dbus_be;
  logic [31:0] dbus_wdata;
  logic [31:0] dbus_rdata;

  logic        sbus_valid;
  logic        sbus_ready;
  logic [31:0] sbus_addr;
  logic        sbus_we;
  logic [3:0]  sbus_be;
  logic [31:0] sbus_wdata;
  logic [31:0] sbus_rdata;

  rv32im_core dut (
    .clk(clk),
    .rst_n(rst_n),
    .ibus_valid(ibus_valid),
    .ibus_ready(ibus_ready),
    .ibus_addr(ibus_addr),
    .ibus_rdata(ibus_rdata),
    .dbus_valid(dbus_valid),
    .dbus_ready(dbus_ready),
    .dbus_addr(dbus_addr),
    .dbus_we(dbus_we),
    .dbus_be(dbus_be),
    .dbus_wdata(dbus_wdata),
    .dbus_rdata(dbus_rdata),
    .sbus_valid(sbus_valid),
    .sbus_ready(sbus_ready),
    .sbus_addr(sbus_addr),
    .sbus_we(sbus_we),
    .sbus_be(sbus_be),
    .sbus_wdata(sbus_wdata),
    .sbus_rdata(sbus_rdata)
  );

  localparam int IMEM_BYTES = 65536;
  localparam int DMEM_BYTES = 65536;
  localparam int SMEM_BYTES = 4096;
  localparam logic [31:0] TOHOST_ADDR = 32'hF000_0000;

  logic [7:0] imem[IMEM_BYTES];
  logic [7:0] dmem[DMEM_BYTES];
  logic [7:0] smem[SMEM_BYTES];

  // Lightweight performance counters for asm cases.  instr_count uses the
  // non-bubbled IF/ID to ID/EX transfer as the in-order retired approximation.
  int cycle_count;
  int instr_count;
  int alu_count;
  int branch_count;
  int branch_taken_count;
  int jump_count;
  int load_count;
  int store_count;
  int muldiv_count;
  int lui_auipc_count;
  int stall_if_count;
  int stall_id_count;
  int stall_ex_count;
  int flush_count;
  int dbus_read_count;
  int dbus_write_count;
  int sbus_read_count;
  int sbus_write_count;

  wire [15:0] i_idx = ibus_addr[15:0];
  wire [15:0] d_idx = dbus_addr[15:0];
  wire [11:0] s_idx = sbus_addr[11:0];

  always_comb begin
    ibus_rdata = {imem[i_idx + 3], imem[i_idx + 2], imem[i_idx + 1], imem[i_idx]};
    dbus_rdata = {dmem[{dbus_addr[15:2], 2'b00} + 3],
                  dmem[{dbus_addr[15:2], 2'b00} + 2],
                  dmem[{dbus_addr[15:2], 2'b00} + 1],
                  dmem[{dbus_addr[15:2], 2'b00}]};
    sbus_rdata = {smem[{sbus_addr[11:2], 2'b00} + 3],
                  smem[{sbus_addr[11:2], 2'b00} + 2],
                  smem[{sbus_addr[11:2], 2'b00} + 1],
                  smem[{sbus_addr[11:2], 2'b00}]};
  end

  // Optional bus back-pressure for directed hazard tests (see tests/core/asm/*.plusargs).
  // +stall_sbus_writes=N      — stretch first SBUS store (hazard_branch_mem_stall)
  // +stall_ibus_during_mem_write=N — IBUS wait during store in MEM (hazard_ibus_store_dup)
  int stall_sbus_len;
  int stall_ibus_len;
  logic [7:0] sbus_stall_cnt;
  logic [7:0] ibus_stall_cnt;
  logic       ibus_stall_armed;
  logic       sbus_stall_done;

  initial begin
    stall_sbus_len = 0;
    stall_ibus_len = 0;
    void'($value$plusargs("stall_sbus_writes=%d", stall_sbus_len));
    void'($value$plusargs("stall_ibus_during_mem_write=%d", stall_ibus_len));
  end

  wire sbus_stall_req =
      (stall_sbus_len > 0) && sbus_valid && sbus_we && (sbus_addr != TOHOST_ADDR);
  wire mem_store_active =
      dut.ex_mem_mem_write && (sbus_valid || dbus_valid);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sbus_stall_cnt   <= 8'd0;
      ibus_stall_cnt   <= 8'd0;
      ibus_stall_armed <= 1'b0;
      sbus_stall_done  <= 1'b0;
    end else begin
      if (stall_sbus_len > 0) begin
        if (!sbus_stall_done && sbus_stall_req) begin
          sbus_stall_cnt  <= stall_sbus_len[7:0];
          sbus_stall_done <= 1'b1;
        end else if (sbus_stall_cnt != 8'd0)
          sbus_stall_cnt <= sbus_stall_cnt - 8'd1;
      end

      if (stall_ibus_len > 0) begin
        if (!ibus_stall_armed && mem_store_active)
          ibus_stall_armed <= 1'b1;
        if (ibus_stall_armed) begin
          if (ibus_stall_cnt == 8'd0)
            ibus_stall_cnt <= stall_ibus_len[7:0];
          else
            ibus_stall_cnt <= ibus_stall_cnt - 8'd1;
          if (ibus_stall_cnt == 8'd1)
            ibus_stall_armed <= 1'b0;
        end
      end
    end
  end

  // Deassert ready on the first beat (not only after the counter register updates).
  assign ibus_ready = (ibus_stall_cnt == 8'd0) &&
                      !(stall_ibus_len > 0 && ibus_stall_armed && ibus_stall_cnt == 8'd0);
  assign dbus_ready = 1'b1;
  assign sbus_ready = (sbus_stall_cnt == 8'd0) &&
                      !(stall_sbus_len > 0 && sbus_stall_req && !sbus_stall_done);

  // Printed just before tohost PASS so the case log is self-contained.
  task automatic print_perf;
    real ipc;
    begin
      ipc = (cycle_count == 0) ? 0.0 : (instr_count * 1.0) / cycle_count;
      $display("[PERF] cycles=%0d instr=%0d ipc=%0.3f", cycle_count, instr_count, ipc);
      $display("[PERF] type alu=%0d load=%0d store=%0d branch=%0d branch_taken=%0d jump=%0d muldiv=%0d lui_auipc=%0d",
               alu_count, load_count, store_count, branch_count, branch_taken_count,
               jump_count, muldiv_count, lui_auipc_count);
      $display("[PERF] stall if=%0d id=%0d ex=%0d flush=%0d dbus_r=%0d dbus_w=%0d sbus_r=%0d sbus_w=%0d",
               stall_if_count, stall_id_count, stall_ex_count, flush_count,
               dbus_read_count, dbus_write_count, sbus_read_count, sbus_write_count);
    end
  endtask

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      cycle_count       <= 0;
      instr_count       <= 0;
      alu_count         <= 0;
      branch_count      <= 0;
      branch_taken_count <= 0;
      jump_count        <= 0;
      load_count        <= 0;
      store_count       <= 0;
      muldiv_count      <= 0;
      lui_auipc_count   <= 0;
      stall_if_count    <= 0;
      stall_id_count    <= 0;
      stall_ex_count    <= 0;
      flush_count       <= 0;
      dbus_read_count   <= 0;
      dbus_write_count  <= 0;
      sbus_read_count   <= 0;
      sbus_write_count  <= 0;
    end else begin
      cycle_count <= cycle_count + 1;

      if (dut.stall_if_id)  stall_if_count <= stall_if_count + 1;
      if (dut.stall_id_ex)  stall_id_count <= stall_id_count + 1;
      if (dut.stall_ex_mem) stall_ex_count <= stall_ex_count + 1;
      if (dut.flush)        flush_count    <= flush_count + 1;

      if (dbus_valid && dbus_ready) begin
        if (dbus_we) dbus_write_count <= dbus_write_count + 1;
        else         dbus_read_count  <= dbus_read_count + 1;
      end
      if (sbus_valid && sbus_ready) begin
        if (sbus_we) sbus_write_count <= sbus_write_count + 1;
        else         sbus_read_count  <= sbus_read_count + 1;
      end

      // Do not count flushed, stalled, bubbled, or canonical NOP instructions.
      if (!dut.flush && !dut.stall_id_ex && !dut.bubble_id_ex &&
          (dut.if_id_inst != 32'h0000_0013)) begin
        instr_count <= instr_count + 1;
        unique case (dut.if_id_inst[6:0])
          7'b0110011: begin
            if (dut.if_id_inst[31:25] == 7'b0000001) muldiv_count <= muldiv_count + 1;
            else                                      alu_count    <= alu_count + 1;
          end
          7'b0010011: alu_count       <= alu_count + 1;
          7'b0000011: load_count      <= load_count + 1;
          7'b0100011: store_count     <= store_count + 1;
          7'b1100011: branch_count    <= branch_count + 1;
          7'b1101111,
          7'b1100111: jump_count      <= jump_count + 1;
          7'b0110111,
          7'b0010111: lui_auipc_count <= lui_auipc_count + 1;
          default:    alu_count       <= alu_count + 1;
        endcase
      end
      if (dut.ex_branch_taken)
        branch_taken_count <= branch_taken_count + 1;
    end
  end

  always @(posedge clk) begin
    if (rst_n) begin
      if (dbus_valid && dbus_ready && dbus_we) begin
        if (dbus_be[0]) dmem[{dbus_addr[15:2], 2'b00} + 0] <= dbus_wdata[7:0];
        if (dbus_be[1]) dmem[{dbus_addr[15:2], 2'b00} + 1] <= dbus_wdata[15:8];
        if (dbus_be[2]) dmem[{dbus_addr[15:2], 2'b00} + 2] <= dbus_wdata[23:16];
        if (dbus_be[3]) dmem[{dbus_addr[15:2], 2'b00} + 3] <= dbus_wdata[31:24];
      end
      if (sbus_valid && sbus_ready && sbus_we) begin
        if (sbus_addr == TOHOST_ADDR) begin
          if (sbus_wdata[7:0] == 8'h01) begin
            print_perf();
            $display("[PASS] tohost signalled success");
            $finish(0);
          end else begin
            $error("[FAIL] tohost signalled 0x%02h", sbus_wdata[7:0]);
            $finish(1);
          end
        end
        if (sbus_be[0]) smem[{sbus_addr[11:2], 2'b00} + 0] <= sbus_wdata[7:0];
        if (sbus_be[1]) smem[{sbus_addr[11:2], 2'b00} + 1] <= sbus_wdata[15:8];
        if (sbus_be[2]) smem[{sbus_addr[11:2], 2'b00} + 2] <= sbus_wdata[23:16];
        if (sbus_be[3]) smem[{sbus_addr[11:2], 2'b00} + 3] <= sbus_wdata[31:24];
      end
    end
  end

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  function automatic logic [31:0] gpr(input int r);
    if (r == 0)
      return 32'd0;
    return dut.u_rf.mem[r];
  endfunction

  task automatic wait_gpr(input int r, input logic [31:0] val, input int max_cycles);
    int c;
    c = 0;
    while (gpr(r) !== val && c < max_cycles) begin
      @(posedge clk);
      c++;
    end
    if (gpr(r) !== val) begin
      $error("TIMEOUT waiting x%0d == %0h (last %0h)", r, val, gpr(r));
      $finish(1);
    end
  endtask

  task automatic put_inst(input int word_idx, input logic [31:0] inst);
    int addr;
    begin
      addr = word_idx * 4;
      imem[addr + 0] = inst[7:0];
      imem[addr + 1] = inst[15:8];
      imem[addr + 2] = inst[23:16];
      imem[addr + 3] = inst[31:24];
    end
  endtask

  task automatic apply_reset;
    begin
      rst_n = 0;
      repeat (4) @(posedge clk);
      rst_n = 1;
    end
  endtask

  task automatic clear_data_mem;
    int i;
    begin
      for (i = 0; i < DMEM_BYTES; i++) dmem[i] = 8'd0;
      for (i = 0; i < SMEM_BYTES; i++) smem[i] = 8'd0;
    end
  endtask

  initial begin
    if ($test$plusargs("vcd")) begin
      string vcd_path;
      if (!$value$plusargs("vcdfile=%s", vcd_path))
        vcd_path = "tb_rv32im_top.vcd";
      $dumpfile(vcd_path);
      $dumpvars(0, tb_rv32im_top);
    end
`ifdef RV32M_FSDB
    if ($test$plusargs("fsdb")) begin
      string fsdb_path;
      if (!$value$plusargs("fsdbfile=%s", fsdb_path))
        fsdb_path = "tb_rv32im_top.fsdb";
      $fsdbDumpfile(fsdb_path);
      $fsdbDumpvars(0, tb_rv32im_top);
    end
`endif
  end

  // Optional PC trace file for offline debuggers (no VCD parsing): +pc_trace [+pc_trace_file=...] [+pc_trace_each_cycle]
  int           pc_trace_fd;
  logic         pc_trace_en;
  string        pc_trace_path;
  bit           pc_trace_each;
  logic [31:0]  pc_trace_prev;
  bit           pc_trace_warmed;

  initial begin
    pc_trace_fd   = 0;
    pc_trace_en   = 1'b0;
    pc_trace_each = 1'b0;
    if ($test$plusargs("pc_trace")) begin
      if (!$value$plusargs("pc_trace_file=%s", pc_trace_path))
        pc_trace_path = "pc_trace.tsv";
      pc_trace_fd = $fopen(pc_trace_path, "w");
      if (pc_trace_fd == 0) begin
        $warning("pc_trace: could not open %s", pc_trace_path);
      end else begin
        pc_trace_en = 1'b1;
        if ($test$plusargs("pc_trace_each_cycle"))
          pc_trace_each = 1'b1;
        $fwrite(pc_trace_fd,
                "time_ps\tpc_hex\tibus_inst_hex\tif_id_pc_hex\tif_id_inst_hex\n");
      end
    end
  end

  final begin
    if (pc_trace_fd != 0)
      $fclose(pc_trace_fd);
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc_trace_warmed <= 1'b0;
      pc_trace_prev   <= '0;
    end else if (pc_trace_en && pc_trace_fd != 0) begin
      begin
        bit log_it;
        log_it = pc_trace_each || !pc_trace_warmed || (dut.pc !== pc_trace_prev);
        if (log_it) begin
          $fwrite(pc_trace_fd, "%0t\t%h\t%h\t%h\t%h\n", $time, dut.pc, ibus_rdata,
                  dut.if_id_pc, dut.if_id_inst);
          pc_trace_warmed <= 1'b1;
        end
      end
      pc_trace_prev <= dut.pc;
    end
  end

  always @(posedge clk) begin
    if (rst_n && $test$plusargs("trace")) begin
      $display("T=%0t pc=%08x inst=%08x dbus v=%0b we=%0b a=%08x wd=%08x be=%b sbus v=%0b we=%0b a=%08x wd=%08x be=%b",
               $time, dut.pc, ibus_rdata, dbus_valid, dbus_we, dbus_addr,
               dbus_wdata, dbus_be, sbus_valid, sbus_we, sbus_addr,
               sbus_wdata, sbus_be);
    end
  end

  initial begin : stim
    int k;
    string imem_hex;
    string dmem_hex;
    int max_cycles;

    for (k = 0; k < IMEM_BYTES; k++) imem[k] = 8'h13;
    for (k = 1; k < IMEM_BYTES; k += 4) imem[k] = 8'h00;
    for (k = 2; k < IMEM_BYTES; k += 4) imem[k] = 8'h00;
    for (k = 3; k < IMEM_BYTES; k += 4) imem[k] = 8'h00;
    clear_data_mem();

    if ($value$plusargs("imem=%s", imem_hex)) begin
      max_cycles = 20000;
      void'($value$plusargs("max_cycles=%d", max_cycles));
      $readmemh(imem_hex, imem);

      if ($value$plusargs("dmem=%s", dmem_hex))
        $readmemh(dmem_hex, dmem);
      apply_reset();
      repeat (max_cycles) @(posedge clk);
      $error("TIMEOUT waiting for tohost after %0d cycles", max_cycles);
      $finish(1);
    end

    // --- Test 1: ADDI + dependency ---
    put_inst(0, 32'h0050_0093);  // ADDI x1, x0, 5
    put_inst(1, 32'h0030_8113);  // ADDI x2, x1, 3  -> 8
    put_inst(2, 32'h0000_0013);
    put_inst(3, 32'h0000_0013);

    apply_reset();

    wait_gpr(1, 32'd5, 300);
    wait_gpr(2, 32'd8, 300);
    $display("[PASS] test1 ADDI chain: x1=5 x2=8");

    // --- Test 2: RV32M MUL ---
    put_inst(0, 32'h0030_0193);  // ADDI x3, x0, 3
    put_inst(1, 32'h0040_0213);  // ADDI x4, x0, 4
    put_inst(2, 32'h024182b3);  // MUL x5, x3, x4  -> 12
    for (k = 3; k < 32; k++) put_inst(k, 32'h0000_0013);

    apply_reset();

    wait_gpr(5, 32'd12, 400);
    $display("[PASS] test2 MUL: x5=12");

    $display("All tb_rv32im_top checks passed.");
    $finish(0);
  end

endmodule
