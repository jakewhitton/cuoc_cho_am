library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package signals is

    -- Apply variable phase to signal over time
    component phaser is
        port (
            i_clk  : in  std_logic;
            input  : in  std_logic;
            output : out std_logic
        );
    end component;

    component clk_generator is
        port (
            i_clk : in  std_logic;
            o_clk : out std_logic
        );
    end component;

end package signals;
