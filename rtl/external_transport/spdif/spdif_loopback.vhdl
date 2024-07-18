library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.spdif.all;

entity spdif_loopback is
    port (
        i_clk   : in  std_logic;
        i_spdif : in  std_logic;
        o_spdif : out std_logic
    );
end spdif_loopback;

architecture behavioral of spdif_loopback is

    -- Loopback via synchronizer
    --constant MIN_SYNC_SIZE : natural := 1;
    --constant MAX_SYNC_SIZE : natural := 1;
    --signal   spdif_sync    : std_logic_vector(MAX_SYNC_SIZE downto 0);

    -- sync_size selection
    --signal   sync_size             : natural := MIN_SYNC_SIZE;
    --constant CLK_CYCLES_PER_SECOND : natural := 100000000;
    --signal   seconds               : natural := 0;
    --signal   clk_cycles            : natural := 0;

begin

    
    input_sync_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then
            o_spdif <= i_spdif;
        end if;
    end process;

    -- Synchronizer
    --input_sync_proc : process(i_clk)
    --begin
    --    if rising_edge(i_clk) then
    --        spdif_sync(MAX_SYNC_SIZE) <= i_spdif;
    --        spdif_sync(MAX_SYNC_SIZE - 1 downto 0) <= spdif_sync(MAX_SYNC_SIZE downto 1);
    --    end if;
    --end process;

    -- Sampler
    --sample_proc : process(i_clk)
    --begin
    --    if rising_edge(i_clk) then
    --        o_spdif <= spdif_sync(MAX_SYNC_SIZE - sync_size);
    --    end if;
    --end process;

    -- Select sync_size
    --sync_size_proc : process(i_clk)
    --begin
    --    if rising_edge(i_clk) then
    --        clk_cycles <= clk_cycles + 1;
    --        if clk_cycles >= CLK_CYCLES_PER_SECOND then
    --            seconds <= seconds + 1;
    --            clk_cycles <= 0;
    --        end if;
    --
    --        if seconds > 1 then
    --
    --            if sync_size < MAX_SYNC_SIZE then
    --                sync_size <= sync_size + 1;
    --            else
    --                sync_size <= MIN_SYNC_SIZE;
    --            end if;
    --
    --            seconds <= 0;
    --            clk_cycles <= 0;
    --        end if;
    --
    --    end if;
    --end process;

end behavioral;
