library work;
    use work.ethernet.all;
    use work.protocol.all;

library util;
    use util.audio.all;
    use util.types.all;

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity ethernet_trx is
    port (
        i_clk  : in   std_logic;
        phy    : view Phy_t;
        writer : view PeriodFifo_Writer_t;
        o_leds : out  std_logic_vector(15 downto 0);
    );
end ethernet_trx;

architecture behavioral of ethernet_trx is

    constant CLKS_PER_SEC : natural := 50000000;

    -- Session state
    type SessionState_t is (
        WAIT_FOR_HANDSHAKE_REQUEST,
        SEND_ANNOUNCE,
        SEND_HANDSHAKE_RESPONSE,
        SESSION_OPEN,
        SEND_HEARTBEAT,
        SEND_CLOSE
    );
    signal session_state    : SessionState_t := WAIT_FOR_HANDSHAKE_REQUEST;
    signal prev_rx_valid    : std_logic      := '0';
    signal host_mac_address : MacAddress_t   := MAC_ADDRESS_BROADCAST;
    signal generation_id    : GenerationId_t := to_unsigned(0, 8);
    signal counter          : natural        := 0;
    signal elapsed          : natural        := 0;

    -- 50MHz reference clk that drives ethernet PHY
    component ip_clk_wizard_ethernet is
        port (
            i_eth_clk : in  std_logic;
            o_eth_clk : out std_logic;
        );
    end component;
    signal ref_clk : std_logic := '0';

    -- Intermediate signals for ethernet_rx
    signal rx_frame : Frame_t   := Frame_t_INIT;
    signal rx_valid : std_logic := '0';

    -- Intermediate signals for ethernet_tx
    signal tx_frame : Frame_t   := Frame_t_INIT;
    signal tx_valid : std_logic := '0';

begin

    session_sm : process(ref_clk)
        variable pcm_data_msg : PcmDataMsg_t;
        variable period       : Period_t;
    begin
        if rising_edge(ref_clk) then

            -- Will be overwritten when a PCM data msg is received
            writer.enable <= '0';

            case session_state is
            when WAIT_FOR_HANDSHAKE_REQUEST =>
                -- If we've received a handshake request, transit
                if prev_rx_valid = '0' and rx_valid = '1' and
                   is_valid_handshake_request(rx_frame)
                then
                    host_mac_address <= rx_frame.src_mac;

                    counter <= 0;
                    session_state <= SEND_HANDSHAKE_RESPONSE;

                -- Otherwise, send an announce message once per second
                elsif counter < ANNOUNCE_INTERVAL * CLKS_PER_SEC then
                    counter <= counter + 1;
                else
                    counter <= 0;
                    session_state <= SEND_ANNOUNCE;
                end if;

            when SEND_ANNOUNCE =>
                if counter = 0 then
                    tx_valid <= '0';
                    counter <= 1;
                else
                    tx_frame <= build_session_ctl_msg(
                        dest_mac      => host_mac_address,
                        src_mac       => MAC_ADDRESS_CCO,
                        generation_id => generation_id,
                        msg_type      => SessionCtl_Announce
                    );
                    tx_valid <= '1';

                    counter <= 0;
                    session_state <= WAIT_FOR_HANDSHAKE_REQUEST;
                end if;

            when SEND_HANDSHAKE_RESPONSE =>
                if counter = 0 then
                    tx_valid <= '0';
                    counter <= 1;
                else
                    tx_frame <= build_session_ctl_msg(
                        dest_mac      => host_mac_address,
                        src_mac       => MAC_ADDRESS_CCO,
                        generation_id => generation_id,
                        msg_type      => SessionCtl_HandshakeResponse
                    );
                    tx_valid <= '1';

                    counter <= 0;
                    elapsed <= 0;
                    session_state <= SESSION_OPEN;
                end if;

            when SESSION_OPEN =>
                -- Send a heartbeat once per second
                if counter < HEARTBEAT_INTERVAL * CLKS_PER_SEC then
                    counter <= counter + 1;
                else
                    counter <= 0;
                    session_state <= SEND_HEARTBEAT;
                end if;

                -- If we've received a CCO msg, reset elapsed timer
                if prev_rx_valid = '0' and rx_valid = '1' and
                   is_valid_msg(rx_frame)
                then
                    elapsed <= 0;

                    if is_valid_pcm_data_msg(rx_frame) then
                        pcm_data_msg := get_pcm_data_msg(rx_frame);
                        period := get_period(pcm_data_msg.period);
                        writer.data <= period;
                        writer.enable <= '1';
                    end if;

                -- Otherwise, close session if we've exceeded heartbeat timeout
                elsif elapsed < TIMEOUT_INTERVAL * CLKS_PER_SEC then
                    elapsed <= elapsed + 1;
                else
                    elapsed <= 0;
                    counter <= 0;
                    session_state <= SEND_CLOSE;
                end if;

            when SEND_HEARTBEAT =>
                if counter = 0 then
                    tx_valid <= '0';
                    counter <= 1;
                else
                    tx_frame <= build_session_ctl_msg(
                        dest_mac      => host_mac_address,
                        src_mac       => MAC_ADDRESS_CCO,
                        generation_id => generation_id,
                        msg_type      => SessionCtl_Heartbeat
                    );
                    tx_valid <= '1';

                    counter <= 0;
                    session_state <= SESSION_OPEN;
                end if;

            when SEND_CLOSE =>
                if counter = 0 then
                    tx_valid <= '0';
                    counter <= 1;
                else
                    tx_frame <= build_session_ctl_msg(
                        dest_mac      => host_mac_address,
                        src_mac       => MAC_ADDRESS_CCO,
                        generation_id => generation_id,
                        msg_type      => SessionCtl_Close
                    );
                    tx_valid <= '1';

                    host_mac_address <= MAC_ADDRESS_BROADCAST;

                    if generation_id < MAX_GENERATION_ID then
                        generation_id <= generation_id + 1;
                    else
                        generation_id <= to_unsigned(0, 8);
                    end if;

                    counter <= 0;
                    session_state <= WAIT_FOR_HANDSHAKE_REQUEST;
                end if;
            end case;
            prev_rx_valid <= rx_valid;
        end if;
    end process;
    writer.clk <= ref_clk;

    -- Derives 50MHz clk from 100MHz clk for feeding into PHY
    generate_50mhz_ref_clk : ip_clk_wizard_ethernet
        port map (
            i_eth_clk => i_clk,
            o_eth_clk => ref_clk
        );
    phy.clkin <= ref_clk;

    -- Ethernet receiving
    ethernet_rx : work.ethernet.ethernet_rx
        port map (
            i_ref_clk => ref_clk,
            phy       => phy,
            o_frame   => rx_frame,
            o_valid   => rx_valid
        );

    ethernet_tx : work.ethernet.ethernet_tx
        port map (
            i_ref_clk => ref_clk,
            phy       => phy,
            i_frame   => tx_frame,
            i_valid   => tx_valid
        );

end behavioral;
