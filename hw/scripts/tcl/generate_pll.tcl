create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name pll

set_property -dict [list \
  CONFIG.CLKOUT1_JITTER {571.196} \
  CONFIG.CLKOUT1_PHASE_ERROR {386.048} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {6.144} \
  CONFIG.CLKOUT2_JITTER {419.254} \
  CONFIG.CLKOUT2_PHASE_ERROR {409.632} \
  CONFIG.CLKOUT2_USED {false} \
  CONFIG.CLK_OUT1_PORT {o_spdif_tx_clk} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {44.375} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {120.375} \
  CONFIG.MMCM_CLKOUT1_DIVIDE {1} \
  CONFIG.MMCM_DIVCLK_DIVIDE {6} \
  CONFIG.NUM_OUT_CLKS {1} \
  CONFIG.PRIMARY_PORT {i_clk} \
] [get_ips pll]

set $files [get_files /home/jake/Downloads/vivado/vivado.srcs/sources_1/ip/pll/pll.xci]
print $files

exit 0

generate_target {instantiation_template} $files

update_compile_order -fileset sources_1
generate_target all [get_files  /home/jake/Downloads/vivado/vivado.srcs/sources_1/ip/pll/pll.xci]
catch { config_ip_cache -export [get_ips -all pll] }
export_ip_user_files -of_objects [get_files /home/jake/Downloads/vivado/vivado.srcs/sources_1/ip/pll/pll.xci] -no_script -sync -force -quiet
