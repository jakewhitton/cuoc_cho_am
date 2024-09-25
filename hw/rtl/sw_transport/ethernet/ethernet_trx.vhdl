library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.ethernet.all;

entity ethernet_trx is
    port (
        i_clk  : in   std_logic;
        phy    : view EthernetPhy_t;
        o_leds : out  std_logic_vector(15 downto 0);
    );
end ethernet_trx;

architecture behavioral of ethernet_trx is

    -- 50MHz reference clk that drives ethernet PHY
    signal ref_clk : std_logic := '0';

begin

    -- Derives 50MHz clk from 100MHz clk for feeding into PHY
    generate_50mhz_ref_clk : process(i_clk)
    begin
        if rising_edge(i_clk) then
            ref_clk <= not ref_clk;
        end if;
    end process;
    phy.clkin <= ref_clk;

    -- Ethernet receiving
    ethernet_rx : work.ethernet.ethernet_rx
        port map (
            i_ref_clk => ref_clk,
            phy       => phy,
            o_leds    => o_leds
        );

end behavioral;
