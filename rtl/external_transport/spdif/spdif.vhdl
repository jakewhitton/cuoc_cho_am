library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package spdif is

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

    -- Receive S/PDIF data
    component spdif_rx is
        port (
            i_clk     : in  std_logic;
            i_spdif   : in  std_logic;
            o_valid   : out std_logic;
            o_channel : out std_logic;
            o_sample  : out std_logic_vector(23 downto 0);
            o_sclk    : out std_logic
        );
    end component;

    -- Spoof a stream of S/PDIF data
    component spdif_tx_spoof is
        port (
            i_clk   : in  std_logic;
            o_spdif : out std_logic
        );
    end component;

    subtype Spdif_Preamble_t is std_logic_vector(7 downto 0);
    constant B_PREAMBLE : Spdif_Preamble_t := "11101000";
    constant M_PREAMBLE : Spdif_Preamble_t := "11100010";
    constant W_PREAMBLE : Spdif_Preamble_t := "11100100";

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

end package spdif;
