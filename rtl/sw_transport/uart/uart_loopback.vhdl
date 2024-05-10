library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.uart.all;

entity uart_loopback is
    port (
        i_clk   : in  std_logic;
        i_rx    : in  std_logic;
        o_tx    : out std_logic;
        o_data  : out std_logic_vector(7 downto 0)
    );
end uart_loopback;

architecture behavioral of uart_loopback is

    signal valid : std_logic                    := '0';
    signal data  : std_logic_vector(7 downto 0) := (others => '0');

begin

    uart_rx : work.uart.uart_rx
        port map (
            i_clk,
            i_rx,
            valid,
            data
        );

    uart_tx : work.uart.uart_tx
        port map (
            i_clk,
            o_tx,
            valid,
            data
        );

    o_data <= data;

end behavioral;
