library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library work;
    use work.ethernet.all;
    use work.protocol.all;

entity ethernet_trx is
    port (
        i_clk  : in   std_logic;
        phy    : view Phy_t;
        o_leds : out  std_logic_vector(15 downto 0);
    );
end ethernet_trx;

architecture behavioral of ethernet_trx is

    -- Session state
    type SessionState_t is (
        WAIT_FOR_HANDSHAKE_REQUEST,
        SEND_ANNOUNCE,
        SEND_HANDSHAKE_RESPONSE,
        SESSION_OPEN,
        SEND_HEARTBEAT
    );
    signal   session_state : SessionState_t := WAIT_FOR_HANDSHAKE_REQUEST;
    signal   prev_rx_valid : std_logic      := '0';
    signal   counter       : natural        := 0;
    constant CLKS_PER_SEC  : natural        := 50000000;

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
    begin
        if rising_edge(ref_clk) then
            case session_state is
            when WAIT_FOR_HANDSHAKE_REQUEST =>
                -- If we've received a handshake request, transit
                if prev_rx_valid = '0' and rx_valid = '1' and
                   is_valid_handshake_request(rx_frame)
                then
                    counter <= 0;
                    session_state <= SEND_HANDSHAKE_RESPONSE;

                -- Otherwise, send an announce message once per second
                elsif counter < CLKS_PER_SEC then
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
                    tx_frame.length <= X"0006";
                    tx_frame.payload <= (others => '0');
                    tx_frame.payload(
                        0 to (4 * BITS_PER_BYTE) - 1
                    ) <= CCO_MAGIC;
                    tx_frame.payload(
                        (4 * BITS_PER_BYTE) to (5 * BITS_PER_BYTE) - 1
                    ) <= SessionCtlMsg_t'msg_type;
                    tx_frame.payload(
                        (5 * BITS_PER_BYTE) to (6 * BITS_PER_BYTE) - 1
                    ) <= SessionCtl_Announce;
                    tx_valid <= '1';

                    counter <= 0;
                    session_state <= WAIT_FOR_HANDSHAKE_REQUEST;
                end if;

            when SEND_HANDSHAKE_RESPONSE =>
                if counter = 0 then
                    tx_valid <= '0';
                    counter <= 1;
                else
                    tx_frame.length <= X"0006";
                    tx_frame.payload <= (others => '0');
                    tx_frame.payload(
                        0 to (4 * BITS_PER_BYTE) - 1
                    ) <= CCO_MAGIC;
                    tx_frame.payload(
                        (4 * BITS_PER_BYTE) to (5 * BITS_PER_BYTE) - 1
                    ) <= SessionCtlMsg_t'msg_type;
                    tx_frame.payload(
                        (5 * BITS_PER_BYTE) to (6 * BITS_PER_BYTE) - 1
                    ) <= SessionCtl_HandshakeResponse;
                    tx_valid <= '1';

                    counter <= 0;
                    session_state <= SESSION_OPEN;
                end if;

            when SESSION_OPEN =>
                -- TODO

            when SEND_HEARTBEAT =>
                -- TODO
            end case;
            prev_rx_valid <= rx_valid;
        end if;
    end process;
    tx_frame.dest_mac <= X"FFFFFFFFFFFF";
    tx_frame.src_mac  <= X"123456789ABC";
    with session_state select o_leds(15 downto 11) <=
        "10000" when WAIT_FOR_HANDSHAKE_REQUEST,
        "01000" when SEND_ANNOUNCE,
        "00100" when SEND_HANDSHAKE_RESPONSE,
        "00010" when SESSION_OPEN,
        "00001" when SEND_HEARTBEAT;

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
