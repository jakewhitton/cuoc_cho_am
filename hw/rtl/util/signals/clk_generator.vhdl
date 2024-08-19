library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.signals.all;

entity clk_generator is
    port (
        i_clk : in  std_logic;
        o_clk : out std_logic
    );
end clk_generator;

architecture behavioral of clk_generator is

    constant CYCLES_LOW  : natural := 4;
    constant CYCLES_HIGH : natural := 4;

    type State_t is (LOW, HIGH);
    signal state : State_t := LOW;
    signal clk     : std_logic := '0';
    signal counter : natural   := 0;

begin

    generate_clk_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then

            case state is
                when LOW =>
                    if counter < CYCLES_LOW then
                        counter <= counter + 1;
                    else
                        state <= HIGH;
                        clk <= '1';
                        counter <= 0;
                    end if;

                when HIGH =>
                    if counter < CYCLES_HIGH then
                        counter <= counter + 1;
                    else
                        state <= LOW;
                        clk <= '0';
                        counter <= 0;
                    end if;
            end case;
        end if;
    end process;
    o_clk <= clk;

end behavioral;
