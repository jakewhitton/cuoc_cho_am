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

    signal spdif_phy_rx : std_logic := '0';

begin

    spdif_phy_rx <= spdif_phy.rx;

    -- S/PDIF status bit dumper
    status_bit_dumper : external_transport.spdif.spdif_status_bit_dumper
        port map (
            i_clk        => i_clk,
            i_spdif      => spdif_phy_rx,
            ethernet_phy => ethernet_phy
        );

end structure;
