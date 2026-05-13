`timescale 1ns / 1ps
module tb_rv32im_ahb_top;
  logic hclk;
  logic hresetn;

  logic [31:0] i_haddr;
  logic [1:0]  i_htrans;
  logic        i_hwrite;
  logic [2:0]  i_hsize;
  logic [2:0]  i_hburst;
  logic [3:0]  i_hprot;
  logic [31:0] i_hwdata;
  logic [31:0] i_hrdata;
  logic        i_hready;
  logic        i_hresp;

  logic [31:0] d_haddr;
  logic [1:0]  d_htrans;
  logic        d_hwrite;
  logic [2:0]  d_hsize;
  logic [2:0]  d_hburst;
  logic [3:0]  d_hprot;
  logic [31:0] d_hwdata;
  logic [31:0] d_hrdata;
  logic        d_hready;
  logic        d_hresp;

  logic [31:0] s_haddr;
  logic [1:0]  s_htrans;
  logic        s_hwrite;
  logic [2:0]  s_hsize;
  logic [2:0]  s_hburst;
  logic [3:0]  s_hprot;
  logic [31:0] s_hwdata;
  logic [31:0] s_hrdata;
  logic        s_hready;
  logic        s_hresp;

  rv32im_ahb_top dut (
    .hclk(hclk),
    .hresetn(hresetn),
    .i_haddr(i_haddr),
    .i_htrans(i_htrans),
    .i_hwrite(i_hwrite),
    .i_hsize(i_hsize),
    .i_hburst(i_hburst),
    .i_hprot(i_hprot),
    .i_hwdata(i_hwdata),
    .i_hrdata(i_hrdata),
    .i_hready(i_hready),
    .i_hresp(i_hresp),
    .d_haddr(d_haddr),
    .d_htrans(d_htrans),
    .d_hwrite(d_hwrite),
    .d_hsize(d_hsize),
    .d_hburst(d_hburst),
    .d_hprot(d_hprot),
    .d_hwdata(d_hwdata),
    .d_hrdata(d_hrdata),
    .d_hready(d_hready),
    .d_hresp(d_hresp),
    .s_haddr(s_haddr),
    .s_htrans(s_htrans),
    .s_hwrite(s_hwrite),
    .s_hsize(s_hsize),
    .s_hburst(s_hburst),
    .s_hprot(s_hprot),
    .s_hwdata(s_hwdata),
    .s_hrdata(s_hrdata),
    .s_hready(s_hready),
    .s_hresp(s_hresp)
  );

  ahb_sram_model #(.BYTES(65536)) u_i_sram (
    .hclk(hclk),
    .hresetn(hresetn),
    .haddr(i_haddr),
    .htrans(i_htrans),
    .hwrite(i_hwrite),
    .hsize(i_hsize),
    .hwdata(i_hwdata),
    .hrdata(i_hrdata),
    .hready(i_hready),
    .hresp(i_hresp)
  );

  ahb_sram_model #(.BYTES(65536)) u_d_sram (
    .hclk(hclk),
    .hresetn(hresetn),
    .haddr(d_haddr),
    .htrans(d_htrans),
    .hwrite(d_hwrite),
    .hsize(d_hsize),
    .hwdata(d_hwdata),
    .hrdata(d_hrdata),
    .hready(d_hready),
    .hresp(d_hresp)
  );

  ahb_sram_model #(
    .BYTES(65536),
    .TOHOST_ENABLE(1'b0),
    .TOHOST_ADDR(32'hF000_0000)
  ) u_s_sram (
    .hclk(hclk),
    .hresetn(hresetn),
    .haddr(s_haddr),
    .htrans(s_htrans),
    .hwrite(s_hwrite),
    .hsize(s_hsize),
    .hwdata(s_hwdata),
    .hrdata(s_hrdata),
    .hready(s_hready),
    .hresp(s_hresp)
  );

  localparam logic [1:0] HTRANS_IDLE = 2'b00;
  localparam logic [31:0] TOHOST_ADDR = 32'hF000_0000;

  // Lightweight performance counters for AHB runs.  instr_count uses the
  // core's non-bubbled IF/ID to ID/EX transfer as the retired approximation.
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

  logic        s_data_valid_q;
  logic        s_write_q;
  logic [31:0] s_addr_q;

  // Printed on the tohost beat so AHB case logs match core case logs.
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

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      cycle_count        <= 0;
      instr_count        <= 0;
      alu_count          <= 0;
      branch_count       <= 0;
      branch_taken_count <= 0;
      jump_count         <= 0;
      load_count         <= 0;
      store_count        <= 0;
      muldiv_count       <= 0;
      lui_auipc_count    <= 0;
      stall_if_count     <= 0;
      stall_id_count     <= 0;
      stall_ex_count     <= 0;
      flush_count        <= 0;
      dbus_read_count    <= 0;
      dbus_write_count   <= 0;
      sbus_read_count    <= 0;
      sbus_write_count   <= 0;
      s_data_valid_q     <= 1'b0;
      s_write_q          <= 1'b0;
      s_addr_q           <= 32'd0;
    end else begin
      cycle_count <= cycle_count + 1;

      s_data_valid_q <= (s_htrans != HTRANS_IDLE);
      if (s_htrans != HTRANS_IDLE) begin
        s_write_q <= s_hwrite;
        s_addr_q  <= s_haddr;
      end

      if (dut.u_core.stall_if_id)  stall_if_count <= stall_if_count + 1;
      if (dut.u_core.stall_id_ex)  stall_id_count <= stall_id_count + 1;
      if (dut.u_core.stall_ex_mem) stall_ex_count <= stall_ex_count + 1;
      if (dut.u_core.flush)        flush_count    <= flush_count + 1;

      if (d_htrans != HTRANS_IDLE) begin
        if (d_hwrite) dbus_write_count <= dbus_write_count + 1;
        else          dbus_read_count  <= dbus_read_count + 1;
      end
      if (s_htrans != HTRANS_IDLE) begin
        if (s_hwrite) sbus_write_count <= sbus_write_count + 1;
        else          sbus_read_count  <= sbus_read_count + 1;
      end

      // Do not count flushed, stalled, bubbled, or canonical NOP instructions.
      if (!dut.u_core.flush && !dut.u_core.stall_id_ex && !dut.u_core.bubble_id_ex &&
          (dut.u_core.if_id_inst != 32'h0000_0013)) begin
        instr_count <= instr_count + 1;
        unique case (dut.u_core.if_id_inst[6:0])
          7'b0110011: begin
            if (dut.u_core.if_id_inst[31:25] == 7'b0000001) muldiv_count <= muldiv_count + 1;
            else                                             alu_count    <= alu_count + 1;
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
      if (dut.u_core.ex_branch_taken)
        branch_taken_count <= branch_taken_count + 1;

      if (s_data_valid_q && s_write_q && (s_addr_q == TOHOST_ADDR)) begin
        if (s_hwdata[7:0] == 8'h01) begin
          print_perf();
          $display("[PASS] AHB tohost signalled success");
          $finish(0);
        end else begin
          $error("[FAIL] AHB tohost signalled 0x%02h", s_hwdata[7:0]);
          $finish(1);
        end
      end
    end
  end

  initial begin
    hclk = 1'b0;
    forever #5 hclk = ~hclk;
  end

  task automatic clear_memories;
    int i;
    begin
      for (i = 0; i < 65536; i++) begin
        u_i_sram.mem[i] = 8'h13;
        u_d_sram.mem[i] = 8'd0;
        u_s_sram.mem[i] = 8'd0;
      end
      for (i = 1; i < 65536; i += 4) u_i_sram.mem[i] = 8'h00;
      for (i = 2; i < 65536; i += 4) u_i_sram.mem[i] = 8'h00;
      for (i = 3; i < 65536; i += 4) u_i_sram.mem[i] = 8'h00;
    end
  endtask

  initial begin
    string imem_hex;
    string dmem_hex;
    int max_cycles;

    clear_memories();
    if (!$value$plusargs("imem=%s", imem_hex)) begin
      $error("AHB TB requires +imem=<objcopy -O verilog hex>");
      $finish(1);
    end

    max_cycles = 20000;
    void'($value$plusargs("max_cycles=%d", max_cycles));
    $readmemh(imem_hex, u_i_sram.mem);
    if ($value$plusargs("dmem=%s", dmem_hex))
      $readmemh(dmem_hex, u_d_sram.mem);

    hresetn = 1'b0;
    repeat (6) @(posedge hclk);
    hresetn = 1'b1;

    repeat (max_cycles) @(posedge hclk);
    $error("TIMEOUT waiting for AHB tohost after %0d cycles", max_cycles);
    $finish(1);
  end

  initial begin
    if ($test$plusargs("vcd")) begin
      string vcd_path;
      if (!$value$plusargs("vcdfile=%s", vcd_path))
        vcd_path = "tb_rv32im_ahb_top.vcd";
      $dumpfile(vcd_path);
      $dumpvars(0, tb_rv32im_ahb_top);
    end
`ifdef RV32M_FSDB
    if ($test$plusargs("fsdb")) begin
      string fsdb_path;
      if (!$value$plusargs("fsdbfile=%s", fsdb_path))
        fsdb_path = "tb_rv32im_ahb_top.fsdb";
      $fsdbDumpfile(fsdb_path);
      $fsdbDumpvars(0, tb_rv32im_ahb_top);
    end
