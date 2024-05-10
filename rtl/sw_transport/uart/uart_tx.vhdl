library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.uart.all;

entity uart_tx is
    port (
        i_clk      : in  std_logic;
        o_tx       : out std_logic;
        i_valid    : in  std_logic;
        i_data     : in  std_logic_vector(7 downto 0)
    );
end uart_tx;

architecture behavioral of uart_tx is

    signal uart : Uart_t := INIT_UART_T;

    -- State for input receive state machine
    type Input_State_t is (
        WAITING_FOR_INPUT_DATA,
        WAITING_FOR_TRANSMIT_END,
        BEGIN_TRANSMIT
    );
    signal received_data : std_logic_vector(7 downto 0) := (others => '0');
    signal input_state  : Input_State_t := WAITING_FOR_INPUT_DATA;
    signal prev_i_valid : std_logic := '0';
    signal transmit_trigger : std_logic                    := '0';
    signal transmit_data    : std_logic_vector(7 downto 0) := (others => '0');

    -- State for transmit state machine
    signal prev_transmit_trigger: std_logic := '0';

begin

    -- Scan for new d
    --
    -- Guarantees:
    --   1. Never overwrite
    scan_for_new_data : process(i_clk)
    begin
        if rising_edge(i_clk) then

            case input_state is

                when WAITING_FOR_INPUT_DATA =>
                    if prev_i_valid = '0' and i_valid = '1' then
                        received_data <= i_data;
                        transmit_trigger <= '0';
                        input_state <= WAITING_FOR_TRANSMIT_END;
                    end if;

                when WAITING_FOR_TRANSMIT_END =>
                    if uart.state = WAITING_FOR_DATA then
                        input_state <= BEGIN_TRANSMIT;
                    end if;

                when BEGIN_TRANSMIT =>
                    transmit_data <= received_data;
                    transmit_trigger <= '1';
                    input_state <= WAITING_FOR_INPUT_DATA;

            end case;

            prev_i_valid <= i_valid;
        end if;
    end process scan_for_new_data;

    -- State machine for uart writing
    state_machine : process(i_clk)
    begin
        if rising_edge(i_clk) then
            case uart.state is

                when WAITING_FOR_DATA =>
                    -- Upon detection of new data, transit into START_BIT
                    if prev_transmit_trigger = '0' and transmit_trigger = '1' then
                        uart.state <= START_BIT;
                    end if;

                when START_BIT =>
                    -- Immediately lower o_tx, then spin for one baud
                    o_tx <= '0';
                    uart.current_bit <= 0;
                    uart.counter <= clks_per_baud;
                    uart.state <= SPINNING;
                    uart.next_state <= DATA_BIT;

                when DATA_BIT =>
                    -- Immediately write data bit, then spin for one baud
                    o_tx <= transmit_data(uart.current_bit);
                    uart.current_bit <= uart.current_bit + 1;
                    uart.counter <= clks_per_baud;
                    uart.state <= SPINNING;

                    -- After spin, transit back to either:
                    --   1. DATA_BIT if current_bit < 7
                    --   2. STOP_BIT otherwise
                    if uart.current_bit < 7 then
                        uart.next_state <= DATA_BIT;
                    else
                        uart.next_state <= STOP_BIT;
                    end if;

                when STOP_BIT =>
                    -- Immediately raise o_tx, then spin for one baud
                    o_tx <= '1';
                    uart.counter <= clks_per_baud;
                    uart.state <= SPINNING;
                    uart.next_state <= WAITING_FOR_DATA;

                when SPINNING =>
                    -- Spin for `counter` clock cycles, then transit to `next_state`
                    if uart.counter = 0 then
                        uart.state <= uart.next_state;
                    else
                        uart.counter <= uart.counter - 1;
                    end if;
            end case;

            prev_transmit_trigger <= transmit_trigger;
        end if;
    end process state_machine;

end behavioral;
