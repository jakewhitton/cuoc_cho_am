library ieee;
    use ieee.std_logic_1164.all;

library sw_transport;
    use sw_transport.ethernet.all;

library util;
    use util.audio.all;

library work;
    use work.spdif.all;

entity spdif_trx is
    port (
        i_clk           : in   std_logic;
        i_streams       : in   Streams_t;
        playback_reader : view PeriodFifo_Reader_t;
        capture_writer  : view PeriodFifo_Writer_t;
        phy             : view SpdifPhy_t;
    );
end spdif_trx;

architecture behavioral of spdif_trx is

    -- TX clk generation
    component ip_clk_wizard_spdif
        port (
            i_spdif_clk : in  std_logic;
            o_spdif_clk : out std_logic;
        );
    end component;
    signal spdif_tx_clk : std_logic := '0';

    -- Intermediate signals
    signal phy_rx : std_logic := '0';
    signal phy_tx : std_logic := '0';
    signal reader : PeriodFifo_ReaderPins_t;
    signal writer : PeriodFifo_WriterPins_t;

begin

    phy_rx <= phy.rx;
    phy.tx <= phy_tx;

    playback_reader.clk    <= reader.clk;
    reader.empty           <= playback_reader.empty;
    playback_reader.enable <= reader.enable;
    reader.data            <= playback_reader.data;

    capture_writer.clk    <= writer.clk;
    writer.full           <= capture_writer.full;
    capture_writer.enable <= reader.enable;
    capture_writer.data   <= writer.data;

    -- Generate SPDIF tx clk
    generate_spdif_tx_clk : ip_clk_wizard_spdif
        port map (
            i_spdif_clk => i_clk,
            o_spdif_clk => spdif_tx_clk
        );

    -- S/PDIF transmitter
    spdif_tx : work.spdif.spdif_tx
        port map (
            i_clk    => spdif_tx_clk,
            i_active => i_streams.playback.active,
            reader   => reader,
            o_spdif  => phy_tx
        );

    -- S/PDIF receiver
    --spdif_rx : work.spdif.spdif_rx
    --    port map (
    --        i_clk    => i_clk,
    --        i_spdif  => phy_rx,
    --        i_active => i_streams.capture.active,
    --        writer   => writer,
    --        o_sclk   => sclk
    --    );
    writer.clk <= i_clk;
    writer.enable <= '0';
    writer.data <= Period_t_INIT;

end behavioral;
