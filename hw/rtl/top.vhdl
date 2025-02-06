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

    -- Intermediate signals for playback FIFO
    signal playback_reader : PeriodFifo_ReaderPins_t;
    signal playback_writer : PeriodFifo_WriterPins_t;

    -- Intermediate signals for capture FIFO
    signal capture_reader : PeriodFifo_ReaderPins_t;
    --signal capture_writer : PeriodFifo_WriterPins_t;

begin

    -- Ethernet transport
    ethernet_trx : sw_transport.ethernet.ethernet_trx
        port map (
            i_clk           => i_clk,
            phy             => ethernet_phy,
            playback_writer => playback_writer,
            capture_reader  => capture_reader,
            o_leds          => o_leds
        );

    -- S/PDIF transport
    --spdif_trx : external_transport.spdif.spdif_trx
    --    port map (
    --        i_clk   => i_clk,
    --        i_spdif => i_spdif,
    --        o_spdif => o_spdif
    --    );

    playback_period_fifo : util.audio.period_fifo
        port map (
            writer => playback_writer,
            reader => playback_reader
        );

    -- For now, simply loopback playback data into capture for testing
    capture_reader <= playback_reader;

end structure;
