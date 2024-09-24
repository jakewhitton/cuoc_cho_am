library ieee;
    use ieee.std_logic_1164.all;

package ethernet is

    type EthernetPhyPins_t is record
        clkin   : std_logic;
        rxd     : std_logic_vector(0 to 1);
        crs_dv  : std_logic;
    end record;

    view EthernetPhy_t of EthernetPhyPins_t is
        clkin  : out;
        rxd    : in;
        crs_dv : in;
    end view;

    component ethernet_trx is
        port (
            i_clk : in   std_logic;
            phy   : view EthernetPhy_t;
        );
    end component;

end package ethernet;
