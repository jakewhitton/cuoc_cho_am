library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet.all;

entity ethernet_rx is
    port (
        i_ref_clk : in   std_logic;
        phy       : view Phy_t;
        o_frame   : out  Frame_t;
        o_valid   : out  std_logic;
    );
end ethernet_rx;

architecture behavioral of ethernet_rx is

    -- Dibit streaming state
    type StreamState_t is (
        PREAMBLE_AND_SFD, -- Wait for complete preamble & SFD
        STREAM_FRAME      -- Stream frame dibits
    );
    signal stream_state : StreamState_t := PREAMBLE_AND_SFD;
    signal psfd_counter : natural       := 0;
    signal dibit_data   : Dibit_t       := (others => '0');
    signal dibit_valid  : std_logic     := '0';

    -- Dibit placing state
    type PlaceState_t is (
        WAIT_FOR_FRAME, -- Wait for dibit stream of next frame
        PLACE_FRAME,    -- Place frame dibits
        VALIDATE_FRAME  -- Validate FCS & publish frame
    );
    signal place_state      : PlaceState_t   := WAIT_FOR_FRAME;
    signal prev_dibit_valid : std_logic      := '0';
    signal section          : FrameSection_t := DESTINATION_MAC;
    signal offset           : natural        := 0;
    signal fcs_recv         : FCS_t          := (others => '0');

    -- Intermediate signals for fcs_calculator
    signal prev_crc  : CRC32_t := (others => '0');
    signal crc_dibit : Dibit_t := (others => '0');
    signal crc       : CRC32_t := (others => '0');
    signal fcs_calc  : FCS_t   := (others => '0');

    -- Intermediate signals
    signal frame : Frame_t   := Frame_t_INIT;
    signal valid : std_logic := '0';

