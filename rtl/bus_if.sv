// Harvard IBUS / DBUS / SBUS bundles (spec §13.3)
`ifndef RV32M_BUS_IF_SV
`define RV32M_BUS_IF_SV

typedef struct packed {
  logic        valid;
  logic        ready;
  logic [31:0] addr;
  logic [31:0] rdata;
} ibus_mosi_t;

typedef struct packed {
  logic        valid;
  logic        ready;
  logic [31:0] addr;
  logic        we;
  logic [3:0]  be;
  logic [31:0] wdata;
  logic [31:0] rdata;
} dbus_mosi_t;

`endif
