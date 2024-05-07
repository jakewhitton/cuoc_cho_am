library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    port (
        i_clk   : in  std_logic;
        i_rx    : in  std_logic;
        o_valid : out std_logic;
        o_data  : out std_logic_vector(7 downto 0)
    );
end uart_rx;

architecture behavioral of uart_rx is

    -- (100MHz)/(115200Hz) ~= 868
    constant clks_per_baud : integer := 868;

    -- double sample i_rx to assist with metastability
    signal rx_dup : std_logic := '0';
    signal rx     : std_logic := '0';

    -- state machine
    type State_t is (
        WAITING_FOR_DATA, -- Initial state
        START_BIT,        -- Beginning of word
        SAMPLE_DATA_BIT,  -- Data bits
        STOP_BIT,         -- End of word
        SPINNING          -- Wait for `counter` number of clk periods to pass, then transition to `next_state`
    );
    signal state : State_t := WAITING_FOR_DATA;

    -- Supplementary state for SAMPLE_DATA_BIT
    signal bit_to_sample : integer range 0 to 7 := 0;

    -- Supplementary state for SPINNING
    signal counter : integer range 0 to clks_per_baud := 0;
    signal next_state : State_t := WAITING_FOR_DATA;

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
            case state is

                when WAITING_FOR_DATA =>
                    -- Upon first detection of rx low (start bit), wait for a half baud
                    if rx = '0' then
                        counter <= clks_per_baud / 2;
                        state <= SPINNING;
                        next_state <= START_BIT;
                    end if;

                when START_BIT =>
                    if rx = '0' then
                        -- Invalidate previous data
                        o_valid <= '0';

                        bit_to_sample <= 0;
                        counter <= clks_per_baud;
                        state <= SPINNING;
                        next_state <= SAMPLE_DATA_BIT;
                    else
                        -- Should not be reached, but it probably means that
                        -- the start bit was spurious.  Transit back to WAITING_FOR_DATA.
                        state <= WAITING_FOR_DATA;
                    end if;

                when SAMPLE_DATA_BIT =>
                    o_data(bit_to_sample) <= rx;

                    counter <= clks_per_baud;
                    if bit_to_sample < 7 then
                        bit_to_sample <= bit_to_sample + 1;
                        next_state <= SAMPLE_DATA_BIT;
                    else
                        next_state <= STOP_BIT;
                    end if;

                    state <= SPINNING;

                when STOP_BIT =>
                    if rx = '1' then
                        o_valid <= '1';
                    end if;

                    state <= WAITING_FOR_DATA;

                when SPINNING =>
                    -- Spin for `counter` clock cycles, then transit to `next_state`
                    if counter = 0 then
                        state <= next_state;
                    else
                        counter <= counter - 1;
                    end if;
            end case;
        end if;
    end process state_machine;

end behavioral;
