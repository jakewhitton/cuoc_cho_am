# clk
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {i_clk}];
create_clock -name clk -period 10 [get_ports {i_clk}];

# S/PDIF
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS33} [get_ports {i_spdif}];
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports {o_spdif}];

# Ethernet PHY
set_property -dict {PACKAGE_PIN D5  IOSTANDARD LVCMOS33} [get_ports {ethernet_phy[clkin]}];
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} [get_ports {ethernet_phy[rxd][0]}];
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {ethernet_phy[rxd][1]}];
set_property -dict {PACKAGE_PIN D9  IOSTANDARD LVCMOS33} [get_ports {ethernet_phy[crs_dv]}];

# LEDs
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {o_leds[0]}];
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {o_leds[1]}];
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {o_leds[2]}];
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {o_leds[3]}];
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {o_leds[4]}];
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {o_leds[5]}];
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {o_leds[6]}];
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {o_leds[7]}];
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {o_leds[8]}];
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports {o_leds[9]}];
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports {o_leds[10]}];
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {o_leds[11]}];
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports {o_leds[12]}];
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {o_leds[13]}];
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports {o_leds[14]}];
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {o_leds[15]}];
