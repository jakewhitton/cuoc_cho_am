library ieee;
    use ieee.std_logic_1164.all;

library sw_transport;
    use sw_transport.all;

library external_transport;
    use external_transport.spdif.all;

entity top is
    port (
        i_clk   : in  std_logic;
        i_spdif : in  std_logic;
        o_spdif : out std_logic;
        o_leds  : out std_logic_vector(15 downto 0)
    );
end top;

architecture structure of top is

    --constant ONE_SECOND          : natural   := 100000000;
    --signal active_counter        : natural   := 0;
    --signal active_in_last_second : std_logic := '0';

    signal valid   : std_logic                     := '0';
    signal channel : std_logic                     := '0';
    signal sample  : std_logic_vector(23 downto 0) := (others => '0');
    signal sclk    : std_logic                     := '0';

    constant SCLK_BUFFER_SIZE : natural := 15;
    signal sclk_buffer : std_logic_vector(SCLK_BUFFER_SIZE downto 0) := (others => '0');

    --signal led15 : std_logic := '0';
    

    --signal counter_low  : natural := 0;
    --signal counter_high : natural := 0;

    --signal samples_received : natural := 0;

begin
    -- S/PDIF loopback
    --spdif_tx_loopback : external_transport.spdif.spdif_loopback
    --    port map (
    --        i_clk   => i_clk,
    --        i_spdif => i_spdif,
    --        o_spdif => o_spdif
    --    );

    -- S/PDIF transmitter
    --spdif_tx_spoof : external_transport.spdif.spdif_tx_spoof
    --    port map (
    --        i_clk   => i_clk,
    --        o_spdif => o_spdif
    --    );

    -- S/PDIF receiver
    spdif_rx : external_transport.spdif.spdif_rx
        port map (
            i_clk     => i_clk,
            i_spdif   => i_spdif,
            o_valid   => valid,
            o_channel => channel,
            o_sample  => sample,
            o_sclk    => sclk
        );

    sclk_buffer_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then
            sclk_buffer(SCLK_BUFFER_SIZE) <= sclk;
            sclk_buffer(SCLK_BUFFER_SIZE - 1 downto 0) <= sclk_buffer(SCLK_BUFFER_SIZE downto 1);
            o_spdif <= sclk_buffer(0);
        end if;
    end process;

    --write_sample_proc : process(valid)
    --begin
    --    if rising_edge(valid) then
    --        o_leds(14 downto 7) <= sample(23 downto 16);
    --        o_leds(6 downto 0) <= sample(6 downto 0);
    --    end if;
    --end process;
    --o_leds(15) <= valid;
    

end structure;
