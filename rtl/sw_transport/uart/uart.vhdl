library ieee;
    use ieee.std_logic_1164.all;

package uart is

    -- Define ratio of input clk <-> baud rate: (100MHz)/(115200Hz) ~= 868
    constant clks_per_baud : integer := 868;

    type Uart_State_t is (
        WAITING_FOR_DATA, -- Initial state
        START_BIT,        -- Beginning of word
        DATA_BIT,         -- Data bits
        STOP_BIT,         -- End of word
        SPINNING          -- Wait for `counter` number of clk periods to pass, then transition to `next_state`
    );

    type Uart_t is record
        state       : Uart_State_t;
        -- Used by DATA_BIT state
        current_bit : integer range 0 to 7;
        -- Used by SPINNING state
        counter     : integer range 0 to clks_per_baud;
        next_state  : Uart_State_t;
    end record Uart_t;

    constant INIT_UART_T: Uart_t := (
        state       => WAITING_FOR_DATA,
        current_bit => 0,
        counter     => 0,
        next_state  => WAITING_FOR_DATA
    );

    component uart_rx is
        port (
            i_clk   : in  std_logic;
            i_rx    : in  std_logic;
            o_valid : out std_logic;
            o_data  : out std_logic_vector(7 downto 0)
        );
    end component;

end package uart;
