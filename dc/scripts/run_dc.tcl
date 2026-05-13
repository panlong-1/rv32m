# rv32im_core — Design Compiler synthesis (TSMC 0.13 µm target .db via env)
# Run from rv32m/dc:  dc_shell-xg-t -64 -f scripts/run_dc.tcl | tee logs/dc.log
#
# Required:
#   export TSMC013_TARGET_LIB=$HOME/PDK/TSMC_013/synopsys/slow.db
# Optional:
#   export TSMC013_WLM=tsmc13fsg_6lm
#   export TSMC013_SOURCE_PDK_SETUP=1   # source synopsys_dc.setup from same dir as .db

set TOP rv32im_ahb_top

set DC_ROOT  [file normalize [file dirname [file dirname [info script]]]]
set RTL_ROOT [file normalize [file join $DC_ROOT .. rtl]]
set SYN_ROOT [file normalize [file join $DC_ROOT .. dc]]

file mkdir [file join $SYN_ROOT logs]
file mkdir [file join $SYN_ROOT outputs]
file mkdir [file join $SYN_ROOT reports]
file mkdir [file join $SYN_ROOT work]

define_design_lib WORK -path [file join $SYN_ROOT work]

if {![info exists env(TSMC013_TARGET_LIB)] || $env(TSMC013_TARGET_LIB) eq ""} {
  puts {ERROR: set TSMC013_TARGET_LIB to the absolute path of your TSMC_013 standard-cell .db}
  puts {Example: export TSMC013_TARGET_LIB=$HOME/PDK/TSMC_013/.../typical.db}
  exit 1
}

set TARGET_LIB_PATH [file normalize $env(TSMC013_TARGET_LIB)]
if {![file isfile $TARGET_LIB_PATH]} {
  puts "ERROR: TSMC013_TARGET_LIB is not a file: $TARGET_LIB_PATH"
  exit 1
}

set SYMBOL_LIB_PATH $TARGET_LIB_PATH
if {[info exists env(TSMC013_SYMBOL_LIB)] && $env(TSMC013_SYMBOL_LIB) ne ""} {
  set SYMBOL_LIB_PATH [file normalize $env(TSMC013_SYMBOL_LIB)]
}

set_app_var search_path [list $SYN_ROOT $RTL_ROOT [file dirname $TARGET_LIB_PATH] [file dirname $SYMBOL_LIB_PATH]]

# Optional: source PDK macro (only if you set TSMC013_SOURCE_PDK_SETUP=1; may set search_path / libs)
set PDK_SETUP [file join [file dirname $TARGET_LIB_PATH] synopsys_dc.setup]
if {[info exists env(TSMC013_SOURCE_PDK_SETUP)] && $env(TSMC013_SOURCE_PDK_SETUP) eq "1"} {
  if {[file isfile $PDK_SETUP]} {
    puts "INFO: sourcing $PDK_SETUP"
    source -echo -verbose $PDK_SETUP
  } else {
    puts "WARN: TSMC013_SOURCE_PDK_SETUP=1 but missing $PDK_SETUP"
  }
}

read_db $TARGET_LIB_PATH
if {$SYMBOL_LIB_PATH ne $TARGET_LIB_PATH && [file isfile $SYMBOL_LIB_PATH]} {
  read_db $SYMBOL_LIB_PATH
}

set target_library [list [file tail $TARGET_LIB_PATH]]
set synthetic_library dw_foundation.sldb
set_app_var link_library [concat * $target_library $synthetic_library]

puts "INFO: target_library = $target_library"
puts "INFO: link_library   = $link_library"

# --- RTL (bus_if.sv is typedef-only; omit for DC) ---
set rtl_files [list \
  [file join $RTL_ROOT addr_decode.sv] \
  [file join $RTL_ROOT pc_unit.sv] \
  [file join $RTL_ROOT regfile.sv] \
  [file join $RTL_ROOT imm_gen.sv] \
  [file join $RTL_ROOT decoder.sv] \
  [file join $RTL_ROOT alu_control.sv] \
  [file join $RTL_ROOT alu.sv] \
  [file join $RTL_ROOT muldiv_unit.sv] \
  [file join $RTL_ROOT forwarding_unit.sv] \
  [file join $RTL_ROOT hazard_unit.sv] \
  [file join $RTL_ROOT lsu.sv] \
  [file join $RTL_ROOT rv32im_core.sv] \
  [file join $RTL_ROOT rv32im_ahb_bridge.sv] \
  [file join $RTL_ROOT rv32im_ahb_top.sv] \
]

foreach rf $rtl_files {
  if {![file isfile $rf]} {
    puts "ERROR: missing RTL $rf"
    exit 1
  }
}

analyze -format sverilog -library work $rtl_files
elaborate $TOP -library work
current_design $TOP
link

# Wire load: export TSMC013_WLM=ExactName, or we try common TSMC_013/synopsys plib names
if {[info exists env(TSMC013_WLM)] && $env(TSMC013_WLM) ne ""} {
  if {[catch {set_wire_load_model -name $env(TSMC013_WLM)} err]} {
    puts "WARN: set_wire_load_model $env(TSMC013_WLM) failed: $err"
  } else {
    puts "INFO: wire_load_model $env(TSMC013_WLM)"
  }
} else {
  foreach wlm {tsmc13fsg_6lm tsmc13fsg_5lm tsmc13fsg_7lm tsmc13fsg_8lm tsmc13fsg_4lm} {
    if {[catch {set_wire_load_model -name $wlm} err] == 0} {
      puts "INFO: wire_load_model (auto) $wlm"
      break
    }
  }
}

check_design > [file join $SYN_ROOT reports check_design_pre.rpt]

source -echo -verbose [file join $SYN_ROOT constraints.sdc]

# Mapping + optimization (DesignWare may absorb wide multipliers/dividers)
compile_ultra -no_autoungroup

write -format verilog -hierarchy -output [file join $SYN_ROOT outputs ${TOP}_mapped.v]
write -format ddc -hierarchy -output [file join $SYN_ROOT outputs ${TOP}_mapped.ddc]

report_area -hierarchy > [file join $SYN_ROOT reports area.rpt]
report_area -nosplit > [file join $SYN_ROOT reports area_flat.rpt]
report_timing -path full -delay max -max_paths 30 -nets > [file join $SYN_ROOT reports timing_max.rpt]
report_timing -path full -delay min -max_paths 10 > [file join $SYN_ROOT reports timing_min.rpt]
report_qor > [file join $SYN_ROOT reports qor.rpt]
if {[catch {redirect [file join $SYN_ROOT reports power.rpt] { report_power }} err]} {
  puts "WARN: report_power skipped: $err"
}

puts "Done. Gate netlist: outputs/${TOP}_mapped.v"
exit
