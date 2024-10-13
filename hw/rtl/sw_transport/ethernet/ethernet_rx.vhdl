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
        FRAME                      -- Receive full frame    (n bytes)
    );
    signal state    : State_t       := WAIT_FOR_CARRIER_ABSENCE;
    signal dibit    : natural       := 0;
    signal fcs_recv : EthernetFCS_t := (others => '0');

    -- Intermediate signals for fcs_calculator
    signal prev_crc  : EthernetFCS_t                := (others => '0');
    signal crc_dibit : std_logic_vector(1 downto 0) := (others => '0');
    signal crc       : EthernetFCS_t                := (others => '0');
    signal fcs_calc  : EthernetFCS_t                := (others => '0');

    -- Intermediate signals
    signal packet   : EthernetPacket_t := (others => '0');
    signal size     : natural          := 0;
    signal valid    : std_logic        := '0';

begin

    -- Receive state machine
    --
    -- Note: i_ref_clk is the 50MHz clock that is fed into phy.clkin
    recv_sm : process(i_ref_clk)
        variable byte : natural := 0;
        variable rest : natural := 0;
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
                        packet   <= (others => '0');
                        size     <= 0;
                        fcs_recv <= (others => '0');
                        valid    <= '0';
                        state    <= frame;
                    end if;

                when FRAME =>
                    -- If data is still being presented, receive it
                    if phy.crs_dv = '1' then

                        -- Shift dibits into fcs_recv, preserving transmit order
                        fcs_recv(31 downto 2) <= fcs_recv(29 downto 0);
                        fcs_recv(1)           <= phy.rxd(0);
                        fcs_recv(0)           <= phy.rxd(1);

                        -- Once fcs_recv has been filled, start spilling dibits
                        -- over to packet, along with FCS calculation
                        if dibit > FCS_LAST_DIBIT then

                            byte := (dibit - 16) / DIBITS_PER_BYTE;
                            rest := dibit mod DIBITS_PER_BYTE;

                            size <= byte + 1;

                            -- Place dibit in packet
                            packet(
                                (byte + 1) * BITS_PER_BYTE -
                                    (rest + 1) * BITS_PER_DIBIT
                            ) <= fcs_recv(30);
                            packet(
                                (byte + 1) * BITS_PER_BYTE -
                                    (rest + 1) * BITS_PER_DIBIT + 1
                            ) <= fcs_recv(31);

                            -- Update calculated FCS
                            with dibit select prev_crc <=
                                (others => '1') when FCS_LAST_DIBIT + 1,
                                crc             when others;
                            crc_dibit <= fcs_recv(31 downto 30);
                        end if;

                        dibit <= dibit + 1;

                    -- Otherwise, publish packet if CRC is valid, then transit
                    else
                        if fcs_recv = fcs_calc then
                            valid <= '1';
                        end if;
                        state <= WAIT_FOR_CARRIER_PRESENCE;
                    end if;
            end case;
        end if;
    end process;
    o_packet <= packet;
    o_size   <= size;
    o_fcs    <= fcs_recv;
    o_valid  <= valid;

    -- Frame check sequence calculator
    fcs_calculator : work.ethernet.fcs_calculator
        port map (
            i_crc   => prev_crc,
            i_dibit => crc_dibit,
            o_crc   => crc,
            o_fcs   => fcs_calc
        );

end behavioral;
