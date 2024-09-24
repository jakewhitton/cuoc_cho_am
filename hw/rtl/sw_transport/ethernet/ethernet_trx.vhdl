library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.ethernet.all;

entity ethernet_trx is
    port (
        i_clk : in   std_logic;
        phy   : view EthernetPhy_t;
    );
end ethernet_trx;

architecture behavioral of ethernet_trx is
    signal ref_clk : std_logic := '0';
begin
    phy.clkin <= ref_clk;
end behavioral;
