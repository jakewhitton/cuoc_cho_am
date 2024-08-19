library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.spdif.all;

entity spdif_rx is
    port (
        i_clk     : in  std_logic;
        i_spdif   : in  std_logic;
        o_valid   : out std_logic;
        o_channel : out std_logic;
        o_sample  : out std_logic_vector(23 downto 0);
        o_sclk    : out std_logic
    );
end spdif_rx;

architecture behavioral of spdif_rx is

    -- Signals for spdif_rx_serial_bridge
    signal reset  : std_logic := '0';
    signal sdata  : std_logic := '0';
    signal sclk   : std_logic := '0';
    signal bsync  : std_logic := '0';
    signal lrck   : std_logic := '0';
    signal active : std_logic := '0';

    -- State for parse_sm_proc
    type State_t is (WAITING_FOR_FRAME, PREAMBLE, SAMPLE, STATUS);
    signal state     : State_t   := WAITING_FOR_FRAME;
    signal counter   : natural   := 0;
    signal last_lrck : std_logic := '0';

begin

    -- S/PDIF => serial bridge
    spdif_rx_serial_bridge : work.spdif.spdif_rx_serial_bridge
        generic map (
            reg_width => 5
        )
        port map (
            clk    => i_clk,
            aes3   => i_spdif,
            reset  => reset,
            sdata  => sdata,
            sclk   => sclk,
            bsync  => bsync,
            lrck   => lrck,
            active => active
        );

    parse_sm_proc : process(sclk)
    begin
        if rising_edge(sclk) then
            case state is

                when WAITING_FOR_FRAME =>
                    if lrck /= last_lrck then
                        -- This is the first bit of a preamble
                        o_channel <= lrck;
                        counter <= 1;
                        state <= PREAMBLE;
                    end if;

                when PREAMBLE =>
                    -- Wait for the 4th preamble bit, then transit to SAMPLE
                    if counter < 3 then
                        counter <= counter + 1;
                    else
                        o_valid <= '0';
                        counter <= 0;
                        state <= SAMPLE;
                    end if;

                when SAMPLE =>
                    if counter < 24 then
                        o_sample(counter) <= sdata;
                        counter <= counter + 1;
                    else
                        o_valid <= '1';
                        counter <= 1;
                        state <= STATUS;
                    end if;

                when STATUS =>
                    -- Wait for the 4th status bit, then transit to WAITING_FOR_FRAME
                    if counter < 3 then
                        counter <= counter + 1;
                    else
                        counter <= 0;
                        state <= WAITING_FOR_FRAME;
                    end if;

            end case;

            last_lrck <= lrck;
        end if;
    end process;

    o_sclk <= sclk;

end behavioral;
