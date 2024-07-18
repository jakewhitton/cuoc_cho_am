library ieee;
    use ieee.std_logic_1164.all;
    use ieee.std_logic_arith.all;


-------------------------------Package Declaration------------------------------
package sim_spdif is

    type int_array is array (integer range <>) of integer;

    --type Subframe_t

    procedure transmit_subframe (
        constant vector : in     std_logic_vector(23 downto 0);
        signal   aes    : inout  std_logic
    );

    procedure transmit_block (
        constant pcm_data : in    int_array(0 to 191);
        signal   aes      : inout std_logic;
        signal   curr_val : out   std_logic_vector(23 downto 0)
    );

    -- Timing parameters
    --
    -- s: todo, explain purpose
    constant        s_init : time := 150 ns;
    shared variable s      : time := s_init;
    --
    -- l: todo, explain purpose
    constant        m_init : time := 310 ns;
    shared variable m      : time := m_init;
    --
    -- l: todo, explain purpose
    constant        l_init : time := 485 ns;
    shared variable l      : time := l_init;

end package sim_spdif;
--------------------------------------------------------------------------------


----------------------------------Package Body----------------------------------
package body sim_spdif is

    procedure transmit_subframe (
        signal   spdif    : inout  std_logic;
        constant subframe : in     std_logic_vector(23 downto 0)
    ) is begin
         -- TODO
    end procedure;

    --procedure transmit_subframe (
    --    constant vector : in     std_logic_vector(23 downto 0);
    --    signal   aes    : inout  std_logic
    --) is begin
    --    for i in 0 to 23 loop
    --        if vector(i) = '0' then
    --            aes <= not aes;
    --            wait for m;
    --        elsif vector(i) = '1' then
    --            aes <= not aes;
    --            wait for s;
    --            aes <= not aes;
    --            wait for s;
    --        end if;
    --    end loop;
    --end procedure;

    --procedure transmit_block (
    --    constant pcm_data : in    int_array(0 to 191);
    --    signal   aes      : inout std_logic;
    --    signal   curr_val : out   std_logic_vector(23 downto 0)
    --) is begin
    --
    --    -- Z preamble
    --    aes <= not aes;    
    --    wait for l;                    
    --    aes <= not aes;    
    --    wait for s;
    --    aes <= not aes;    
    --    wait for s;
    --    aes <= not aes;    
    --    wait for l;
    --
    --    transmit_subframe(conv_std_logic_vector(pcm_data(0), 24), aes);    
    --    curr_val <= conv_std_logic_vector(pcm_data(0), 24);
    --
    --    aes <= not aes; -- 1.5
    --    wait for m;
    --    aes <= not aes; -- 1.5
    --    wait for m;
    --    aes <= not aes; -- 1.5
    --    wait for m;
    --    aes <= not aes; -- 1.5
    --    wait for m;                
    --
    --    for i in 1 to 191 loop
    --
    --        -- B subframe
    --        if i mod 2 /= 0 then 
    --            -- Y preamble
    --            aes <= not aes; -- 1.5                
    --            wait for l;
    --            aes <= not aes; -- 1.5
    --            wait for m;
    --            aes <= not aes; -- 3
    --            wait for s;
    --            aes <= not aes; -- 3.5
    --            wait for m;        
    --
    --        -- A subframe
    --        else 
    --            -- X preamble
    --            aes <= not aes; -- 1.5                
    --            wait for l;
    --            aes <= not aes; 
    --            wait for l;
    --            aes <= not aes;                 
    --            wait for s;
    --            aes <= not aes; 
    --            wait for s;
    --        end if;
    --
    --        curr_val <= conv_std_logic_vector(pcm_data(i), 24);
    --        transmit_subframe(conv_std_logic_vector(pcm_data(i), 24), aes);
    --
    --        aes <= not aes; -- 1.5
    --        wait for m;
    --        aes <= not aes; -- 1.5
    --        wait for m;
    --        aes <= not aes; -- 1.5
    --        wait for m;
    --        aes <= not aes; -- 1.5
    --        wait for m;                
    --                    
    --    end loop;
    --end procedure;


end package body sim_spdif;
--------------------------------------------------------------------------------
