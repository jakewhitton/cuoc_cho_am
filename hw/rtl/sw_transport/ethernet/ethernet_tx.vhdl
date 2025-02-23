library work;
    use work.ethernet.all;

library util;
    use util.audio.all;
    use util.types.all;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity ethernet_tx is
    port (
        i_ref_clk : in   std_logic;
        phy       : view EthernetPhy_t;
        i_frame   : in   Frame_t;
        i_valid   : in   std_logic;
    );
end ethernet_tx;

architecture behavioral of ethernet_tx is

    -- Input data buffering state
    signal prev_i_valid : std_logic := '0';
    signal frame        : Frame_t   := Frame_t_INIT;

    -- Transmit state
    type State_t is (
        WAIT_FOR_FRAME,   -- Wait for frame to be presented on inputs
        PREAMBLE_AND_SFD, -- Send complete preamble & SFD
        SEND_FRAME,       -- Send complete frame
        INTER_PACKET_GAP  -- Wait before accepting new frame
    );
    signal state   : State_t        := WAIT_FOR_FRAME;
    signal section : FrameSection_t := DESTINATION_MAC;
    signal offset  : natural        := 0;

    -- Intermediate signals for fcs_calculator
    signal prev_crc  : CRC32_t := (others => '0');
    signal crc_dibit : Dibit_t := (others => '0');
    signal crc       : CRC32_t := (others => '0');
    signal fcs_calc  : FCS_t   := (others => '0');

    -- Intermediate signals
    signal txd   : Dibit_t   := (others => '0');
    signal tx_en : std_logic := '0';

begin

    -- Transmit frames
    transmit_sm : process(i_ref_clk)
        variable pos   : natural := 0;
        variable dibit : Dibit_t := (others => '0');
    begin
        if rising_edge(i_ref_clk) then
            case state is
            when WAIT_FOR_FRAME =>
                -- Wait for rising edge on i_valid, then transit
                if prev_i_valid = '0' and i_valid = '1' then
                    frame <= i_frame;
                    offset <= 0;
                    state <= PREAMBLE_AND_SFD;
                end if;

            when PREAMBLE_AND_SFD =>
                txd <= PSFD_VALID_DIBIT_REST
                       when offset < PSFD_LAST_DIBIT
                       else PSFD_VALID_DIBIT_LAST;
                tx_en <= '1';

                -- Wait for final PSFD dibit, then transit
                if offset < PSFD_LAST_DIBIT then
                    offset <= offset + 1;
                else
                    section <= DESTINATION_MAC;
                    offset <= 0;
                    state <= SEND_FRAME;
                end if;

            when SEND_FRAME =>

                -- Select dibit to transmit based on section and offset
                pos := get_dibit_pos(offset, section);
                case section is
                when DESTINATION_MAC =>
                    dibit := frame.dest_mac(pos to pos + 1);

                    -- Wait for final dest MAC dibit, then transit
                    if offset < MAC_LAST_DIBIT then
                        offset <= offset + 1;
                    else
                        offset <= 0;
                        section <= SOURCE_MAC;
                    end if;

                when SOURCE_MAC =>
                    dibit := frame.src_mac(pos to pos + 1);

                    -- Wait for final src MAC dibit, then transit
                    if offset < MAC_LAST_DIBIT then
                        offset <= offset + 1;
                    else
                        offset <= 0;
                        section <= LENGTH;
                    end if;

                when LENGTH =>
                    dibit := Dibit_t(frame.length(pos to pos + 1));

                    -- Wait for final length dibit, then transit
                    if offset < LENGTH_LAST_DIBIT then
                        offset <= offset + 1;
                    else
                        offset <= 0;
                        section <= PAYLOAD;
                    end if;

                when PAYLOAD =>
                    dibit := frame.payload(pos to pos + 1);

                    -- If payload is incomplete, advance to next dibit
                    if offset + 1 < frame.length * DIBITS_PER_BYTE then
                        offset <= offset + 1;

                    -- Otherwise, if payload is smaller than what would be
                    -- needed to meet minimum frame size, select padding to
                    -- follow
                    elsif offset < MIN_PAYLOAD_SIZE * DIBITS_PER_BYTE
                    then
                        offset <= 0;
                        section <= PADDING;

                    -- Otherwise, select FCS to follow
                    else
                        offset <= 0;
                        section <= FRAME_CHECK_SEQUENCE;
                    end if;

                when PADDING =>
                    -- Pad with zeroes
                    dibit := "00";

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
                    dibit(0) := fcs_calc(pos);
                    dibit(1) := fcs_calc(pos - 1);

                    -- Wait for final FCS dibit, then transit
                    if offset < FCS_LAST_DIBIT then
                        offset <= offset + 1;
                    else
                        offset <= 0;
                        state <= INTER_PACKET_GAP;
                    end if;
                end case;

                -- Update our calculated FCS
                if section /= FRAME_CHECK_SEQUENCE then
                    prev_crc <= CRC32_t_INIT when
                                section = DESTINATION_MAC and offset = 0
                                else crc;
                    crc_dibit(1) <= dibit(0);
                    crc_dibit(0) <= dibit(1);
                end if;

                -- Transmit dibit that was selected
                txd <= dibit;
                tx_en <= '1';

            when INTER_PACKET_GAP =>
                txd <= "00";
                tx_en <= '0';
                
                -- Wait for final IPG dibit, then transit
                if offset < IPG_LAST_DIBIT then
                    offset <= offset + 1;
                else
                    state <= WAIT_FOR_FRAME;
                end if;

                state <= WAIT_FOR_FRAME;
            end case;
            prev_i_valid <= i_valid;
        end if;
    end process;
    phy.txd <= txd;
    phy.tx_en <= tx_en;

    -- Frame check sequence calculator
    fcs_calculator : work.ethernet.fcs_calculator
        port map (
            i_crc   => prev_crc,
            i_dibit => crc_dibit,
            o_crc   => crc,
            o_fcs   => fcs_calc
        );

end behavioral;
