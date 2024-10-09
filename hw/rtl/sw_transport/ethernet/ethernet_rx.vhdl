library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.ethernet.all;

entity ethernet_rx is
    port (
        i_ref_clk : in   std_logic;
        phy       : view EthernetPhy_t;
        o_packet  : out  EthernetPacket_t;
        o_size    : out  natural;
        o_fcs     : out  EthernetFCS_t;
        o_valid   : out  std_logic;
    );
end ethernet_rx;

architecture behavioral of ethernet_rx is

    -- Receive state
    type State_t is (
        WAIT_FOR_CARRIER_ABSENCE,  -- Wait for CRS_DV to go low
        WAIT_FOR_CARRIER_PRESENCE, -- Wait for CRS_DV to go high
        WAIT_FOR_PREAMBLE,         -- Wait for preamble to start
        PREAMBLE,                  -- Receive full preamble (7 bytes)
        START_FRAME_DELIMITER,     -- Receive full SFD      (1 byte)
        PAYLOAD,                   -- Receive full payload  (n bytes)
        EXTRACT_FCS,               -- Pull out FCS from payload
        PUBLISH_PACKET             -- Publish packet
    );
    signal state : State_t := WAIT_FOR_CARRIER_ABSENCE;
    signal dibit : natural := 0;

    -- Intermediate signals
    signal size  : natural   := 0;
    signal valid : std_logic := '0';

begin

    -- Receive state machine
    --
    -- Note: i_ref_clk is the 50MHz clock that is fed into phy.clkin
    recv_sm : process(i_ref_clk)
    begin
        if rising_edge(i_ref_clk) then
            case state is
                when WAIT_FOR_CARRIER_ABSENCE =>
                    -- Wait for CRS_DV to go low, then transit
                    if phy.crs_dv = '0' then
                        state <= WAIT_FOR_CARRIER_PRESENCE;
                    end if;

                when WAIT_FOR_CARRIER_PRESENCE =>
                    -- Wait for CRS_DV to go high, then transit
                    if phy.crs_dv = '1' then
                        state <= WAIT_FOR_PREAMBLE;
                    end if;

                when WAIT_FOR_PREAMBLE =>
                    -- If carrier has been lost, wait for carrier
                    if phy.crs_dv = '0' then
                        state <= WAIT_FOR_CARRIER_PRESENCE;

                    -- Otherwise, wait for first preamble dibit, then transit
                    elsif phy.rxd = VALID_PREAMBLE_DIBIT then
                        dibit <= 1;
                        state <= PREAMBLE;
                    end if;

                when PREAMBLE =>
                    -- If carrier has been lost, wait for carrier
                    if phy.crs_dv = '0' then
                        state <= WAIT_FOR_CARRIER_PRESENCE;

                    -- Otherwise, if we detect false carrier, abandon packet
                    elsif phy.rxd /= VALID_PREAMBLE_DIBIT then
                        state <= WAIT_FOR_CARRIER_ABSENCE;

                    -- Otherwise, wait for last preamble dibit, then transit
                    elsif dibit < PREAMBLE_LAST_DIBIT then
                        dibit <= dibit + 1;
                    else
                        dibit <= 0;
                        state <= START_FRAME_DELIMITER;
                    end if;

                when START_FRAME_DELIMITER =>
                    -- If carrier has been lost, wait for carrier
                    if phy.crs_dv = '0' then
                        state <= WAIT_FOR_CARRIER_PRESENCE;

                    -- Otherwise, if we detect false carrier, abandon packet
                    elsif ( dibit < SFD_LAST_DIBIT
                            and phy.rxd /= VALID_SFD_DIBIT_REST ) or
                          ( dibit = SFD_LAST_DIBIT
                            and phy.rxd /= VALID_SFD_DIBIT_LAST )
                    then
                        state <= WAIT_FOR_CARRIER_ABSENCE;

                    -- Otherwise, wait for last SFD dibit, then transit
                    elsif dibit < SFD_LAST_DIBIT then
                        dibit <= dibit + 1;
                    else
                        dibit    <= 0;
                        o_packet <= (others => '0');
                        o_fcs    <= (others => '0');
                        size     <= 0;
                        valid    <= '0';
                        state    <= PAYLOAD;
                    end if;

                when PAYLOAD =>
                    -- If data is still being presented, receive it
                    if phy.crs_dv = '1' then

                        -- Note: although ethernet transmits bytes in the order
                        -- in which they appear in the packet, each individual
                        -- byte is transmitted from lsb -> msb.
                        --
                        -- To compute the location in the packet where this
                        -- dibit should be placed, we start with an offset that
                        -- points at the beginning of the byte after the one
                        -- currently being received.
                        --
                        -- Then, we count backwards for however many dibits
                        -- have been received in the current byte.
                        --
                        o_packet(
                            (size + 1) * BITS_PER_BYTE -
                                (dibit + 1) * BITS_PER_DIBIT
                        to
                            (size + 1) * BITS_PER_BYTE -
                                (dibit + 1) * BITS_PER_DIBIT + 1
                        ) <= phy.rxd;

                        if dibit + 1 < DIBITS_PER_BYTE then
                            dibit <= dibit + 1;
                        else
                            size <= size + 1;
                            dibit <= 0;
                        end if;

                    -- Otherwise, transit
                    else
                        state <= EXTRACT_FCS;
                    end if;

                when EXTRACT_FCS =>
                    -- Restore transmission order for FCS
                    for byte in 0 to 3 loop
                        for i in 0 to 7 loop
                            o_fcs(31 - (byte*BITS_PER_BYTE + i)) <= o_packet(
                                (size-4)*BITS_PER_BYTE +
                                (byte + 1)*BITS_PER_BYTE - (i + 1)
                            );
                        end loop;
                    end loop;

                    -- Remove FCS from packet
                    o_packet(
                        (size - 4)*BITS_PER_BYTE to
                        size*BITS_PER_BYTE - 1
                    ) <= (others => '0');
                    size <= size - 4;

                    -- Transit
                    state <= PUBLISH_PACKET;

                when PUBLISH_PACKET =>
                    valid <= '1';
                    state <= WAIT_FOR_CARRIER_PRESENCE;
            end case;
        end if;
    end process;
    o_size <= size;
    o_valid <= valid;

end behavioral;
