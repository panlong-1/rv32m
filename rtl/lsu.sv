// Load/store unit — DBUS vs SBUS routing (spec §3 MEM, §13)
module lsu (
  input  logic        mem_read,
  input  logic        mem_write,
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  input  logic [2:0]  funct3,
  input  logic        use_sbus,
  output logic        dbus_valid,
  output logic        dbus_we,
  output logic [3:0]  dbus_be,
  output logic [31:0] dbus_addr,
  output logic [31:0] dbus_wdata,
  output logic        sbus_valid,
  output logic        sbus_we,
  output logic [3:0]  sbus_be,
  output logic [31:0] sbus_addr,
  output logic [31:0] sbus_wdata
);
  logic mem_active;
  assign mem_active = mem_read || mem_write;

  always_comb begin
    logic [3:0] be;
    logic [31:0] store_wdata;

    unique case (funct3)
      3'b000: begin
        be = 4'b0001 << addr[1:0];
        store_wdata = {4{wdata[7:0]}} << (8 * addr[1:0]);
      end
      3'b001: begin
        be = addr[1] ? 4'b1100 : 4'b0011;
        store_wdata = {2{wdata[15:0]}} << (16 * addr[1]);
      end
      default: begin
        be = 4'b1111;
        store_wdata = wdata;
      end
    endcase

    dbus_valid  = mem_active && !use_sbus;
    dbus_we     = mem_write && !use_sbus;
    dbus_be     = be;
    dbus_addr   = addr;
    dbus_wdata  = mem_write ? store_wdata : 32'd0;

    sbus_valid  = mem_active && use_sbus;
    sbus_we     = mem_write && use_sbus;
    sbus_be     = be;
    sbus_addr   = addr;
    sbus_wdata  = mem_write ? store_wdata : 32'd0;
  end
endmodule
