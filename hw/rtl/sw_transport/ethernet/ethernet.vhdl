library util;
    use util.audio.all;
    use util.types.all;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package ethernet is

    -- Reduced Media-Independent Interface (RMII) implements 100Mbps
    -- ethernet by presenting dibits (2-bit sequences) on the rising
    -- edge of a 50MHz reference clock
    subtype Dibit_t is std_logic_vector(1 downto 0);

    -- Preamble & Start Frame Delimiter (PSFD)
    constant PSFD_SIZE       : natural := 8;
    constant PSFD_LAST_DIBIT : natural := (PSFD_SIZE * DIBITS_PER_BYTE) - 1;
    constant PSFD_VALID_DIBIT_REST : Dibit_t := "01";
    constant PSFD_VALID_DIBIT_LAST : Dibit_t := "11";

    -- Destination MAC & Source MAC
    constant MAC_SIZE       : natural := 6;
    constant MAC_LAST_DIBIT : natural := (MAC_SIZE * DIBITS_PER_BYTE) - 1;
    subtype MacAddress_t is std_logic_vector(
        0 to (MAC_SIZE * BITS_PER_BYTE) - 1
    );
    constant MAC_ADDRESS_BROADCAST : MacAddress_t := (others => '1');
    constant MAC_ADDRESS_CCO       : MacAddress_t := X"123456789ABC";

    -- Length/Ethertype
    constant LENGTH_SIZE       : natural := 2;
    constant LENGTH_LAST_DIBIT : natural := (LENGTH_SIZE * DIBITS_PER_BYTE) - 1;
    subtype Length_t is unsigned(
        0 to (LENGTH_SIZE * BITS_PER_BYTE) - 1
    );

    -- Frame Check Sequence (FCS)
    constant FCS_SIZE       : natural := 4;
    constant FCS_LAST_DIBIT : natural := (FCS_SIZE * DIBITS_PER_BYTE) - 1;
    subtype CRC32_t is std_logic_vector(
        (FCS_SIZE * BITS_PER_BYTE) - 1 downto 0
    );
    constant CRC32_t_INIT : CRC32_t := (others => '1');
    subtype FCS_t is CRC32_t;

    -- Payload
    constant MIN_FRAME_SIZE   : natural := 64;
    constant MTU              : natural := 1500;
    constant MIN_PAYLOAD_SIZE : natural := MIN_FRAME_SIZE
                                           - (2 * MAC_SIZE)
                                           - LENGTH_SIZE
                                           - FCS_SIZE;
    constant MAX_PAYLOAD_SIZE : natural := MTU;
    subtype Payload_t is std_logic_vector(
        0 to (MAX_PAYLOAD_SIZE * BITS_PER_BYTE) - 1
    );

    -- Inter Packet Gap (IPG)
    constant IPG_SIZE       : natural := 12;
    constant IPG_LAST_DIBIT : natural := (IPG_SIZE * DIBITS_PER_BYTE) - 1;

    -- Frame type definitions
    type FrameSection_t is (
        DESTINATION_MAC,
        SOURCE_MAC,
        LENGTH,
        PAYLOAD,
        PADDING,
        FRAME_CHECK_SEQUENCE
    );
    type Frame_t is record
        dest_mac : MacAddress_t;
        src_mac  : MacAddress_t;
        length   : Length_t;
        payload  : Payload_t;
    end record;
    constant Frame_t_INIT : Frame_t := (
        dest_mac => (others => '0'),
        src_mac  => (others => '0'),
        length   => (others => '0'),
        payload  => (others => '0')
    );

    function get_dibit_pos(
        offset  : natural;
        section : FrameSection_t;
    ) return natural;

    -- Record for RX interface
    type EthernetRxPhy_t is record
        data   : Dibit_t;
        crs_dv : std_logic;
    end record;

    -- Record for TX interface
    type EthernetTxPhy_t is record
        data   : Dibit_t;
        enable : std_logic;
    end record;

    -- Record of ethernet PHY pins
    type EthernetPhyPins_t is record
        clkin  : std_logic;
        rx     : EthernetRxPhy_t;
        tx     : EthernetTxPhy_t;
    end record;

    -- View of ethernet PHY pins
    --
    -- Note: can be used as port in entity, preserves direction of each pin
    view EthernetPhy_t of EthernetPhyPins_t is
        clkin : out;
        rx    : in;
        tx    : out;
    end view;

    -- Ethernet sending/receiving
    component ethernet_trx is
        port (
            i_clk           : in   std_logic;
            phy             : view EthernetPhy_t;
            playback_writer : view PeriodFifo_Writer_t;
            capture_reader  : view PeriodFifo_Reader_t;
            o_streams       : out  Streams_t;
        );
    end component;

    -- Ethernet receiving
    component ethernet_rx is
        port (
            i_ref_clk : in  std_logic;
            phy       : in  EthernetRxPhy_t;
            o_frame   : out Frame_t;
            o_valid   : out std_logic;
        );
    end component;

    -- Ethernet sending
    component ethernet_tx is
        port (
            i_ref_clk : in  std_logic;
            phy       : out EthernetTxPhy_t;
            i_frame   : in  Frame_t;
            i_valid   : in  std_logic;
        );
    end component;

    -- Frame check sequence calculator
    component fcs_calculator is
        port (
            i_crc   : in  CRC32_t;
            i_dibit : in  Dibit_t;
            o_crc   : out CRC32_t;
            o_fcs   : out FCS_t;
        );
    end component;

end package ethernet;

package body ethernet is

    function get_dibit_pos(
        offset  : natural;
        section : FrameSection_t;
    ) return natural is
        variable byte : natural := 0;
        variable rest : natural := 0;
    begin
        if section /= FRAME_CHECK_SEQUENCE then
            byte := offset / DIBITS_PER_BYTE;
            rest := offset mod DIBITS_PER_BYTE;
            return (byte + 1) * BITS_PER_BYTE -
                       (rest + 1) * BITS_PER_DIBIT;
        else
            -- The frame check sequence is the only field in the ethernet
            -- frame whose bytes are transmitted msb -> lsb
            return 31 - (offset * BITS_PER_DIBIT);
        end if;
    end function;

end package body ethernet;
