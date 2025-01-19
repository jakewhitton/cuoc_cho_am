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

    -- Reader state
    signal data : std_logic_vector(15 downto 0) := (others => '0');

    -- Writer state
    constant CLKS_PER_SEC : natural                        := 100000000;
    signal   counter      : natural                        := 0;
    signal   din          : std_logic_vector(767 downto 0) := (others => '0');
    signal   value        : natural                        := 0;

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
    fifo_reader : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if fifo_empty = '0' then
                fifo_rd_en <= '1';
                data <= fifo_dout(15 downto 0);
            else
                fifo_rd_en <= '0';
            end if;
        end if;
    end process;
    o_leds(15) <= fifo_empty;
    o_leds(14 downto 0) <= data(14 downto 0);

    -- Writer
    fifo_writer : process(i_clk)
    begin
        if rising_edge(i_clk) then
            if counter < CLKS_PER_SEC then
                fifo_wr_en <= '0';
                counter <= counter + 1;
            else
                if fifo_full = '0' then
                    fifo_din(15 downto 0) <= std_logic_vector(to_unsigned(value, 16));
                    fifo_wr_en <= '1';
                    counter <= 0;
                    value <= value + 1;
                end if;
            end if;
        end if;
    end process;

end structure;
