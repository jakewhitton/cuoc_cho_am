library ieee;
    use ieee.std_logic_1164.all;

library sw_transport;
    use sw_transport.all;

entity top is
    port (
        i_clk : in  std_logic;
        i_rx  : in  std_logic;
        o_tx  : out std_logic;
        o_data  : out std_logic_vector(7 downto 0)
    );
end top;

architecture structure of top is
begin
    uart_loopback : sw_transport.uart.uart_loopback
        port map (
            i_clk,
            i_rx,
            o_tx,
            o_data
        );
end structure;
