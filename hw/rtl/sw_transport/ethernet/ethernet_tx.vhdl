library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.ethernet.all;

entity ethernet_tx is
    port (
        i_ref_clk : in   std_logic;
        phy       : view EthernetPhy_t;
        i_packet  : in   EthernetPacket_t;
        i_size    : in   natural;
        i_valid   : in   std_logic;
    );
end ethernet_tx;

architecture behavioral of ethernet_tx is

    -- Input data buffering state
    signal prev_i_valid : std_logic        := '0';
    signal packet       : EthernetPacket_t := (others => '0');
    signal size         : natural          := 0;

    -- Transmit state
    type State_t is (
        WAIT_FOR_DATA,         -- Wait for user to present packet for TX
        PREAMBLE,              -- Transmit full preamble (7 bytes)
        START_FRAME_DELIMITER, -- Transmit full SFD      (1 byte)
        PAYLOAD,               -- Transmit full payload  (n bytes)
        FRAME_CHECK_SEQUENCE,  -- Transmit full FCS      (4 bytes)
        INTER_PACKET_GAP       -- Idle period before transmitting again
    );
    signal state      : State_t := WAIT_FOR_DATA;
    signal dibit      : natural := 0;
    signal bytes_sent : natural := 0;

    -- Intermediate signals for fcs_calculator
    signal prev_crc  : EthernetFCS_t                := (others => '0');
    signal crc_dibit : std_logic_vector(1 downto 0) := (others => '0');
    signal crc       : EthernetFCS_t                := (others => '0');
    signal fcs_calc  : EthernetFCS_t                := (others => '0');

    -- Intermediate signals
    signal txd   : std_logic_vector(1 downto 0) := (others => '0');
    signal tx_en : std_logic                    := '0';

begin

    -- Transmit state machine
    --
    -- Note: i_ref_clk is the 50MHz clock that is fed into phy.clkin
    transmit_sm : process(i_ref_clk)
    begin
        if rising_edge(i_ref_clk) then
            case state is
                when WAIT_FOR_DATA =>
                    -- Wait for user to present data, latch it, then transit
                    if prev_i_valid = '0' and i_valid = '1' then
                        packet <= i_packet;
                        size <= i_size;
                        dibit <= 0;
                        state <= PREAMBLE;
                    end if;

                when PREAMBLE =>

                    txd <= VALID_PREAMBLE_DIBIT;
                    tx_en <= '1';

                    -- Wait for last preamble dibit, then transit
                    if dibit < PREAMBLE_LAST_DIBIT then
                        dibit <= dibit + 1;
                    else
                        dibit <= 0;
                        state <= START_FRAME_DELIMITER;
                    end if;

                when START_FRAME_DELIMITER =>

                    txd <= VALID_SFD_DIBIT_REST
                               when dibit < SFD_LAST_DIBIT
                               else VALID_SFD_DIBIT_LAST;
                    tx_en <= '1';

                    -- Wait for last SFD dibit, then transit
                    if dibit < SFD_LAST_DIBIT then
                        dibit <= dibit + 1;
                    else
                        dibit <= 0;
                        bytes_sent <= 0;
                        state <= PAYLOAD;
                    end if;

                when PAYLOAD =>

                    -- Note: although ethernet transmits bytes in the order
                    -- in which they appear in the packet, each individual
                    -- byte is transmitted from lsb -> msb.
                    --
                    -- To compute the location in the packet where this
                    -- dibit should be placed, we start with an offset that
                    -- points at the beginning of the byte after the one
                    -- currently being transmitted.
                    --
                    -- Then, we count backwards for however many dibits
                    -- have been transmitted in the current byte.
                    --
                    txd <= packet(
                        ((dibit / DIBITS_PER_BYTE) + 1) * BITS_PER_BYTE -
                        ((dibit mod DIBITS_PER_BYTE) + 1) * BITS_PER_DIBIT
                    to
                        ((dibit / DIBITS_PER_BYTE) + 1) * BITS_PER_BYTE -
                        ((dibit mod DIBITS_PER_BYTE) + 1) * BITS_PER_DIBIT + 1
                    );
                    tx_en <= '1';

                    -- Update calculated FCS
                    with dibit select prev_crc <=
                        (others => '1') when 0,
                        crc             when others;
                    crc_dibit(0) <= packet(
                        ((dibit / DIBITS_PER_BYTE) + 1) * BITS_PER_BYTE -
                        ((dibit mod DIBITS_PER_BYTE) + 1) * BITS_PER_DIBIT
                    );
                    crc_dibit(1) <= packet(
                        ((dibit / DIBITS_PER_BYTE) + 1) * BITS_PER_BYTE -
                        ((dibit mod DIBITS_PER_BYTE) + 1) * BITS_PER_DIBIT + 1
                    );

                    -- Wait for last payload bit, then transit
                    if dibit + 1 < size * DIBITS_PER_BYTE then
                        dibit <= dibit + 1;
                    else
                        dibit <= 0;
                        state <= FRAME_CHECK_SEQUENCE;
                    end if;

                when FRAME_CHECK_SEQUENCE =>

                    txd(0) <= fcs_calc(31 - dibit*BITS_PER_DIBIT);
                    txd(1) <= fcs_calc(30 - dibit*BITS_PER_DIBIT);
                    tx_en <= '1';

                    -- Wait for last FCS dibit, end transmission, then transit
                    if dibit < FCS_LAST_DIBIT then
                        dibit <= dibit + 1;
                    else
                        dibit <= 0;
                        state <= INTER_PACKET_GAP;
                    end if;

                when INTER_PACKET_GAP =>

                    txd <= "00";
                    tx_en <= '0';

                    -- Wait for last IPG dibit, then transit
                    if dibit < IPG_LAST_DIBIT then
                        dibit <= dibit + 1;
                    else
                        dibit <= 0;
                        state <= WAIT_FOR_DATA;
                    end if;
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
