library ieee;
    use ieee.std_logic_1164.all;

library sw_transport;
    use sw_transport.all;

library external_transport;
    use external_transport.spdif.all;

library work;
    use work.ip.all;

entity top is
    port (
        i_clk   : in  std_logic;
        i_spdif : in  std_logic;
        o_spdif : out std_logic;
        o_leds  : out std_logic_vector(15 downto 0)
    );
end top;

architecture structure of top is

    --signal valid   : std_logic                     := '0';
    --signal channel : std_logic                     := '0';
    --signal sample  : std_logic_vector(23 downto 0) := (others => '0');
    --signal sclk    : std_logic                     := '0';

    signal spdif_tx_clk      : std_logic  := '0';
    signal spdif_tx_subframe : Subframe_t := Subframe_t_EXAMPLE;
    signal spdif_tx_enable   : std_logic  := '1';

begin
    -- S/PDIF receiver
    --spdif_rx : external_transport.spdif.spdif_rx
    --    port map (
    --        i_clk     => i_clk,
    --        i_spdif   => i_spdif,
    --        o_valid   => valid,
    --        o_channel => channel,
    --        o_sample  => sample,
    --        o_sclk    => sclk
    --    );

    generate_spdif_tx_clk : work.ip.pll
        port map (
            o_spdif_tx_clk => spdif_tx_clk,
            reset          => '0',
            locked         => open,
            i_clk          => i_clk
        );

    -- S/PDIF transmitter
    spdif_tx : external_transport.spdif.spdif_tx
        port map (
            i_clk      => spdif_tx_clk,
            i_subframe => spdif_tx_subframe,
            i_enable   => spdif_tx_enable,
            o_spdif    => o_spdif
        );

end structure;
