library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.spdif.all;

entity spdif_tx is
    port (
        i_clk             : in  std_logic;
        i_subframe        : in  Subframe_t;
        i_channel_left    : in  std_logic_vector(0 to 191);
        i_channel_right   : in  std_logic_vector(0 to 191);
        i_enable          : in  std_logic;
        o_finish_subframe : out std_logic;
        o_spdif           : out std_logic
    );
end spdif_tx;

architecture behavioral of spdif_tx is

    -- Preamble to use during next subframe
    signal preamble_transitions : Spdif_Preamble_t := (others => '0');

    -- Timing state
    signal sclk     : std_logic := '0';
    signal frame    : natural   := 0;
    signal subframe : std_logic := '0';
    signal bit_pos  : natural   := 0;
    signal timeslot : std_logic := '0';

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
    signal parity_bit : std_logic := '0';

    -- Intermediate signals
    signal spdif : std_logic := '0';

begin

    -- Investigate current state of transmission, deduce correct
    -- preamble to use at the beginning of the next frame, and save
    -- it in `preamble_transitions`
    preamble_transitions <= B_PREAMBLE_TRANSITIONS when frame = 0 and subframe = '0' else
                            W_PREAMBLE_TRANSITIONS when subframe = '0' else
                            M_PREAMBLE_TRANSITIONS when subframe = '1' else
                            "00000000";

    -- Timing handling
    sclk <= i_clk; -- Works currently because i_clk period is manually set to ~81.38ns
    maintain_timing_state_proc : process(sclk)
    begin
        if rising_edge(sclk) then
            -- Increment frame
            if subframe = '1' and bit_pos = LAST_STATUS_BIT and timeslot = '1' then
                if frame < 191 then
                    frame <= frame + 1;
                else
                    frame <= 0;
                end if;
            end if;

            -- Increment subframe
            if bit_pos = LAST_STATUS_BIT and timeslot = '1' then
                subframe <= not subframe;
            end if;

            -- Increment bit
            if timeslot = '1' then
                if bit_pos < 31 then
                    bit_pos <= bit_pos + 1;
                else
                    bit_pos <= 0;
                end if;
            end if;

            -- Increment timeslot
            timeslot <= not timeslot;
        end if;
    end process;
    o_finish_subframe <= subframe;

    -- Note: states in the state machine have the responsibility of
    -- negating the line in the moment of the outgoing transition
    -- to another state.
    transmit_sm_proc : process(sclk)
    begin
        if rising_edge(sclk) then
            case state is
                when INIT =>
                    -- If i_enable is asserted during rising edge before the
                    -- first time slot of a new block of 192 frames, perform
                    -- first transition of preamble, and transit to PREAMBLE to
                    -- handle the rest
                    if frame = 191 and subframe = '1' and bit_pos = 31 and timeslot = '1' and i_enable = '1' then
                        spdif <= not spdif;
                        state <= PREAMBLE;
                    end if;

                when PREAMBLE =>

                    -- Verify preamble decode logic has decided on a vaild
                    -- preamble to use
                    assert (preamble_transitions = B_PREAMBLE_TRANSITIONS or
                            preamble_transitions = M_PREAMBLE_TRANSITIONS or
                            preamble_transitions = W_PREAMBLE_TRANSITIONS)
                        report "Preamble decode logic is not working correctly"
                        severity ERROR; 

                    if not (bit_pos = LAST_PREAMBLE_BIT and timeslot = '1') then
                        -- Only trigger signal transition when it is appropriate
                        -- based on what is selecetd by decode_next_preamble_proc
                        if preamble_transitions(2*bit_pos + to_integer(unsigned'("" & timeslot)) + 1) = '1' then
                            spdif <= not spdif;
                        end if;
                    else
                        -- Reset parity calculation for the aux, data, and status bits to follow
                        parity_bit <= '0';

                        spdif <= not spdif;
                        state <= AUX;
                    end if;

                when AUX =>
                    if not (bit_pos = LAST_AUX_BIT and timeslot = '1') then
                        if timeslot = '0' then
                            -- Signal transition only if aux bit is a '1'
                            if i_subframe.aux(bit_pos - FIRST_AUX_BIT) = '1' then
                                spdif <= not spdif;
                                parity_bit <= not parity_bit;
                            end if;
                        else
                            -- Always transition at end of a aux bit
                            spdif <= not spdif;
                        end if;
                    else
                        spdif <= not spdif;
                        state <= DATA;
                    end if;

                when DATA =>
                    if not (bit_pos = LAST_DATA_BIT and timeslot = '1') then
                        if timeslot = '0' then
                            -- Signal transition only if data bit is a '1'
                            if i_subframe.data(bit_pos - FIRST_DATA_BIT) = '1' then
                                spdif <= not spdif;
                                parity_bit <= not parity_bit;
                            end if;
                        else
                            -- Always transition at end of a data bit
                            spdif <= not spdif;
                        end if;
                    else
                        spdif <= not spdif;
                        state <= STATUS;
                    end if;

                when STATUS =>
                    if not (bit_pos = LAST_STATUS_BIT and timeslot = '1') then
                        if timeslot = '0' then
                            case bit_pos is
                                when STATUS_BIT_VALID =>
                                    if i_subframe.valid = '1' then
                                        spdif <= not spdif;
                                        parity_bit <= not parity_bit;
                                    end if;
                                    
                                when STATUS_BIT_USER =>
                                    if i_subframe.user = '1' then
                                        spdif <= not spdif;
                                        parity_bit <= not parity_bit;
                                    end if;
                                    -- Always assume user bit is a '0'

                                when STATUS_BIT_CHANNEL =>
                                    if subframe = '1' then
                                        if i_channel_left(frame) = '1' then
                                            spdif <= not spdif;
                                            parity_bit <= not parity_bit;
                                        end if;
                                    else
                                        if i_channel_right(frame) = '1' then
                                            spdif <= not spdif;
                                            parity_bit <= not parity_bit;
                                        end if;
                                    end if;

                                when STATUS_BIT_PARITY =>
                                    if parity_bit = '1' then
                                        spdif <= not spdif;
                                        parity_bit <= not parity_bit;
                                    end if;
                                    

                                when others =>
                                    -- TODO, assert false
                            end case;

                        else
                            -- Always transition at end of a status bit
                            spdif <= not spdif;
                        end if;
                    else
                        -- Verify parity_bit always causes even parity at the
                        -- end of each subframe
                        assert parity_bit = '0'
                            report "Parity calculation is not behaving correctly"
                            severity ERROR;
                        
                        spdif <= not spdif;
                        state <= PREAMBLE;
                    end if;

                when others =>
                    -- TODO, assert false

            end case;
        end if;
    end process;

    o_spdif <= spdif;

end behavioral;
