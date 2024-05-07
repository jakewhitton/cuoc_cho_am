# clk
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {i_clk}];
create_clock -name clk -period 10.00 [get_ports {i_clk}];

# uart_rxd
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports {i_rx}];

# o_valid
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports {o_valid}];

# o_data
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {o_data[0]}];
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVCMOS33} [get_ports {o_data[1]}];
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS33} [get_ports {o_data[2]}];
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports {o_data[3]}];
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {o_data[4]}];
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {o_data[5]}];
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {o_data[6]}];
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {o_data[7]}];
