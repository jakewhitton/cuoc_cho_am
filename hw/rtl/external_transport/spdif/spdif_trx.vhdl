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

begin

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
            reader   => playback_reader,
            o_spdif  => phy.tx
        );

    -- S/PDIF receiver
    --spdif_rx : work.spdif.spdif_rx
    --    port map (
    --        i_clk    => i_clk,
    --        i_spdif  => phy.rx,
    --        i_active => i_streams.capture.active,
    --        writer   => capture_writer,
    --        o_sclk   => sclk
    --    );

end behavioral;
