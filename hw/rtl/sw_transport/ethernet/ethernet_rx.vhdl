library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet.all;

entity ethernet_rx is
    port (
        i_ref_clk : in   std_logic;
        phy       : view EthernetPhy_t;
        o_leds    : out  std_logic_vector(15 downto 0);
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
        PAYLOAD                    -- Receive full payload  (n bytes)
    );
    signal state       : State_t := WAIT_FOR_CARRIER_ABSENCE;
    signal dibit       : natural := 0; -- Dibit offset into frame section
    signal num_packets : natural := 0; -- Counts number of packets recv'd

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
                        dibit <= 0;
                        state <= PAYLOAD;
                    end if;

                when PAYLOAD =>
                    -- Wait for carrier to end, then transit
                    if phy.crs_dv = '0' then
                        num_packets <= num_packets + 1;
                        state <= WAIT_FOR_CARRIER_PRESENCE;
                    end if;
            end case;

        end if;

    end process;
    o_leds <= std_logic_vector(to_unsigned(num_packets, 16));

end behavioral;
