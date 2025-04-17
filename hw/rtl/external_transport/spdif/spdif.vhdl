library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library sw_transport;
    use sw_transport.ethernet.all;

library util;
    use util.audio.all;

package spdif is

    -- Timing parameters:
    --
    -- Notes:
    --
    --   1. 'sclk' refers to the pulse that drives the transmit state machine.
    --
    --      It should pulse once in the middle of each bit and once at the end
    --      of each bit, which gives the opportunity to trigger signal
    --      transitions when needed.
    --
    --   2. These measurements are derived from the observed output of a Scarlett
    --      18i8 S/PDIF coax output, which is successfully read by the corresponding
    --      S/PDIF coax input also present on the card
    --
    constant SAMPLE_RATE        : real    := 48000.0;
    constant SCLK_PERIOD_NS     : real    := 0.5               * -- (0.5 bit)
                                             (1.0/64.0)        * -- (1 sample/64 bit)
                                             (1.0/SAMPLE_RATE) * -- (1s/480000 sample)
                                             1000000000.0;       -- (10^9 ns/s)
    constant CLK_PERIOD_NS      : real    := 81.38;
    constant SCLK_PERIOD_CYCLES : natural := natural(ROUND(SCLK_PERIOD_NS / CLK_PERIOD_NS));

    -- S/PDIF Preamble
    --
    -- Notes:
    --
    --   1. Consumes 4 "bits" of time
    --
    --   2. Bits are "unencoded" and have signal transitions at pre-defined
    --      locations rather than only having one at the end for a "0" and having
    --      two for a "1".
    --
    subtype Spdif_Preamble_t is std_logic_vector(0 to 7);
    constant B_PREAMBLE             : Spdif_Preamble_t := "11101000";
    constant B_PREAMBLE_TRANSITIONS : Spdif_Preamble_t := "10011100";
    constant M_PREAMBLE             : Spdif_Preamble_t := "11100010";
    constant M_PREAMBLE_TRANSITIONS : Spdif_Preamble_t := "10010011";
    constant W_PREAMBLE             : Spdif_Preamble_t := "11100100";
    constant W_PREAMBLE_TRANSITIONS : Spdif_Preamble_t := "10010110";

    -- One frame consists of two 32-bit subframes
    --
    -- Each subframe consists of:
    --   1. Preamble:  4 bits, 4 signal transitions
    --   2. Data:     28 bits, 1-2 signal transitions per bit
    --
    -- Therefore, the max number of signal transitions that could occur during
    -- one frame is 2 * (4 + (28 * 2)) => 120
    --
    -- Thus, if we survey min distance between signal transitions for 120
    -- signal transitions, we are guaranteed to hit at least one contiguous
    -- preamble (which contains the shortest-length pulse reliably even if data
    -- bits are all '0').
    constant MAX_TRANSITIONS_IN_FRAME : unsigned := to_unsigned(120, 7);

    -- Subframe struct
    type Subframe_t is record
        aux     : std_logic_vector(0 to 3);
        data    : std_logic_vector(0 to 19);
        valid   : std_logic;
        user    : std_logic;
        channel : std_logic;
    end record Subframe_t;
    constant Subframe_t_INIT : Subframe_t := (
        aux     => "1000",
        data    => "00000000000000000000",
        valid   => '0',
        user    => '0',
        channel => '0'
    );
    constant Subframe_t_SQUARE_WAVE_LOW : Subframe_t := (
        aux     => "0000",
        data    => "00000000000000000111",
        valid   => '0',
        user    => '0',
        channel => '0'
    );
    constant Subframe_t_SQUARE_WAVE_HIGH : Subframe_t := (
        aux     => "1111",
        data    => "11111111111111111000",
        valid   => '0',
        user    => '0',
        channel => '0'
    );

    -- Bit boundaries for subframe sections
    --
    -- Preamble
    constant FIRST_PREAMBLE_BIT : natural := 0;
    constant LAST_PREAMBLE_BIT  : natural := 3;
    --
    -- Auxiliary bits
    constant FIRST_AUX_BIT      : natural := 4;
    constant LAST_AUX_BIT       : natural := 7;
    --
    -- Data bits
    constant FIRST_DATA_BIT     : natural := 8;
    constant LAST_DATA_BIT      : natural := 27;
    --
    -- Status:
    constant FIRST_STATUS_BIT   : natural := 28;
    constant LAST_STATUS_BIT    : natural := 31;
    constant STATUS_BIT_VALID   : natural := FIRST_STATUS_BIT;
    constant STATUS_BIT_USER    : natural := 29;
    constant STATUS_BIT_CHANNEL : natural := 30;
    constant STATUS_BIT_PARITY  : natural := LAST_STATUS_BIT;

    type SpdifPhyPins_t is record
        rx : std_logic;
        tx : std_logic;
    end record;

    view SpdifPhy_t of SpdifPhyPins_t is
        rx : in;
        tx : out;
    end view;

    -- Component for reading data from S/PDIF (reference implementation)
    component spdif_rx_serial_bridge is
        generic (
            -- Registers width, determines minimal baud speed of input AES3 at given master clock frequency
            reg_width : integer := 5
        );
        port (
            -- Master clock
            clk   : in  std_logic;
            -- AES3/SPDIF compatible input signal
            aes3  : in  std_logic; 
            -- Synchronous reset
            reset : in  std_logic; 
            -- Serial data out
            sdata : out std_logic := '0'; -- output serial data
            -- AES3 clock out
            sclk  : out std_logic := '0'; -- output serial data clock
            -- Block start (asserted when Z subframe is being transmitted)
            bsync : out std_logic := '0'; 
            -- Frame sync (asserted for channel A, negated for B)
            lrck  : out std_logic := '0'; 
            -- Receiver has (probably) valid data on its outputs
            active: out std_logic := '0'
        );
    end component;

    -- Loopback S/PDIF data
    component spdif_loopback is
        port (
            i_clk   : in  std_logic;
            i_spdif : in  std_logic;
            o_spdif : out std_logic
        );
    end component;

    -- Transmit S/PDIF data
    component spdif_tx is
        port (
            i_clk    : in   std_logic;
            i_active : in   std_logic;
            reader   : view PeriodFifo_Reader_t;
            o_spdif  : out  std_logic;
        );
    end component;

    -- Receive S/PDIF data
    component spdif_rx is
        port (
            i_clk    : in   std_logic;
            i_spdif  : in   std_logic;
            i_active : in   std_logic;
            writer   : view PeriodFifo_Writer_t;
            o_sclk   : out  std_logic;
        );
    end component;

    -- Transmit and receive S/PDIF data
    component spdif_trx is
        port (
            i_clk           : in   std_logic;
            i_streams       : in   Streams_t;
            playback_reader : view PeriodFifo_Reader_t;
            capture_writer  : view PeriodFifo_Writer_t;
            phy             : view SpdifPhy_t;
        );
    end component;

    -- Spoof a stream of S/PDIF data
    component spdif_tx_spoof is
        port (
            i_clk   : in  std_logic;
            o_spdif : out std_logic
        );
    end component;

end package spdif;
