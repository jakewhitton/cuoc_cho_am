library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.ethernet.all;

entity ethernet_trx is
    port (
        i_clk  : in   std_logic;
        phy    : view Phy_t;
        o_leds : out  std_logic_vector(15 downto 0);
    );
end ethernet_trx;

architecture behavioral of ethernet_trx is

    -- 50MHz reference clk that drives ethernet PHY
    signal ref_clk : std_logic := '0';

    -- Intermediate signals for ethernet_rx
    signal rx_packet : EthernetPacket_t := (others => '0');
    signal rx_size   : natural          := 0;
    signal rx_fcs    : EthernetFCS_t    := (others => '0');
    signal rx_valid  : std_logic        := '0';

    component ip_clk_wizard_ethernet is
        port (
            i_eth_clk : in  std_logic;
            o_eth_clk : out std_logic;
        );
    end component;

begin

    -- Derives 50MHz clk from 100MHz clk for feeding into PHY
    generate_50mhz_ref_clk : ip_clk_wizard_ethernet
        port map (
            i_eth_clk => i_clk,
            o_eth_clk => ref_clk
        );
    phy.clkin <= ref_clk;

    -- Ethernet receiving
    ethernet_rx : work.ethernet.ethernet_rx
        port map (
            i_ref_clk => ref_clk,
            phy       => phy,
            o_packet  => rx_packet,
            o_size    => rx_size,
            o_valid   => rx_valid
        );

    -- Ethernet transmitting (loopback of data from ethernet_rx)
    ethernet_tx : work.ethernet.ethernet_tx
        port map (
            i_ref_clk => ref_clk,
            phy       => phy,
            i_packet  => rx_packet,
            i_size    => rx_size,
            i_valid   => rx_valid
        );

end behavioral;
