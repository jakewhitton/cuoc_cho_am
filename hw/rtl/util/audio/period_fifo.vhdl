library ieee;
    use ieee.std_logic_1164.all;
    
entity period_fifo is
    port (
        writer : view PeriodFifo_Writer_t;
        reader : view PeriodFifo_Reader_t;
    );
end period_fifo;

architecture behavioral of period_fifo is

    -- Underlying FIFO IP that we rely on for transport
    constant SUBPERIOD_WIDTH       : natural := 768;
    constant SUBPERIODS_PER_PERIOD : natural := 8;
    type Subperiod_t is std_logic_vector(SUBPERIOD_WIDTH - 1 downto 0);
    component ip_sample_fifo is
        port (
            rst         : in  std_logic;
            wr_clk      : in  std_logic;
            rd_clk      : in  std_logic;
            din         : in  Subperiod_t;
            wr_en       : in  std_logic;
            rd_en       : in  std_logic;
            dout        : out Subperiod_t;
            full        : out std_logic;
            empty       : out std_logic;
            wr_rst_busy : out std_logic;
            rd_rst_busy : out std_logic;
        );
    end component;

    -- Intermediate signals for FIFO IP
    signal fifo_rst         : std_logic   := '0';
    signal fifo_wr_clk      : std_logic   := '0';
    signal fifo_rd_clk      : std_logic   := '0';
    signal fifo_din         : Subperiod_t := (others => '0');
    signal fifo_wr_en       : std_logic   := '0';
    signal fifo_rd_en       : std_logic   := '0';
    signal fifo_dout        : Subperiod_t := (others => '0');
    signal fifo_full        : std_logic   := '0';
    signal fifo_empty       : std_logic   := '0';
    signal fifo_wr_rst_busy : std_logic   := '0';
    signal fifo_rd_rst_busy : std_logic   := '0';

    -- Read state
    type ReadPeriodState_t is (
        WAIT_FOR_PERIOD_GIVEN,
        WRITE_INTO_FIFO
    );
    signal read_period_state  : ReadPeriodState_t := WAIT_FOR_PERIOD_GIVEN;
    signal subperiods_written : natural           := 0;

    -- Write state
    type WritePeriodState_t is (
        READ_FROM_FIFO,
        WAIT_FOR_PERIOD_TAKEN
    );
    signal write_period_state : WritePeriodState_t := READ_FROM_FIFO;
    signal subperiods_read    : natural            := 0;
    
begin

    -- Underlying FIFO IP instance
    fifo : ip_sample_fifo
        port map (
            rst         => fifo_rst,
            wr_clk      => writer.clk,
            rd_clk      => reader.clk,
            din         => fifo_din,
            wr_en       => fifo_wr_en,
            rd_en       => fifo_rd_en,
            dout        => fifo_dout,
            full        => fifo_full,
            empty       => fifo_empty,
            wr_rst_busy => fifo_wr_rst_busy,
            rd_rst_busy => fifo_rd_rst_busy
        );

    read_sm : process(reader.clk)
    begin
        if rising_edge(reader.clk) then
            case state is
            when WAIT_FOR_PERIOD_GIVEN =>
                -- TODO
            when WRITE_INTO_FIFO =>
                if fifo_full = '0' then
                    -- TODO
                end if;
            end case;
        end if;
    end process;

end behavioral;
