library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library sw_transport;
    use sw_transport.all;

library external_transport;
    use external_transport.all;

library util;
    use util.audio.all;

entity top is
    port (
        i_clk        : in   std_logic;
        i_spdif      : in   std_logic;
        o_spdif      : out  std_logic;
        ethernet_phy : view sw_transport.ethernet.Phy_t;
        o_leds       : out  std_logic_vector(15 downto 0)
    );
end top;

architecture structure of top is

    -- Reader state
    signal period : Period_t := Period_t_INIT;
    signal counter : natural := 0;

    -- Intermediate signals for playback FIFO
    signal playback_reader : PeriodFifo_ReaderPins_t;
    signal playback_writer : PeriodFifo_WriterPins_t;

begin

    -- Ethernet transport
    ethernet_trx : sw_transport.ethernet.ethernet_trx
        port map (
            i_clk  => i_clk,
            phy    => ethernet_phy,
            writer => playback_writer,
            o_leds => o_leds
        );

    -- S/PDIF transport
    --spdif_trx : external_transport.spdif.spdif_trx
    --    port map (
    --        i_clk   => i_clk,
    --        i_spdif => i_spdif,
    --        o_spdif => o_spdif
    --    );

    -- Reader
    fifo_reader : process(playback_reader.clk)
    begin
        if rising_edge(playback_reader.clk) then
            if playback_reader.empty = '0' then
                period <= playback_reader.data;
                playback_reader.enable <= '1';

                -- Display sample on LEDs if nonzero
                for channel in 0 to NUM_CHANNELS - 1 loop
                    for sample in 0 to PERIOD_SIZE - 1 loop
                        if unsigned(playback_reader.data(channel)(sample)) > 0 then
                            counter <= counter + 1;
                        end if;
                    end loop;
                end loop;
            else
                playback_reader.enable <= '0';
            end if;
        end if;
    end process;
    playback_reader.clk <= i_clk;

    playback_period_fifo : util.audio.period_fifo
        port map (
            writer => playback_writer,
            reader => playback_reader
        );

end structure;