`endif
  end

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

  always_ff @(posedge hclk) begin
    if (!hresetn) begin
      pc_trace_warmed <= 1'b0;
      pc_trace_prev   <= '0;
    end else if (pc_trace_en && pc_trace_fd != 0) begin
      begin
        bit log_it;
        log_it = pc_trace_each || !pc_trace_warmed ||
            (dut.u_core.pc !== pc_trace_prev);
        if (log_it) begin
          $fwrite(pc_trace_fd, "%0t\t%h\t%h\t%h\t%h\n", $time, dut.u_core.pc,
                  i_hrdata, dut.u_core.if_id_pc, dut.u_core.if_id_inst);
          pc_trace_warmed <= 1'b1;
        end
      end
      pc_trace_prev <= dut.u_core.pc;
    end
  end

  always @(posedge hclk) begin
    if (hresetn && $test$plusargs("trace")) begin
      $display("T=%0t pc=%08x ifid_pc=%08x ifid_inst=%08x x1=%08x I[%b %08x rd=%08x] D[%b we=%0b sz=%0d a=%08x wd=%08x] S[%b we=%0b sz=%0d a=%08x wd=%08x]",
               $time, dut.u_core.pc, dut.u_core.if_id_pc, dut.u_core.if_id_inst,
               dut.u_core.u_rf.mem[1], i_htrans, i_haddr, i_hrdata,
               d_htrans, d_hwrite, d_hsize, d_haddr, d_hwdata,
               s_htrans, s_hwrite, s_hsize, s_haddr, s_hwdata);
    end
  end

endmodule
