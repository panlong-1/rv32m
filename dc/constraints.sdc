# rv32im_ahb_top clock / IO budgets (tune after first QOR)
# Clock period in ns — tighten to explore max F for TSMC_013.

set clk_port hclk
set rst_port hresetn

create_clock -name CLK -period 5.0 [get_ports $clk_port]

set_false_path -from [get_ports $rst_port]

# Remove clock from data input delays
set nonclk_inputs [remove_from_collection [all_inputs] [get_ports $clk_port]]
set nonclk_inputs [remove_from_collection $nonclk_inputs [get_ports $rst_port]]

# IO budgets (ns); adjust to your pad / board plan
set_input_delay 2.0 -clock CLK -max $nonclk_inputs
set_input_delay 0.5 -clock CLK -min $nonclk_inputs
set_output_delay 2.0 -clock CLK -max [all_outputs]
set_output_delay 0.5 -clock CLK -min [all_outputs]

# Output pin capacitance (library-dependent units); lower = harder timing
set_load 0.05 [all_outputs]

set_input_transition 0.3 [all_inputs]

set_clock_uncertainty -setup 0.3 [get_clocks CLK]
set_clock_uncertainty -hold  0.1 [get_clocks CLK]
