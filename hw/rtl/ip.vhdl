library ieee;
    use ieee.std_logic_1164.all;

-- Component declarations for IP
package ip is

    -- PLL IP for generating S/PDIF clk
    component pll is
        port (
            o_spdif_tx_clk : out std_logic;
            reset          : in  std_logic;
            locked         : out std_logic;
            i_clk          : in  std_logic
        );
    end component;

end package ip;
