library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library work;
    use work.spdif.all;

entity spdif_tx is
    port (
        i_sample : in  std_logic_vector(19 downto 0);
        i_enable : in std_logic;
        o_spdif  : out std_logic
    );
end spdif_tx;

architecture behavioral of spdif_tx is

    -- Stores signal transition pattern for the next preamble in transmit
    --
    -- Preambles are uniquely determined by signal transitions over the
    -- duration of four unencoded bits, which corresponds to 8 time slots
    constant B_PREAMBLE         : std_logic_vector(7 downto 0) := "10011100";
    constant W_PREAMBLE         : std_logic_vector(7 downto 0) := "10010110";
    constant M_PREAMBLE         : std_logic_vector(7 downto 0) := "10010011";
    signal preamble_transitions : std_logic_vector(7 downto 0) := (others => '0');

    -- Timing parameters
    constant SAMPLE_RATE        : real    := 48000.0;
    constant SCLK_PERIOD_NS     : real    := 0.5               * -- (0.5 bit)
                                             (1.0/64.0)        * -- (1 sample/64 bit)
                                             (1.0/SAMPLE_RATE) * -- (1s/480000 sample)
                                             1000000000.0;       -- (10^9 ns/s)
    constant CLK_PERIOD_NS      : real    := 81.38;
    constant SCLK_PERIOD_CYCLES : natural := ROUND(SCLK_PERIOD_NS / CLK_PERIOD_NS);
    signal sclk : std_logic := '0';

    -- Transmit state
    type State_t is (
        INIT,
        PREAMBLE,
        AUX,
        DATA,
        STATUS,
        SPINNING
    );
    signal state      : State_t   := INIT;
    signal frame      : natural   := 0;
    signal subframe   : std_logic := '0';
    signal counter    : natural   := 0;

    -- Intermediate signals
    signal spdif : std_logic := '0';

begin

    -- Investigate current state of transmission, deduce correct
    -- preamble to use at the beginning of the next frame, and save
    -- it in `preamble_transitions`
    preamble_transitions <= B_PREAMBLE when frame = 0 and subframe = '0'
                            W_PREAMBLE when subframe = '0'
                            M_PREAMBLE when subframe = '1'
                            "00000000" when others;

    -- Generate sclk for transmit_sm to use
    --
    -- Implementation is currently unecessary, because i_clk is manually set to
    -- desired frequency
    sclk <= i_clk;

    -- Note: states in the state machine have the responsibility of
    -- negating the line in the moment of the outgoing transition
    -- to another state.
    transmit_sm : process(sclk)
    begin
        if rising_edge(sclk) then
            case state is
                when INIT =>
                    -- Wait for enable to be asserted, trigger first signal
                    -- transition in preamble, and transit to PREAMBLE to
                    -- handle the rest
                    if i_enable = '1' then
                        spdif <= not spdif;
                        counter <= 1;
                        state <= PREAMBLE;
                    end if;

                when PREAMBLE =>
                    if counter < 8 then
                        -- Only trigger signal transition when it is appropriate
                        -- based on what is selecetd by decode_next_preamble_proc
                        if preamble_transitions(counter) = '1' then
                            spdif <= not spdif;
                        end if;
                    else
                        spdif <= not spdif;
                        counter <= 1;
                        state <= AUX;
                    end if;
                    counter <= counter + 1;

                when AUX =>
                    if counter < 8 then
                        if counter mod 2 = 0 then
                            spdif <= not spdif;
                        end if;
                    else
                        spdif <= not spdif;
                        counter <= 1;
                        state <= DATA;
                    end if;
                    counter <= counter + 1;

                when DATA =>
                    if counter < 20 then
                        if counter mod 2 = 0 then
                            spdif <= not spdif;

                        elsif i_sample(counter) = '1' then
                            -- TODO
                        end if;
                    else
                        spdif <= not spdif;
                        counter <= 1;
                        state <= STATUS;
                    end if;
                    counter <= counter + 1;

                when STATUS =>
                    -- TODO: Transmit four status bits

                when others =>
                    -- TODO, assert false

            end case;
        end if;
    end process;

    o_spdif <= spdif;

end behavioral;
