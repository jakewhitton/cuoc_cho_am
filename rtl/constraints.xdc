# clk
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports {i_clk}];
create_clock -name clk -period 10.00 [get_ports {i_clk}];

# uart_rxd
set_property -dict {PACKAGE_PIN C4 IOSTANDARD LVCMOS33} [get_ports {i_rx}];

# uart_txd
set_property -dict {PACKAGE_PIN D4 IOSTANDARD LVCMOS33} [get_ports {o_tx}];
