library ieee;
    use ieee.std_logic_1164.all;

library std;
    use std.env.stop;

library work;
    use work.spdif.all;
    use work.sim_spdif.all;

entity tb_spdif_rx is
end tb_spdif_rx;

architecture behavior of tb_spdif_rx is 

    -- Entity inputs
    signal clk   : std_logic := '0';
    signal spdif : std_logic := '0';

    -- Entity outputs
    signal valid   : std_logic                     := '0';
    signal channel : std_logic                     := '0';
    signal sample  : std_logic_vector(23 downto 0) := (others => '0');

    -- Test data
    shared variable vals     : int_array(0 to 191);
    signal          curr_val : std_logic_vector(23 downto 0);

begin

    spdif_rx : work.spdif.spdif_rx port map (
        i_clk     => clk,
        i_spdif   => spdif,
        o_valid   => valid,
        o_channel => channel,
        o_sample  => sample
    );    
    
    -- Generate clk
    generate_clk: process
    begin
        wait for 100 ns;
        clock_loop : loop
             clk <= '0';
             wait for 5 ns;
             clk <= '1';
             wait for 5 ns;
        end loop clock_loop;
    end process;

    -- Generate spdif
    generate_spdif : process
    begin

        wait for 100 ns;
    
        -- Generate first block
        for i in 0 to 191 loop
            if i = 0 then
                vals(i) := 8388609;
            else 
                vals(i) := 8388609;
            end if;
        end loop;
        generate_block(vals, spdif, curr_val);
        
        -- Generate second block
        for i in 0 to 191 loop
            if i = 0 then
                vals(i) := 0;
            else 
                vals(i) := vals(i-1) + 10000;
            end if;
        end loop;
        generate_block(vals, spdif, curr_val);
        
        -- Wait 100 ns for global reset to finish
        wait for 100 us;
    
        -- Override timing params
        s := 81.2 ns;
        m := 162.6 ns;
        l := 244 ns;
      
        wait for 100 ns;
    
        -- Generate third block
        for i in 0 to 191 loop
            if i = 0 then
                vals(i) := 0;
            else 
                vals(i) := 1;
            end if;
        end loop;
        generate_block(vals, spdif, curr_val);
        
        for i in 0 to 191 loop
            if i = 0 then
                vals(i) := 0;
            else 
                vals(i) := vals(i-1) + 10000;
            end if;
        end loop;

        s := s_init;
        m := m_init;
        l := l_init;

        wait;
    end process;
    
    tb : process
    begin
        wait for 50 ms;
        stop;
    end process;
end;
