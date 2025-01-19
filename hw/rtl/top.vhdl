library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library sw_transport;
    use sw_transport.all;

library external_transport;
    use external_transport.all;

library util;
    use util.all;

entity top is
    port (
        i_clk        : in   std_logic;
        i_spdif      : in   std_logic;
        o_spdif      : out  std_logic;
        ethernet_phy : view sw_transport.ethernet.Phy_t;
        o_leds       : out  std_logic_vector(15 downto 0)
    );
end top;

architecture structure of top is

    -- Intermediate signals for FIFO
    signal reader : util.audio.PeriodFifo_ReaderPins_t;
    signal writer : util.audio.PeriodFifo_WriterPins_t;

    -- Reader state
    signal period_out : util.audio.Period_t := util.audio.Period_t_INIT;

    -- Writer state
    constant CLKS_PER_SEC : natural             := 100000000;
    signal   counter      : natural             := 0;
    signal   value        : natural             := 0;
    signal   period_in    : util.audio.Period_t := util.audio.Period_t_INIT;

begin

    -- Ethernet transport
    --ethernet_trx : sw_transport.ethernet.ethernet_trx
    --    port map (
    --        i_clk  => i_clk,
    --        phy    => ethernet_phy,
    --        o_leds => o_leds
    --    );

    -- S/PDIF transport
    --spdif_trx : external_transport.spdif.spdif_trx
    --    port map (
    --        i_clk   => i_clk,
    --        i_spdif => i_spdif,
    --        o_spdif => o_spdif
    --    );

    -- Reader
    fifo_reader : process(reader.clk)
    begin
        if rising_edge(reader.clk) then
            if reader.empty = '0' then
                period_out <= reader.data;
                reader.enable <= '1';
            else
                reader.enable <= '0';
            end if;
        end if;
    end process;
    reader.clk <= i_clk;
    o_leds(15 downto 0) <= period_out(0)(29)(8 to 23);

    -- Writer
    fifo_writer : process(writer.clk)
    begin
        if rising_edge(writer.clk) then
            if counter < CLKS_PER_SEC then
                writer.enable <= '0';
                counter <= counter + 1;
            else
                if writer.full = '0' then
                    period_in(0)(29) <= std_logic_vector(to_unsigned(42, 24));
                    writer.enable <= '1';
                    counter <= 0;
                    value <= value + 1;
                end if;
            end if;
        end if;
    end process;
    writer.data <= period_in;
    writer.clk <= i_clk;

    fifo : util.audio.period_fifo
        port map (
            writer => writer,
            reader => reader
        );

end structure;
