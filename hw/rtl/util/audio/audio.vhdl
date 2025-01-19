library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package audio is

    constant PERIOD_SIZE : natural := 128;
    constant SAMPLE_SIZE : natural := 3;

    type Period_t is record
        -- TODO
    end record;

    type PeriodFifo_WriterPins_t is record
        clk    : std_logic;
        full   : std_logic;
        enable : std_logic;
        data   : Period_t;
    end record;

    view PeriodFifo_Writer_t of PeriodFifo_WriterPins_t is
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
        clk    : in;
        full   : out;
        enable : in;
        data   : in;
    end view;

    -- Transport whole periods of PCM data
    component period_fifo is
        port (
            writer : view PeriodFifo_Writer_t;
            reader : view PeriodFifo_Reader_t;
        );
    end component;

end package audio;
