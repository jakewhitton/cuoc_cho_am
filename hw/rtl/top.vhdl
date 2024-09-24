library ieee;
    use ieee.std_logic_1164.all;

library sw_transport;
    use sw_transport.all;

library external_transport;
    use external_transport.all;

entity top is
    port (
        i_clk   : in  std_logic;
        i_spdif : in  std_logic;
        o_spdif : out std_logic;
        o_leds  : out std_logic_vector(15 downto 0)
    );
end top;

architecture structure of top is
begin

    -- S/PDIF transport
    spdif_trx : external_transport.spdif.spdif_trx
        port map (
            i_clk   => i_clk,
            i_spdif => i_spdif,
            o_spdif => o_spdif
        );

end structure;
