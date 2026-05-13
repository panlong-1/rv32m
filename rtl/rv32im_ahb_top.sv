// RV32IM core wrapped with independent I/D/S AHB-Lite master ports.
module rv32im_ahb_top (
  input  logic        hclk,
  input  logic        hresetn,

  output logic [31:0] i_haddr,
  output logic [1:0]  i_htrans,
  output logic        i_hwrite,
  output logic [2:0]  i_hsize,
  output logic [2:0]  i_hburst,
  output logic [3:0]  i_hprot,
  output logic [31:0] i_hwdata,
  input  logic [31:0] i_hrdata,
  input  logic        i_hready,
  input  logic        i_hresp,

  output logic [31:0] d_haddr,
  output logic [1:0]  d_htrans,
  output logic        d_hwrite,
  output logic [2:0]  d_hsize,
  output logic [2:0]  d_hburst,
  output logic [3:0]  d_hprot,
  output logic [31:0] d_hwdata,
  input  logic [31:0] d_hrdata,
  input  logic        d_hready,
  input  logic        d_hresp,

  output logic [31:0] s_haddr,
  output logic [1:0]  s_htrans,
  output logic        s_hwrite,
  output logic [2:0]  s_hsize,
  output logic [2:0]  s_hburst,
  output logic [3:0]  s_hprot,
  output logic [31:0] s_hwdata,
  input  logic [31:0] s_hrdata,
  input  logic        s_hready,
  input  logic        s_hresp
);
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

  rv32im_core u_core (
    .clk(hclk),
    .rst_n(hresetn),
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

  rv32im_ahb_bridge #(.STRICT_ADDR_MATCH(1'b1)) u_i_bridge (
    .hclk(hclk),
    .hresetn(hresetn),
    .req_valid(ibus_valid),
    .req_ready(ibus_ready),
    .req_addr(ibus_addr),
    .req_we(1'b0),
    .req_be(4'b1111),
    .req_wdata(32'd0),
    .req_rdata(ibus_rdata),
    .haddr(i_haddr),
    .htrans(i_htrans),
    .hwrite(i_hwrite),
    .hsize(i_hsize),
    .hburst(i_hburst),
    .hprot(i_hprot),
    .hwdata(i_hwdata),
    .hrdata(i_hrdata),
    .hready(i_hready),
    .hresp(i_hresp)
  );

  rv32im_ahb_bridge #(.STRICT_ADDR_MATCH(1'b0)) u_d_bridge (
    .hclk(hclk),
    .hresetn(hresetn),
    .req_valid(dbus_valid),
    .req_ready(dbus_ready),
    .req_addr(dbus_addr),
    .req_we(dbus_we),
    .req_be(dbus_be),
    .req_wdata(dbus_wdata),
    .req_rdata(dbus_rdata),
    .haddr(d_haddr),
    .htrans(d_htrans),
    .hwrite(d_hwrite),
    .hsize(d_hsize),
    .hburst(d_hburst),
    .hprot(d_hprot),
    .hwdata(d_hwdata),
    .hrdata(d_hrdata),
    .hready(d_hready),
    .hresp(d_hresp)
  );

  rv32im_ahb_bridge #(.STRICT_ADDR_MATCH(1'b0)) u_s_bridge (
    .hclk(hclk),
    .hresetn(hresetn),
    .req_valid(sbus_valid),
    .req_ready(sbus_ready),
    .req_addr(sbus_addr),
    .req_we(sbus_we),
    .req_be(sbus_be),
    .req_wdata(sbus_wdata),
    .req_rdata(sbus_rdata),
    .haddr(s_haddr),
    .htrans(s_htrans),
    .hwrite(s_hwrite),
    .hsize(s_hsize),
    .hburst(s_hburst),
    .hprot(s_hprot),
    .hwdata(s_hwdata),
    .hrdata(s_hrdata),
    .hready(s_hready),
    .hresp(s_hresp)
  );
endmodule
