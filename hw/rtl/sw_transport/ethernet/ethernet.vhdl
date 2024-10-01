library ieee;
    use ieee.std_logic_1164.all;

package ethernet is

    type EthernetPhyPins_t is record
        clkin   : std_logic;
        rxd     : std_logic_vector(1 downto 0);
        crs_dv  : std_logic;
    end record;

    view EthernetPhy_t of EthernetPhyPins_t is
        clkin  : out;
        rxd    : in;
        crs_dv : in;
    end view;

    constant BITS_PER_DIBIT      : natural := 2;
    constant DIBITS_PER_BYTE     : natural := 4;
    constant BITS_PER_BYTE       : natural := DIBITS_PER_BYTE * BITS_PER_DIBIT;
    constant PREAMBLE_LAST_DIBIT : natural := (7 * DIBITS_PER_BYTE) - 1;
    constant SFD_LAST_DIBIT      : natural := (1 * DIBITS_PER_BYTE) - 1;

    constant VALID_PREAMBLE_DIBIT : std_logic_vector(1 downto 0) := "01";
    constant VALID_SFD_DIBIT_REST : std_logic_vector(1 downto 0) := "01";
    constant VALID_SFD_DIBIT_LAST : std_logic_vector(1 downto 0) := "11";

    constant MTU : natural := 1500;
    subtype EthernetPacket_t is std_logic_vector(0 to (MTU * BITS_PER_BYTE) - 1);

    component ethernet_trx is
        port (
            i_clk  : in   std_logic;
            phy    : view EthernetPhy_t;
            o_leds : out  std_logic_vector(15 downto 0);
        );
    end component;

    component ethernet_rx is
        port (
            i_ref_clk : in   std_logic;
            phy       : view EthernetPhy_t;
            o_packet  : out  EthernetPacket_t;
            o_size    : out  natural;
            o_valid   : out  std_logic;
        );
    end component;

end package ethernet;