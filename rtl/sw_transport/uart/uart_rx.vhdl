library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.uart.all;

entity uart_rx is
    port (
        i_clk   : in  std_logic;
        i_rx    : in  std_logic;
        o_valid : out std_logic;
        o_data  : out std_logic_vector(7 downto 0)
    );
end uart_rx;

architecture behavioral of uart_rx is

    -- double sample i_rx to assist with metastability
    signal rx_dup : std_logic := '0';
    signal rx     : std_logic := '0';

    signal uart : Uart_t := INIT_UART_T;

begin

    -- Double sample i_rx to assist with metastability
    rx_sampler : process(i_clk)
    begin
        if rising_edge(i_clk) then
            rx_dup <= i_rx;
            rx <= rx_dup;
        end if;
    end process rx_sampler;

    -- State machine for uart reading
    state_machine : process(i_clk)
    begin
        if rising_edge(i_clk) then
            case uart.state is

                when WAITING_FOR_DATA =>
                    -- Upon first detection of rx low (start bit), wait for a half baud
                    if rx = '0' then
                        uart.counter <= clks_per_baud / 2;
                        uart.state <= SPINNING;
                        uart.next_state <= START_BIT;
                    end if;

                when START_BIT =>
                    if rx = '0' then
                        -- Invalidate previous data
                        o_valid <= '0';

                        uart.current_bit <= 0;
                        uart.counter <= clks_per_baud;
                        uart.state <= SPINNING;
                        uart.next_state <= DATA_BIT;
                    else
                        -- Should not be reached, but it probably means that
                        -- the start bit was spurious.  Transit back to WAITING_FOR_DATA.
                        uart.state <= WAITING_FOR_DATA;
                    end if;

                when DATA_BIT =>
                    o_data(uart.current_bit) <= rx;

                    uart.counter <= clks_per_baud;
                    if uart.current_bit < 7 then
                        uart.current_bit <= uart.current_bit + 1;
                        uart.next_state <= DATA_BIT;
                    else
                        uart.next_state <= STOP_BIT;
                    end if;

                    uart.state <= SPINNING;

                when STOP_BIT =>
                    if rx = '1' then
                        o_valid <= '1';
                    end if;

                    uart.state <= WAITING_FOR_DATA;

                when SPINNING =>
                    -- Spin for `counter` clock cycles, then transit to `next_state`
                    if uart.counter = 0 then
                        uart.state <= uart.next_state;
                    else
                        uart.counter <= uart.counter - 1;
                    end if;
            end case;
        end if;
    end process state_machine;

end behavioral;
