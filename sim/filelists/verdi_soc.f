// Verdi: source scripts/open_rv.sh from the open_rv32m repo first.
//   verdi -nologo -sv -f $RV32M_FILELIST_SOC -top tb_torv_soc

+incdir+$RV32M_ROOT/rtl
+incdir+$RV32M_ROOT/ip/third_party/socbus/include
$RV32M_ROOT/rtl/bus_if.sv
$RV32M_ROOT/rtl/addr_decode.sv
$RV32M_ROOT/rtl/pc_unit.sv
$RV32M_ROOT/rtl/regfile.sv
$RV32M_ROOT/rtl/imm_gen.sv
$RV32M_ROOT/rtl/decoder.sv
$RV32M_ROOT/rtl/alu_control.sv
$RV32M_ROOT/rtl/alu.sv
$RV32M_ROOT/rtl/muldiv_unit.sv
$RV32M_ROOT/rtl/forwarding_unit.sv
$RV32M_ROOT/rtl/hazard_unit.sv
$RV32M_ROOT/rtl/lsu.sv
$RV32M_ROOT/rtl/rv32im_core.sv
$RV32M_ROOT/rtl/rv32im_ahb_bridge.sv
$RV32M_ROOT/rtl/rv32im_ahb_top.sv
$RV32M_ROOT/rtl/torv_ahb_sram.sv
$RV32M_ROOT/rtl/torv_soc_top.sv
$RV32M_ROOT/ip/third_party/socbus/rtl/AHB_APB_BRIDGE.v
$RV32M_ROOT/ip/third_party/apb_uart_sv/rtl/apb_uart_sv.sv
$RV32M_ROOT/ip/third_party/apb_uart_sv/rtl/apb_uart_txreg.sv
$RV32M_ROOT/ip/third_party/apb_uart_sv/rtl/apb_uart_rxreg.sv
$RV32M_ROOT/ip/third_party/apb_uart_sv/rtl/apb_uart_baudgen.sv
$RV32M_ROOT/ip/third_party/apb_uart_sv/rtl/apb_uart_fifo.sv
$RV32M_ROOT/sim/tb_torv_soc.sv
