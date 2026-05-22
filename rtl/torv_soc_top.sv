// TORV SoC — Torino Open RISC-V
// PoliTO-oriented student open-source RV32IM platform.
//
// Subsystems (single integration top):
//   - rv32im_ahb_top     (CPU + IBUS/DBUS/SBUS AHB-Lite masters)
//   - torv_ahb_sram      (IMEM, DMEM, SBUS SRAM)
//   - AHB_APB_BRIDGE     (SoCBUS, SBUS peripheral window)
//   - apb_uart_sv        (PULP UART @ 0x4000_1000)
//
// Address map (SBUS master):
//   0x0000_0000 .. 0x0000_FFFF  SBUS SRAM (64 KiB)
//   0x4000_0000 .. (via [15:0]) SBUS data SRAM (core asm tests)
//   0x4000_1000 .. 0x4000_1FFF  APB UART (periph asm tests)
//   0xF000_0000                 tohost (monitored by tb_torv_soc, not decoded here)
//
// AHB note: s_periph_sel and s_bridge_hsel use the current address phase. This matches
// the single-beat rv32im_ahb_bridge master (HADDR held until HREADY). For pipelined
// DMA or strict AMBA compliance, register the peripheral select on HREADY and mux
// data-phase HRDATA/HREADY from the latched decode; keep HSEL address-only (not gated
// by HTRANS_IDLE) per ARM AMBA guidance.
`timescale 1ns / 1ps

module torv_soc_top #(
  parameter int IMEM_BYTES = 65536,
  parameter int DMEM_BYTES = 65536,
  parameter int SBMEM_BYTES = 65536,
  // SBUS scratch/data tests historically use 0x4000_0000 as SRAM. Keep UART on
  // the next 4 KiB page so core SBUS tests and APB side-effect tests do not collide.
  parameter logic [31:0] UART_APB_BASE = 32'h4000_1000,
  parameter logic [31:0] UART_APB_SIZE = 32'h0000_1000
) (
  input  logic        hclk,
  input  logic        hresetn,

  // Testbench bus back-pressure (deep-hazard directed tests)
  input  logic        ibus_stall_hold,
  input  logic        sbus_stall_hold,

  output logic        uart_tx,
  output logic [7:0]  uart_thr_push_count,
  output logic [4:0]  uart_tx_fifo_depth_max,
  output logic [7:0]  uart_rbr_read_count
);
  localparam logic [1:0] HTRANS_IDLE = 2'b00;

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

  rv32im_ahb_top u_cpu (
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

  logic i_sram_hready;

  torv_ahb_sram #(.BYTES(IMEM_BYTES)) u_i_sram (
    .hclk(hclk),
    .hresetn(hresetn),
    .haddr(i_haddr),
    .htrans(i_htrans),
    .hwrite(i_hwrite),
    .hsize(i_hsize),
    .hwdata(i_hwdata),
    .hrdata(i_hrdata),
    .hready(i_sram_hready),
    .hresp(i_hresp)
  );

  torv_ahb_sram #(.BYTES(DMEM_BYTES)) u_d_sram (
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

  logic        s_periph_sel;
  logic [31:0] s_sram_hrdata;
  logic        s_sram_hready;
  logic        s_sram_hresp;
  logic [31:0] s_periph_hrdata;
  logic        s_periph_hready;
  logic        s_periph_hresp;

  assign s_periph_sel =
      (s_haddr >= UART_APB_BASE) && (s_haddr < (UART_APB_BASE + UART_APB_SIZE));

  torv_ahb_sram #(
    .BYTES(SBMEM_BYTES),
    .TOHOST_ENABLE(1'b0)
  ) u_s_sram (
    .hclk(hclk),
    .hresetn(hresetn),
    .haddr(s_haddr),
    .htrans(s_htrans),
    .hwrite(s_hwrite),
    .hsize(s_hsize),
    .hwdata(s_hwdata),
    .hrdata(s_sram_hrdata),
    .hready(s_sram_hready),
    .hresp(s_sram_hresp)
  );

  logic uart_rx;
  logic        s_bridge_hreadyout;
  logic [31:0] s_bridge_hrdata;
  logic        apb_pclk;
  logic        apb_presetn;
  logic [31:0] apb_paddr;
  logic [31:0] apb_pwdata;
  logic        apb_pwrite;
  logic        apb_psel;
  logic        apb_penable;
  logic [31:0] apb_prdata;
  logic        apb_pready;
  logic        apb_pslverr;

  wire s_bridge_hsel = s_periph_sel && (s_htrans != HTRANS_IDLE);

  assign uart_rx           = 1'b1;
  assign s_hready          = s_periph_sel ? s_bridge_hreadyout :
                             (s_sram_hready && !sbus_stall_hold);
  assign s_hrdata          = s_periph_sel ? s_periph_hrdata : s_sram_hrdata;
  assign s_hresp           = 1'b0;
  assign s_periph_hrdata   = s_bridge_hrdata;
  assign s_periph_hresp    = 1'b0;
  assign apb_presetn       = hresetn;
  assign apb_psel          = s_periph_sel && (apb_penable || !s_bridge_hreadyout);

  assign i_hready = i_sram_hready && !ibus_stall_hold;

  AHB_APB_BRIDGE #(.SLOW_PCLK(0)) u_ahb_apb (
    .HCLK(hclk),
    .HRESETn(hresetn),
    .HSEL(s_bridge_hsel),
    .HADDR(s_haddr),
    .HTRANS(s_htrans),
    .HWRITE(s_hwrite),
    .HREADY(s_hready),
    .HWDATA(s_hwdata),
    .HSIZE(s_hsize),
    .HREADYOUT(s_bridge_hreadyout),
    .HRDATA(s_bridge_hrdata),
    .PCLK(apb_pclk),
    .PRESETn(apb_presetn),
    .PCLKEN(1'b1),
    .PRDATA(apb_prdata),
    .PREADY(apb_pready),
    .PWDATA(apb_pwdata),
    .PENABLE(apb_penable),
    .PADDR(apb_paddr),
    .PWRITE(apb_pwrite)
  );

  apb_uart_sv #(
    .APB_ADDR_WIDTH(12)
  ) u_apb_uart (
    .CLK(apb_pclk),
    .RSTN(apb_presetn),
    .PADDR(apb_paddr[11:0]),
    .PWDATA(apb_pwdata),
    .PWRITE(apb_pwrite),
    .PSEL(apb_psel),
    .PENABLE(apb_penable),
    .PRDATA(apb_prdata),
    .PREADY(apb_pready),
    .PSLVERR(apb_pslverr),
    .rx_i(uart_rx),
    .tx_o(uart_tx),
    .event_o()
  );

  wire apb_uart_rbr_read =
      apb_psel && apb_penable && !apb_pwrite && (apb_paddr[2:0] == 3'b000) &&
      !u_apb_uart.regs_q[3][7]; // RBR, not DLL (LCR.DLAB)

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      uart_tx_fifo_depth_max <= 5'd0;
      uart_thr_push_count    <= 8'd0;
      uart_rbr_read_count    <= 8'd0;
    end else begin
      if (u_apb_uart.tx_elements > uart_tx_fifo_depth_max)
        uart_tx_fifo_depth_max <= u_apb_uart.tx_elements;
      if (u_apb_uart.fifo_tx_valid)
        uart_thr_push_count <= uart_thr_push_count + 8'd1;
      if (apb_uart_rbr_read && apb_pready)
        uart_rbr_read_count <= uart_rbr_read_count + 8'd1;
    end
  end

endmodule
