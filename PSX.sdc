derive_pll_clocks
derive_clock_uncertainty

create_generated_clock -name {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -source {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|vco0ph[0]} -divide_by 5 -multiply_by 1 -duty_cycle 50.00 { emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk }

set_false_path -from {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {FPGA_CLK1_50} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {FPGA_CLK2_50} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}

set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}
set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}
set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}
set_false_path -from {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to {FPGA_CLK1_50}