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
        i_clk           : in   std_logic;
        phy             : view EthernetPhy_t;
        playback_writer : view PeriodFifo_Writer_t;
        capture_reader  : view PeriodFifo_Reader_t;
        o_streams       : out  Streams_t;
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
        SEND_CLOSE,
        SEND_PCM_DATA
    );
    signal session_state    : SessionState_t    := WAIT_FOR_HANDSHAKE_REQUEST;
    signal prev_rx_valid    : std_logic         := '0';
    signal host_mac_address : MacAddress_t      := MAC_ADDRESS_BROADCAST;
    signal generation_id    : GenerationId_t    := to_unsigned(0, 8);
    signal counter          : natural           := 0;
    signal elapsed          : natural           := 0;
    signal playback_period  : Period_t          := Period_t_INIT;
    signal pcm_data_seqnum  : unsigned(0 to 31) := to_unsigned(0, 32);
    signal capture_period   : Period_t          := Period_t_INIT;
    signal streams          : Streams_t         := Streams_t_INIT;

    -- 50MHz reference clk that drives ethernet PHY
    component ip_clk_wizard_ethernet is
        port (
            i_eth_clk : in  std_logic;
            o_eth_clk : out std_logic;
        );
    end component;
    signal ref_clk : std_logic := '0';

    -- Intermediate signals for ethernet_rx
    signal phy_rx   : EthernetRxPhy_t;
    signal rx_frame : Frame_t   := Frame_t_INIT;
    signal rx_valid : std_logic := '0';

    -- Intermediate signals for ethernet_tx
    signal phy_tx   : EthernetTxPhy_t;
    signal tx_frame : Frame_t   := Frame_t_INIT;
    signal tx_valid : std_logic := '0';

begin

    -- Unwrap view of phy
    phy_rx.data   <= phy.rx.data;
    phy_rx.crs_dv <= phy.rx.crs_dv;
    phy.tx.data   <= phy_tx.data;
    phy.tx.enable <= phy_tx.enable;

    session_sm : process(ref_clk)
        variable pcm_ctl_msg  : PcmCtlMsg_t;
        variable pcm_data_msg : PcmDataMsg_t;
    begin
        if rising_edge(ref_clk) then

            -- Will be overwritten when a PCM data msg is received
            playback_writer.enable <= '0';
            capture_reader.enable <= '0';

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

                -- If we've received a period via capture, transmit it
                if capture_reader.empty = '0' then
                    capture_period <= capture_reader.data;
                    capture_reader.enable <= '1';

                    session_state <= SEND_PCM_DATA;
                    counter <= 0;
                end if;

                -- If we've received a CCO msg, reset elapsed timer
                if prev_rx_valid = '0' and rx_valid = '1' and
                   is_valid_msg(rx_frame)
                then
                    elapsed <= 0;

                    if is_valid_pcm_ctl_msg(rx_frame) then
                        pcm_ctl_msg := get_pcm_ctl_msg(rx_frame);
                        streams <= pcm_ctl_msg.streams;

                    elsif is_valid_pcm_data_msg(rx_frame) then
                        pcm_data_msg := get_pcm_data_msg(rx_frame);
                        playback_period <= get_period(pcm_data_msg.period);
                        playback_writer.enable <= '1';
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

            when SEND_PCM_DATA =>
                if counter = 0 then
                    tx_valid <= '0';
                    counter <= 1;
                else
                    tx_frame <= build_pcm_data_msg(
                        dest_mac      => host_mac_address,
                        src_mac       => MAC_ADDRESS_CCO,
                        generation_id => generation_id,
                        seqnum        => pcm_data_seqnum,
                        period        => capture_period
                    );
                    tx_valid <= '1';

                    pcm_data_seqnum <= pcm_data_seqnum + 1;

                    counter <= 0;
                    session_state <= SESSION_OPEN;
                end if;
            end case;
            prev_rx_valid <= rx_valid;
        end if;
    end process;
    playback_writer.clk <= ref_clk;
    playback_writer.data <= playback_period;
    capture_reader.clk <= ref_clk;
    o_streams <= streams;

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
            phy       => phy_rx,
            o_frame   => rx_frame,
            o_valid   => rx_valid
        );

    ethernet_tx : work.ethernet.ethernet_tx
        port map (
            i_ref_clk => ref_clk,
            phy       => phy_tx,
            i_frame   => tx_frame,
            i_valid   => tx_valid
        );

end behavioral;
