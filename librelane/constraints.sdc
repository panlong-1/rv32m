# rv32im_ahb_top on IHP SG13G2 — mirrors dc/constraints.sdc (units: ns, pF)

set clk_port hclk
set rst_port hresetn

create_clock -name CLK -period $::env(CLOCK_PERIOD) [get_ports $clk_port]

set_input_delay  2.0 -clock CLK -max [all_inputs -no_clocks]
set_input_delay  0.5 -clock CLK -min [all_inputs -no_clocks]
set_output_delay 2.0 -clock CLK -max [all_outputs]
set_output_delay 0.5 -clock CLK -min [all_outputs]
set_false_path -from [get_ports $rst_port]

set_load 0.05 [all_outputs]
set_input_transition 0.3 [all_inputs]

set_clock_uncertainty -setup 0.3 [get_clocks CLK]
set_clock_uncertainty -hold  0.1 [get_clocks CLK]
