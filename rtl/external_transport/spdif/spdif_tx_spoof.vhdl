library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.spdif.all;

entity spdif_tx_spoof is
    port (
        i_clk   : in  std_logic;
        o_spdif : out std_logic
    );
end spdif_tx_spoof;

architecture behavioral of spdif_tx_spoof is

    -- Transmit state machine
    type State_t is (INIT, PREAMBLE, DATA, STATUS, SPINNING);
    signal state      : State_t := INIT;
    signal next_state : State_t := INIT;
    signal counter    : natural := 0;

    -- Intermediate signals
    signal spdif : std_logic := '0';


begin

    transmit_sm : process(i_clk)
    begin
        if rising_edge(i_clk) then
            case state is
                when INIT =>
                    spdif <= '0';
                    next_state <= PREAMBLE;
                    counter <= 14;
                    state <= SPINNING;

                when PREAMBLE =>
                    spdif <= not spdif;
                    next_state <= DATA;
                    counter <= 60;
                    state <= SPINNING;

                when DATA =>
                    spdif <= not spdif;
                    next_state <= PREAMBLE;
                    counter <= 60;
                    state <= SPINNING;

                when STATUS =>
                    -- TODO

                when SPINNING =>
                    if counter = 0 then
                        state <= next_state;
                    else
                        counter <= counter - 1;
                    end if;
                    -- TODO

                when others =>
                    -- TODO, assert false

            end case;
        end if;
    end process;

    
    o_spdif <= spdif;

end behavioral;
