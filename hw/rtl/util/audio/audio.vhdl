library work;
    use work.types.all;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package audio is

    constant SAMPLE_SIZE : natural := 3;
    subtype Sample_t is std_logic_vector(0 to (SAMPLE_SIZE * BITS_PER_BYTE) - 1);
    constant Sample_t_INIT : Sample_t := (others => '0');

    constant PERIOD_SIZE : natural := 128;
    type ChannelPcmData_t is array (0 to PERIOD_SIZE - 1) of Sample_t;
    constant ChannelPcmData_t_INIT : ChannelPcmData_t := (others => Sample_t_INIT);

    constant NUM_CHANNELS : natural := 2;
    type Period_t is array (0 to NUM_CHANNELS - 1) of ChannelPcmData_t;
    constant Period_t_INIT : Period_t := (others => ChannelPcmData_t_INIT);

    type PeriodFifo_WriterPins_t is record
        clk    : std_logic;
        full   : std_logic;
        enable : std_logic;
        data   : Period_t;
    end record;

    view PeriodFifo_Writer_t of PeriodFifo_WriterPins_t is
        clk    : out;
        full   : in;
        enable : out;
        data   : out;
    end view;

    view PeriodFifo_WriterDriver_t of PeriodFifo_WriterPins_t is
        clk    : in;
        full   : out;
        enable : in;
        data   : in;
    end view;

    type PeriodFifo_ReaderPins_t is record
        clk    : std_logic;
        empty  : std_logic;
        enable : std_logic;
        data   : Period_t;
    end record;

    view PeriodFifo_Reader_t of PeriodFifo_ReaderPins_t is
        clk    : out;
        empty  : in;
        enable : out;
        data   : in;
    end view;

    view PeriodFifo_ReaderDriver_t of PeriodFifo_ReaderPins_t is
        clk    : in;
        empty  : out;
        enable : in;
        data   : out;
    end view;

    -- Transport whole periods of PCM data
    component period_fifo is
        port (
            writer : view PeriodFifo_WriterDriver_t;
            reader : view PeriodFifo_ReaderDriver_t;
        );
    end component;

end package audio;
