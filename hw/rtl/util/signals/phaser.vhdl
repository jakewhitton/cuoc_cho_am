library ieee;
    use ieee.std_logic_1164.all;
    
entity phaser is
    port (
        i_clk  : in  std_logic;
        input  : in  std_logic;
        output : out std_logic
    );
end phaser;

architecture behavioral of phaser is

    -- Loopback via synchronizer
    constant MIN_PHASE : natural := 1;
    constant MAX_PHASE : natural := 5000;
    signal   past      : std_logic_vector(MAX_PHASE downto 0);

    -- Phase selection
    signal   phase                 : natural := MIN_PHASE;
    constant CLK_CYCLES_PER_SECOND : natural := 100000000;
    signal   seconds               : natural := 0;
    signal   clk_cycles            : natural := 0;

begin

    -- Synchronizer
    input_sync_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then
            past(MAX_PHASE) <= input;
            past(MAX_PHASE - 1 downto 0) <= past(MAX_PHASE downto 1);
        end if;
    end process;

    -- Sampler
    sample_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then
            output <= past(MAX_PHASE - phase);
        end if;
    end process;

    -- Select phase
    select_phase_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then
            clk_cycles <= clk_cycles + 1;
            if clk_cycles >= CLK_CYCLES_PER_SECOND then
                seconds <= seconds + 1;
                clk_cycles <= 0;
            end if;
    
            if seconds > 1 then
    
                if phase < MAX_PHASE then
                    phase <= phase + 1;
                else
                    phase <= MIN_PHASE;
                end if;
    
                seconds <= 0;
                clk_cycles <= 0;
            end if;
    
        end if;
    end process;

end behavioral;