begin

    -- Note:
    --
    -- The RMII specification describes a behavior where phase differences
    -- between "recovered rx clock" and the 50MHz reference clock causes
    -- phy.crs_dv to cycle at 25MHz following its initial deassertion.  This
    -- behavior is supposed to allow any leftover data in the frame to be
    -- recovered.
    --
    -- So far, I have not been able to detect this behavior.  However,
    -- anticipating the possibility of needing to support this behavior, I have
    -- separated the implementation into a "streaming" process and a "placing"
    -- process.
    --
    -- The idea is that the logic for handling "recovered dibits" could be
    -- placed into the "streaming" process and that the "placing" process could
    -- be left unaffected.

    -- Present frames from PHY as a stream of dibits
    stream_dibits : process(i_ref_clk)
    begin
        if rising_edge(i_ref_clk) then
            case stream_state is
            when PREAMBLE_AND_SFD =>
                -- Reset psfd_counter when preamble pattern is disrupted
                if phy.crs_dv = '0' or
                    ( psfd_counter < PSFD_LAST_DIBIT
                      and phy.rxd /= PSFD_VALID_DIBIT_REST ) or
                    ( psfd_counter = PSFD_LAST_DIBIT
                      and phy.rxd /= PSFD_VALID_DIBIT_LAST )
                then
                    psfd_counter <= 0;

                -- Otherwise, wait for final PSFD dibit, then transit
                elsif psfd_counter < PSFD_LAST_DIBIT then
                    psfd_counter <= psfd_counter + 1;
                else
                    -- Begin dibit stream one clock cycle early to give
                    -- place_dibits an opportunity to transit
                    dibit_data <= (others => '0');
                    dibit_valid <= '1';

                    psfd_counter <= 0;
                    stream_state <= STREAM_FRAME;
                end if;

            when STREAM_FRAME =>
                -- If dibits are still being presented, pass them along
                if phy.crs_dv = '1' then
                    dibit_data <= phy.rxd;
                    dibit_valid <= '1';

                -- Otherwise, signal end of dibit stream, then transit
                else
                    dibit_data  <= (others => '0');
                    dibit_valid <= '0';
                    stream_state <= PREAMBLE_AND_SFD;
                end if;
            end case;
        end if;
    end process;

    -- Place dibits streamed from PHY into their correct place in a Frame_t
    place_dibits : process(i_ref_clk)
        variable pos : natural := 0;
    begin
        if rising_edge(i_ref_clk) then
            case place_state is
            when WAIT_FOR_FRAME =>
                -- Wait for rising edge on dibit_valid, then transit
                if prev_dibit_valid = '0' and dibit_valid = '1' then
                    frame <= Frame_t_INIT;
                    valid <= '0';
                    offset <= 0;
                    section <= DESTINATION_MAC;
                    place_state <= PLACE_FRAME;
                end if;

            when PLACE_FRAME =>
                -- If dibit stream ends prematurely, abandon frame
                if dibit_valid = '0' then
                    place_state <= WAIT_FOR_FRAME;

                -- Otherwise, place dibit & transit when appropriate
                else
                    -- Update our calculated FCS
                    if section /= FRAME_CHECK_SEQUENCE then
                        prev_crc <= CRC32_t_INIT when
                                    section = DESTINATION_MAC and offset = 0
                                    else crc;
                        crc_dibit(1) <= dibit_data(0);
                        crc_dibit(0) <= dibit_data(1);
                    end if;

                    pos := get_dibit_pos(offset, section);

                    case section is
                    when DESTINATION_MAC =>
                        frame.dest_mac(pos to pos + 1) <= dibit_data;

                        -- Wait for final dest MAC dibit, then transit
                        if offset < MAC_LAST_DIBIT then
                            offset <= offset + 1;
                        else
                            offset <= 0;
                            section <= SOURCE_MAC;
                        end if;

                    when SOURCE_MAC =>
                        frame.src_mac(pos to pos + 1) <= dibit_data;

                        -- Wait for final src MAC dibit, then transit
                        if offset < MAC_LAST_DIBIT then
                            offset <= offset + 1;
                        else
                            offset <= 0;
                            section <= LENGTH;
                        end if;

                    when LENGTH =>
                        frame.length(pos to pos + 1) <= unsigned(dibit_data);

                        -- Wait for final length dibit, then transit
                        if offset < LENGTH_LAST_DIBIT then
                            offset <= offset + 1;
                        else
                            offset <= 0;
                            section <= PAYLOAD;
                        end if;

                    when PAYLOAD =>
                        -- If we have exceeded MTU, abandon frame
                        if offset >= MAX_PAYLOAD_SIZE * DIBITS_PER_BYTE then
                            place_state <= WAIT_FOR_FRAME;

                        -- Otherwise, accept dibit
                        else
                            frame.payload(pos to pos + 1) <= dibit_data;

                            -- If payload is incomplete, advance to next dibit
                            if offset + 1 < frame.length * DIBITS_PER_BYTE then
                                offset <= offset + 1;

                            -- Otherwise, if payload is smaller than what would
                            -- be needed to meet minimum frame size, expect
                            -- padding to follow
                            elsif offset < MIN_PAYLOAD_SIZE * DIBITS_PER_BYTE
                            then
                                offset <= 0;
                                section <= PADDING;

                            -- Otherwise, expect FCS to follow
                            else
                                offset <= 0;
                                section <= FRAME_CHECK_SEQUENCE;
                            end if;
                        end if;

                    when PADDING =>
                        -- No-op when receiving padding
                        --
                        -- Wait for final padding dibit, then transit
                        if offset + 1 <
                           (MIN_PAYLOAD_SIZE - frame.length) * DIBITS_PER_BYTE
                        then
                            offset <= offset + 1;
                        else
                            offset <= 0;
                            section <= FRAME_CHECK_SEQUENCE;
                        end if;

                    when FRAME_CHECK_SEQUENCE =>
                        -- Note: FCS bytes are transmitted msb -> lsb, whereas
                        -- all other bytes are transmitted lsb -> msb.
                        --
                        -- Because of this, we reverse dibit order
                        fcs_recv(pos) <= dibit_data(0);
                        fcs_recv(pos - 1) <= dibit_data(1);

                        -- Wait for final FCS dibit, then transit
                        if offset < FCS_LAST_DIBIT then
                            offset <= offset + 1;
                        else
                            place_state <= VALIDATE_FRAME;
                        end if;
                    end case;
                end if;

            when VALIDATE_FRAME =>
                -- If stream concluded when we predicted it would and our
                -- calculated FCS matches our received FCS, publish frame
                if dibit_valid = '0' and fcs_recv = fcs_calc then
                    valid <= '1';
                end if;

                place_state <= WAIT_FOR_FRAME;
            end case;
            prev_dibit_valid <= dibit_valid;
        end if;
    end process;
    o_frame <= frame;
    o_valid <= valid;

    -- Frame check sequence calculator
    fcs_calculator : work.ethernet.fcs_calculator
        port map (
            i_crc   => prev_crc,
            i_dibit => crc_dibit,
            o_crc   => crc,
            o_fcs   => fcs_calc
        );

end behavioral;
