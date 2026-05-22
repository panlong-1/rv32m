`timescale 1ns / 1ps
// TORV SoC — unified simulation testbench (clock/reset, imem load, directed stalls, tohost).
module tb_torv_soc;
  logic hclk;
  logic hresetn;

  logic        ibus_stall_hold;
  logic        sbus_stall_hold;
  logic        uart_tx;
  logic [7:0]  uart_thr_push_count;
  logic [4:0]  uart_tx_fifo_depth_max;
  logic [7:0]  uart_rbr_read_count;

  torv_soc_top dut (
    .hclk(hclk),
    .hresetn(hresetn),
    .ibus_stall_hold(ibus_stall_hold),
    .sbus_stall_hold(sbus_stall_hold),
    .uart_tx(uart_tx),
    .uart_thr_push_count(uart_thr_push_count),
    .uart_tx_fifo_depth_max(uart_tx_fifo_depth_max),
    .uart_rbr_read_count(uart_rbr_read_count)
  );

  localparam logic [1:0] HTRANS_IDLE = 2'b00;
  localparam logic [31:0] TOHOST_ADDR = 32'hF000_0000;
  localparam logic [31:0] UART_APB_BASE = 32'h4000_1000;

  wire s_periph_sel =
      (dut.s_haddr >= UART_APB_BASE) && (dut.s_haddr < (UART_APB_BASE + 32'h1000));

  // +stall_ibus_during_mem_write=N
  int stall_ibus_len;
  logic [7:0] ibus_stall_cnt;
  logic       ibus_stall_armed;
  logic       ibus_stall_done;
  wire        mem_bus_active =
      (dut.u_cpu.u_core.ex_mem_mem_write || dut.u_cpu.u_core.ex_mem_mem_read) &&
      (dut.u_cpu.u_core.sbus_valid || dut.u_cpu.u_core.dbus_valid);

  // +stall_sbus_writes=N (SBUS SRAM path only, not APB UART)
  int stall_sbus_len;
  logic [7:0] sbus_stall_cnt;
  logic       sbus_stall_armed;
  logic       sbus_stall_done;
  wire        sbus_stall_req =
      (stall_sbus_len > 0) && (dut.s_htrans != HTRANS_IDLE) && dut.s_hwrite &&
      !s_periph_sel && (dut.s_haddr != TOHOST_ADDR);

  initial begin
    stall_ibus_len = 0;
    stall_sbus_len = 0;
    void'($value$plusargs("stall_ibus_during_mem_write=%d", stall_ibus_len));
    void'($value$plusargs("stall_sbus_writes=%d", stall_sbus_len));
  end

  // Bus stall injection — same semantics as sim/tb_rv32im_top.sv (Harvard TB).
  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      sbus_stall_cnt  <= 8'd0;
      ibus_stall_cnt  <= 8'd0;
      ibus_stall_armed <= 1'b0;
      ibus_stall_done <= 1'b0;
      sbus_stall_done <= 1'b0;
    end else begin
      if (stall_sbus_len > 0) begin
        if (!sbus_stall_done && sbus_stall_req) begin
          sbus_stall_cnt  <= stall_sbus_len[7:0];
          sbus_stall_done <= 1'b1;
        end else if (sbus_stall_cnt != 8'd0)
          sbus_stall_cnt <= sbus_stall_cnt - 8'd1;
      end

      if (stall_ibus_len > 0) begin
        if (!ibus_stall_done && mem_bus_active) begin
          ibus_stall_armed <= 1'b1;
          ibus_stall_done  <= 1'b1;
        end
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

  assign ibus_stall_hold =
      (ibus_stall_cnt != 8'd0) ||
      (stall_ibus_len > 0 && ibus_stall_armed && ibus_stall_cnt == 8'd0);

  assign sbus_stall_hold =
      (sbus_stall_cnt != 8'd0) ||
      (stall_sbus_len > 0 && sbus_stall_req && !sbus_stall_done);

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
  int periph_tx_count;
  int replay_expect;
  int replay_expect_rbr;
  wire [7:0] periph_tx_count_hw = uart_thr_push_count;
  wire [7:0] periph_rbr_count_hw = uart_rbr_read_count;

  logic        s_data_valid_q;
  logic        s_write_q;
  logic [31:0] s_addr_q;

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
      periph_tx_count    <= 0;
      s_data_valid_q     <= 1'b0;
      s_write_q          <= 1'b0;
      s_addr_q           <= 32'd0;
    end else begin
      cycle_count <= cycle_count + 1;

      s_data_valid_q <= (dut.s_htrans != HTRANS_IDLE);
      if (dut.s_htrans != HTRANS_IDLE) begin
        s_write_q <= dut.s_hwrite;
        s_addr_q  <= dut.s_haddr;
      end

      if (dut.u_cpu.u_core.stall_if_id)  stall_if_count <= stall_if_count + 1;
      if (dut.u_cpu.u_core.stall_id_ex)  stall_id_count <= stall_id_count + 1;
      if (dut.u_cpu.u_core.stall_ex_mem) stall_ex_count <= stall_ex_count + 1;
      if (dut.u_cpu.u_core.flush)        flush_count    <= flush_count + 1;

      if (dut.d_htrans != HTRANS_IDLE) begin
        if (dut.d_hwrite) dbus_write_count <= dbus_write_count + 1;
        else              dbus_read_count  <= dbus_read_count + 1;
      end
      if (dut.s_htrans != HTRANS_IDLE) begin
        if (dut.s_hwrite) begin
          sbus_write_count <= sbus_write_count + 1;
          if (s_periph_sel)
            periph_tx_count <= periph_tx_count + 1;
        end else
          sbus_read_count <= sbus_read_count + 1;
      end

      if (!dut.u_cpu.u_core.flush && !dut.u_cpu.u_core.stall_id_ex &&
          !dut.u_cpu.u_core.bubble_id_ex &&
          (dut.u_cpu.u_core.if_id_inst != 32'h0000_0013)) begin
        instr_count <= instr_count + 1;
        unique case (dut.u_cpu.u_core.if_id_inst[6:0])
          7'b0110011: begin
            if (dut.u_cpu.u_core.if_id_inst[31:25] == 7'b0000001)
              muldiv_count <= muldiv_count + 1;
            else
              alu_count <= alu_count + 1;
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
      if (dut.u_cpu.u_core.ex_branch_taken)
        branch_taken_count <= branch_taken_count + 1;

      if (s_data_valid_q && s_write_q && (s_addr_q == TOHOST_ADDR)) begin
        if (dut.s_hwdata[7:0] == 8'h01) begin
          print_perf();
          if (replay_expect > 0 && periph_tx_count_hw != replay_expect) begin
            $error("[FAIL] TORV periph TX count %0d != expected %0d",
                   periph_tx_count_hw, replay_expect);
            $finish(1);
          end
          if (replay_expect_rbr > 0 && periph_rbr_count_hw != replay_expect_rbr) begin
            $error("[FAIL] TORV UART RBR read count %0d != expected %0d",
                   periph_rbr_count_hw, replay_expect_rbr);
            $finish(1);
          end
          $display("[PASS] TORV tohost signalled success (periph_tx=%0d rbr=%0d)",
                   periph_tx_count_hw, periph_rbr_count_hw);
          $finish(0);
        end else begin
          $display("[PERF] periph_tx_hw=%0d (replay_expect %0d)",
                   periph_tx_count_hw, replay_expect);
          $error("[FAIL] TORV tohost signalled 0x%02h", dut.s_hwdata[7:0]);
          $finish(1);
        end
      end
    end
  end

  initial begin
    hclk = 1'b0;
    forever #5 hclk = ~hclk;
  end

  // Sim-only: push one byte into the PULP UART RX FIFO (no serial bit-bang).
  task automatic uart_inject_rx_byte(input [7:0] byte_val);
    begin
      @(posedge hclk);
      force dut.u_apb_uart.uart_rx_fifo_i.valid_i = 1'b1;
      force dut.u_apb_uart.uart_rx_fifo_i.data_i  = {1'b0, byte_val};
      @(posedge hclk);
      while (!dut.u_apb_uart.uart_rx_fifo_i.ready_o)
        @(posedge hclk);
      @(posedge hclk);
      release dut.u_apb_uart.uart_rx_fifo_i.valid_i;
      release dut.u_apb_uart.uart_rx_fifo_i.data_i;
    end
  endtask

  task automatic clear_memories;
    int i;
    begin
      for (i = 0; i < 65536; i++) begin
        dut.u_i_sram.mem[i] = 8'h13;
        dut.u_d_sram.mem[i] = 8'd0;
        dut.u_s_sram.mem[i] = 8'd0;
      end
      for (i = 1; i < 65536; i += 4) dut.u_i_sram.mem[i] = 8'h00;
      for (i = 2; i < 65536; i += 4) dut.u_i_sram.mem[i] = 8'h00;
      for (i = 3; i < 65536; i += 4) dut.u_i_sram.mem[i] = 8'h00;
    end
  endtask

  initial begin
    string imem_hex;
    string dmem_hex;
    int max_cycles;

    clear_memories();
    if (!$value$plusargs("imem=%s", imem_hex)) begin
      $error("TORV TB requires +imem=<verilog hex>");
      $finish(1);
    end

    max_cycles = 20000;
    replay_expect = 0;
    replay_expect_rbr = 0;
    void'($value$plusargs("max_cycles=%d", max_cycles));
    void'($value$plusargs("replay_expect=%d", replay_expect));
    void'($value$plusargs("replay_expect_rbr=%d", replay_expect_rbr));
    $readmemh(imem_hex, dut.u_i_sram.mem);
    if ($value$plusargs("dmem=%s", dmem_hex))
      $readmemh(dmem_hex, dut.u_d_sram.mem);

    hresetn = 1'b0;
    repeat (6) @(posedge hclk);
    hresetn = 1'b1;

    begin
      int uart_rx_byte;
      if ($value$plusargs("uart_rx_byte=%h", uart_rx_byte))
        uart_inject_rx_byte(uart_rx_byte[7:0]);
    end

    repeat (max_cycles) @(posedge hclk);
    if (replay_expect > 0) begin
      print_perf();
      $display("[PERF] periph_thr_push=%0d fifo_max=%0d (replay_expect %0d)",
               periph_tx_count_hw, uart_tx_fifo_depth_max, replay_expect);
      if (periph_tx_count_hw > replay_expect) begin
        $error("[FAIL] TORV memory replay: periph_tx=%0d (expected %0d)",
               periph_tx_count_hw, replay_expect);
        $finish(1);
      end else if (periph_tx_count_hw == replay_expect) begin
        $display("[PASS] TORV replay check OK (periph_tx=%0d)", periph_tx_count_hw);
        $finish(0);
      end else begin
        $error("[FAIL] TORV peripheral underflow: periph_tx=%0d (expected %0d)",
               periph_tx_count_hw, replay_expect);
        $finish(1);
      end
    end else begin
      $error("TIMEOUT waiting for TORV tohost after %0d cycles", max_cycles);
      $finish(1);
    end
  end

  initial begin
    if ($test$plusargs("vcd")) begin
      string vcd_path;
      if (!$value$plusargs("vcdfile=%s", vcd_path))
        vcd_path = "tb_torv_soc.vcd";
      $dumpfile(vcd_path);
      $dumpvars(0, tb_torv_soc);
    end
`ifdef RV32M_FSDB
    if ($test$plusargs("fsdb")) begin
      string fsdb_path;
      if (!$value$plusargs("fsdbfile=%s", fsdb_path))
        fsdb_path = "tb_torv_soc.fsdb";
      $fsdbDumpfile(fsdb_path);
      $fsdbDumpvars(0, tb_torv_soc);
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
            (dut.u_cpu.u_core.pc !== pc_trace_prev);
        if (log_it) begin
          $fwrite(pc_trace_fd, "%0t\t%h\t%h\t%h\t%h\n", $time, dut.u_cpu.u_core.pc,
                  dut.i_hrdata, dut.u_cpu.u_core.if_id_pc, dut.u_cpu.u_core.if_id_inst);
          pc_trace_warmed <= 1'b1;
        end
      end
      pc_trace_prev <= dut.u_cpu.u_core.pc;
    end
  end

  always @(posedge hclk) begin
    if (hresetn && $test$plusargs("trace")) begin
      $display("T=%0t pc=%08x ifid_pc=%08x ifid_inst=%08x x1=%08x I[%b rdy=%0b a=%08x] D[%b rdy=%0b we=%0b a=%08x] S[%b rdy=%0b we=%0b a=%08x rd=%08x]",
               $time, dut.u_cpu.u_core.pc, dut.u_cpu.u_core.if_id_pc,
               dut.u_cpu.u_core.if_id_inst, dut.u_cpu.u_core.u_rf.mem[1],
               dut.i_htrans, dut.i_hready, dut.i_haddr,
               dut.d_htrans, dut.d_hready, dut.d_hwrite, dut.d_haddr,
               dut.s_htrans, dut.s_hready, dut.s_hwrite, dut.s_haddr, dut.s_hrdata);
    end
  end

endmodule
