library work;
    use work.audio.all;
    use work.types.all;

library ieee;
    use ieee.std_logic_1164.all;

entity period_loopback is
    port (
        i_clk  : in   std_logic;
        reader : view PeriodFifo_Reader_t;
        writer : view PeriodFifo_Writer_t;
    );
end period_loopback;

architecture behavioral of period_loopback is

    -- Period tracking state
    signal counter      : natural   := 0;
    signal begin_period : std_logic := '0';

    -- Loopback state
    signal loopback_period : Period_t := Period_t_INIT;

begin

    -- Generate a 375Hz, single cycle pulse to mark the beginning of each period
    track_periods : process(i_clk)
    begin
        if rising_edge(i_clk) then
            with counter select
                begin_period <= '1' when 0,
                                '0' when others;

            if counter < 266666 then
                counter <= counter + 1;
            else
                counter <= 0;
            end if;
        end if;
    end process;

    loopback : process(i_clk)
    begin
        if rising_edge(i_clk) then
            -- Will be overwritten later if necessary
            reader.enable <= '0';
            writer.enable <= '0';

            if begin_period = '1' and writer.full = '0' then
                if reader.empty = '0' then
                    loopback_period <= reader.data;
                    reader.enable <= '1';
                else
                    loopback_period <= Period_t_INIT;
                end if;

                writer.enable <= '1';
            end if;
        end if;
    end process;
    reader.clk <= i_clk;
    writer.clk <= i_clk;
    writer.data <= loopback_period;

end behavioral;
