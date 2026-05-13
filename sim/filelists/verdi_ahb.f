// Verdi: source /home/ic/project/open_rv first.
//   verdi -nologo -sv -f $RV32M_FILELIST_AHB -top tb_rv32im_ahb_top

+incdir+$RV32M_ROOT/rtl
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
$RV32M_ROOT/sim/ahb_sram_model.sv
$RV32M_ROOT/sim/tb_rv32im_ahb_top.sv
