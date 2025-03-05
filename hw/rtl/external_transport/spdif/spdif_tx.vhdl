library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library util;
    use util.audio.all;

library work;
    use work.spdif.all;

entity spdif_tx is
    port (
        i_clk    : in   std_logic;
        i_active : in   std_logic;
        reader   : view PeriodFifo_Reader_t;
        o_spdif  : out  std_logic;
    );
end spdif_tx;

architecture behavioral of spdif_tx is

    -- Timing state
    signal frame    : natural   := 0;
    signal subframe : std_logic := '0';
    signal bit_pos  : natural   := 0;
    signal timeslot : std_logic := '0';

    -- Sample selection state
    signal period_in  : Period_t := Period_t_INIT;
    signal period     : Period_t := Period_t_INIT;
    signal pos        : natural  := 0;
    signal period_end : natural  := 0;
    signal sample     : Sample_t := Sample_t_INIT;

    -- Mocked period
    constant multiplier  : natural  := 2097151 / PERIOD_SIZE;
    signal   mock_period : Period_t := Period_t_INIT;

    -- Transmit state
    type TransmitState_t is (
        INIT,
        PREAMBLE,
        AUX,
        DATA,
        STATUS
    );
    signal tx_state    : TransmitState_t := INIT;
    signal tx_subframe : Subframe_t      := Subframe_t_INIT;
    signal parity_bit  : std_logic       := '0';

    -- Helper state
    signal preamble_transitions : Spdif_Preamble_t           := (others => '0');
    signal channel_bits         : std_logic_vector(0 to 191) := (others => '0');

    -- Intermediate signals
    signal spdif : std_logic := '0';

begin

    -- Timing handling
    maintain_timing_state_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then
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

    -- Shuttle data between period FIFO & tx_subframe
    sample_selection_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then

            -- Will be overwritten later if needed
            reader.enable <= '0';

            -- Upon finishing transmitting subframe, select next sample
            if subframe = '1' and bit_pos = 31 and timeslot = '1' then

                pos <= (pos + 1) mod PERIOD_SIZE;

                -- Load next period when needed
                if frame = period_end then
                    if reader.empty = '0' then
                        period <= period_in;
                        reader.enable <= '1';
                    else
                        period <= Period_t_INIT;
                    end if;

                    --period <= mock_period;

                    pos <= 0;
                    period_end <= (frame + PERIOD_SIZE) mod 192;
                end if;
            end if;
        end if;
    end process;
    reader.clk <= i_clk;
    period_in <= reader.data;
    sample <= period(to_integer(unsigned'("" & subframe)))(pos);
    assign_aux : for i in 0 to 3 generate
        tx_subframe.aux(i) <= sample(23 - i);
    end generate assign_aux;
    assign_data : for i in 0 to 19 generate
        tx_subframe.data(i) <= sample(19 - i);
    end generate assign_data;

    --generate_mock_period : for i in 0 to PERIOD_SIZE - 1 generate
    --    mock_period(0)(i) <= std_logic_vector(to_unsigned(i * multiplier, 24));
    --    mock_period(1)(i) <= std_logic_vector(to_unsigned(i * multiplier, 24));
    --end generate generate_mock_period;

    -- Note: states in the state machine have the responsibility of negating the
    -- line in the moment of the outgoing transition to another state.
    transmit_sm_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then
            case tx_state is
                when INIT =>
                    -- Wait until beginning of a new block, perform first
                    -- transition of preamble, then switch to PREAMBLE state to
                    -- handle the rest
                    if frame = 191 and subframe = '1' and bit_pos = 31 and timeslot = '1' then
                        spdif <= not spdif;
                        tx_state <= PREAMBLE;
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
                        -- based on what the preamble selection logic prescribes
                        if preamble_transitions(2*bit_pos + to_integer(unsigned'("" & timeslot)) + 1) = '1' then
                            spdif <= not spdif;
                        end if;
                    else
                        -- Reset parity calculation for the aux, data, and status bits to follow
                        parity_bit <= '0';

                        spdif <= not spdif;
                        tx_state <= AUX;
                    end if;

                when AUX =>
                    if not (bit_pos = LAST_AUX_BIT and timeslot = '1') then
                        if timeslot = '0' then
                            -- Signal transition only if aux bit is a '1'
                            if tx_subframe.aux(bit_pos - FIRST_AUX_BIT) = '1' then
                                spdif <= not spdif;
                                parity_bit <= not parity_bit;
                            end if;
                        else
                            -- Always transition at end of a aux bit
                            spdif <= not spdif;
                        end if;
                    else
                        spdif <= not spdif;
                        tx_state <= DATA;
                    end if;

                when DATA =>
                    if not (bit_pos = LAST_DATA_BIT and timeslot = '1') then
                        if timeslot = '0' then
                            -- Signal transition only if data bit is a '1'
                            if tx_subframe.data(bit_pos - FIRST_DATA_BIT) = '1' then
                                spdif <= not spdif;
                                parity_bit <= not parity_bit;
                            end if;
                        else
                            -- Always transition at end of a data bit
                            spdif <= not spdif;
                        end if;
                    else
                        spdif <= not spdif;
                        tx_state <= STATUS;
                    end if;

                when STATUS =>
                    if not (bit_pos = LAST_STATUS_BIT and timeslot = '1') then
                        if timeslot = '0' then
                            case bit_pos is
                                when STATUS_BIT_VALID =>
                                    if tx_subframe.valid = '1' then
                                        spdif <= not spdif;
                                        parity_bit <= not parity_bit;
                                    end if;
                                    
                                when STATUS_BIT_USER =>
                                    if tx_subframe.user = '1' then
                                        spdif <= not spdif;
                                        parity_bit <= not parity_bit;
                                    end if;

                                when STATUS_BIT_CHANNEL =>
                                    if tx_subframe.channel = '1' then
                                        spdif <= not spdif;
                                        parity_bit <= not parity_bit;
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
                        tx_state <= PREAMBLE;
                    end if;

                when others =>
                    -- TODO, assert false

            end case;
        end if;
    end process;
    tx_subframe.valid <= '0';
    tx_subframe.user <= '0';
    tx_subframe.channel <= channel_bits(frame);
    o_spdif <= spdif;

    -- Preamble selection based on timing params
    preamble_transitions <= B_PREAMBLE_TRANSITIONS when frame = 0 and subframe = '0' else
                            W_PREAMBLE_TRANSITIONS when subframe = '0' else
                            M_PREAMBLE_TRANSITIONS when subframe = '1' else
                            "00000000";

    -- Channel bit setting
    --
    -- Note: see https://en.wikipedia.org/wiki/S/PDIF#Protocol_specifications
    -- for more description of the meaning of these fields
    --
    channel_bits(2)        <= '1';    -- Copy permit
    channel_bits(24 to 27) <= "0100"; -- Sampling frequency = 48khz
    channel_bits(32 to 35) <= "1101"; -- Word length = 24 bit, full word

end behavioral;
