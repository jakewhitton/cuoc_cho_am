library ieee;
    use ieee.std_logic_1164.all;

library sw_transport;
    use sw_transport.all;

entity top is
    port (
        i_clk : in  std_logic;
        i_rx  : in  std_logic;
        o_tx  : out std_logic
    );
end top;

architecture structure of top is
begin
    uart_loopback : sw_transport.uart.uart_loopback
        port map (
            i_clk,
            i_rx,
            o_tx
        );
end structure;
