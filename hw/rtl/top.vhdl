library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library sw_transport;
    use sw_transport.ethernet.all;

library external_transport;
    use external_transport.spdif.all;

library util;
    use util.audio.all;

entity top is
    port (
        i_clk        : in   std_logic;
        ethernet_phy : view EthernetPhy_t;
        spdif_phy    : view SpdifPhy_t;
        o_leds       : out  std_logic_vector(15 downto 0)
    );
end top;

architecture structure of top is

    signal streams : Streams_t := Streams_t_INIT;

    -- Intermediate signals for playback FIFO
    signal playback_reader : PeriodFifo_ReaderPins_t;
    signal playback_writer : PeriodFifo_WriterPins_t;

    -- Intermediate signals for capture FIFO
    signal capture_reader : PeriodFifo_ReaderPins_t;
    signal capture_writer : PeriodFifo_WriterPins_t;

begin

    -- Ethernet transport
    ethernet_trx : sw_transport.ethernet.ethernet_trx
        port map (
            i_clk           => i_clk,
            phy             => ethernet_phy,
            playback_writer => playback_writer,
            capture_reader  => capture_reader,
            o_streams       => streams
        );

    -- Playback sample transport
    playback_period_fifo : util.audio.period_fifo
        port map (
            writer => playback_writer,
            reader => playback_reader
        );

    -- Capture sample transport
    --capture_period_fifo : util.audio.period_fifo
    --    port map (
    --        writer => capture_writer,
    --        reader => capture_reader
    --    );
    capture_reader.empty <= '1';
    capture_reader.data <= Period_t_INIT;

    -- S/PDIF transport
    spdif_trx : external_transport.spdif.spdif_trx
        port map (
            i_clk           => i_clk,
            i_streams       => streams,
            playback_reader => playback_reader,
            capture_writer  => capture_writer,
            phy             => spdif_phy
        );

    -- Loopback playback -> capture
    --loopback : util.audio.period_loopback
    --    port map (
    --        i_clk     => i_clk,
    --        i_streams => streams,
    --        reader    => playback_reader,
    --        writer    => capture_writer
    --    );

    o_leds(15 downto 0) <= (others => '0');

end structure;
