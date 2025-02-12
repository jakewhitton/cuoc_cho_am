library work;
    use work.audio.all;
    use work.types.all;

library ieee;
    use ieee.std_logic_1164.all;
    
entity period_fifo is
    port (
        writer : view PeriodFifo_WriterDriver_t;
        reader : view PeriodFifo_ReaderDriver_t;
    );
end period_fifo;

architecture behavioral of period_fifo is

    constant SUBPERIOD_WIDTH       : natural := 768;
    constant SUBPERIODS_PER_PERIOD : natural := 8;
    constant SAMPLES_PER_SUBPERIOD : natural := (NUM_CHANNELS * PERIOD_SIZE) /
                                                SUBPERIODS_PER_PERIOD;

    -- Underlying FIFO IP that we rely on for transport
    subtype Subperiod_t is std_logic_vector(SUBPERIOD_WIDTH - 1 downto 0);
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
        WRITE_INTO_FIFO,
        READ_CLEANUP
    );
    signal read_state         : ReadPeriodState_t := WAIT_FOR_PERIOD_GIVEN;
    signal subperiods_written : natural           := 0;
    signal period_in          : Period_t          := Period_t_INIT;

    -- Write state
    type WritePeriodState_t is (
        WAIT_FOR_FIFO_DATA,
        READ_FROM_FIFO,
        WAIT_FOR_PERIOD_TAKEN
    );
    signal write_state     : WritePeriodState_t := WAIT_FOR_FIFO_DATA;
    signal subperiods_read : natural            := 0;

    type Offsets_t is record
        channel : natural;
        sample  : natural;
    end record;

    function get_offsets(
        subperiods : natural;
    ) return Offsets_t is
        variable channel : natural := 0;
        variable sample  : natural := 0;
    begin
        if subperiods < (SUBPERIODS_PER_PERIOD / 2) then
            channel := 0;
        else
            channel := 1;
        end if;

        sample := (subperiods mod (SUBPERIODS_PER_PERIOD / 2)) *
                  SAMPLES_PER_SUBPERIOD;

        return (
            channel => channel,
            sample  => sample
        );
    end function get_offsets;
    
begin

    read_sm : process(writer.clk)
        variable offsets : Offsets_t;
    begin
        if rising_edge(writer.clk) then
            case read_state is
            when WAIT_FOR_PERIOD_GIVEN =>
                -- Wait for user to present new period, save it, then transit
                if writer.enable = '1' then
                    period_in <= writer.data;
                    subperiods_written <= 0;
                    read_state <= WRITE_INTO_FIFO;
                end if;

            when WRITE_INTO_FIFO =>
                if fifo_full = '0' then
                    -- Write subperiod into FIFO
                    offsets := get_offsets(subperiods_written);
                    for i in 0 to SAMPLES_PER_SUBPERIOD - 1 loop
                        fifo_din(
                            (SAMPLE_SIZE * BITS_PER_BYTE * (i + 1)) - 1
                            downto (SAMPLE_SIZE * BITS_PER_BYTE * i)
                        ) <= period_in(offsets.channel)(offsets.sample + i);
                    end loop;
                    fifo_wr_en <= '1';

                    -- Wait until final subperiod is written, then transit
                    if subperiods_written + 1 < SUBPERIODS_PER_PERIOD then
                        subperiods_written <= subperiods_written + 1;
                    else
                        read_state <= READ_CLEANUP;
                    end if;
                else
                    fifo_wr_en <= '0';
                end if;

            when READ_CLEANUP =>
                -- Burn cycle completing previously initiated write & transit
                fifo_wr_en <= '0';
                read_state <= WAIT_FOR_PERIOD_GIVEN;
            end case;
        end if;
    end process;
    writer.full <= '0' when read_state = WAIT_FOR_PERIOD_GIVEN else '1';

    write_sm : process(reader.clk)
        variable offsets : Offsets_t;
    begin
        if rising_edge(reader.clk) then
            case write_state is
            when WAIT_FOR_FIFO_DATA =>
                -- Wait for data to be present, then burn cycle initiating read
                if fifo_empty = '0' then
                    fifo_rd_en <= '1';
                    write_state <= READ_FROM_FIFO;
                end if;

            when READ_FROM_FIFO =>
                -- Read subperiod from FIFO
                offsets := get_offsets(subperiods_read);
                for i in 0 to SAMPLES_PER_SUBPERIOD - 1 loop
                    reader.data(offsets.channel)(offsets.sample + i)
                        <= fifo_dout(
                            (SAMPLE_SIZE * BITS_PER_BYTE * (i + 1)) - 1
                            downto (SAMPLE_SIZE * BITS_PER_BYTE * i)
                        );
                end loop;

                -- Otherwise, wait until final subperiod is read, then transit
                if subperiods_read + 1 < SUBPERIODS_PER_PERIOD then
                    subperiods_read <= subperiods_read + 1;

                    -- If no more data is available, go back to waiting for data
                    if fifo_empty = '0' then
                        fifo_rd_en <= '0';
                        write_state <= WAIT_FOR_FIFO_DATA;
                    end if;
                else
                    fifo_rd_en <= '0';
                    write_state <= WAIT_FOR_PERIOD_TAKEN;
                end if;

            when WAIT_FOR_PERIOD_TAKEN =>
                if reader.enable = '0' then
                    subperiods_read <= 0;
                    write_state <= WAIT_FOR_FIFO_DATA;
                end if;
            end case;
        end if;
    end process;
    reader.empty <= '0' when write_state = WAIT_FOR_PERIOD_TAKEN else '1';

    -- Underlying FIFO IP instance
    fifo : ip_sample_fifo
        port map (
            rst         => fifo_rst,
            wr_clk      => fifo_wr_clk,
            rd_clk      => fifo_rd_clk,
            din         => fifo_din,
            wr_en       => fifo_wr_en,
            rd_en       => fifo_rd_en,
            dout        => fifo_dout,
            full        => fifo_full,
            empty       => fifo_empty,
            wr_rst_busy => fifo_wr_rst_busy,
            rd_rst_busy => fifo_rd_rst_busy
        );
    fifo_wr_clk <= writer.clk;
    fifo_rd_clk <= reader.clk;

end behavioral;
