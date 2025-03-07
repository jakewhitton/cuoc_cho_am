library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library sw_transport;
    use sw_transport.ethernet.all;

library util;
    use util.types.all;

library work;
    use work.spdif.all;

entity spdif_status_bit_dumper is
    port (
        i_clk        : in   std_logic;
        i_spdif      : in   std_logic;
        ethernet_phy : view EthernetPhy_t;
    );
end spdif_status_bit_dumper;

architecture behavioral of spdif_status_bit_dumper is

    -- Signals for spdif_rx_serial_bridge
    signal reset  : std_logic := '0';
    signal sdata  : std_logic := '0';
    signal sclk   : std_logic := '0';
    signal bsync  : std_logic := '0';
    signal lrck   : std_logic := '0';
    signal active : std_logic := '0';

    -- State for parse_sm_proc
    type State_t is (WAITING_FOR_FRAME, PREAMBLE, SAMPLE, STATUS);
    signal state       : State_t   := WAITING_FOR_FRAME;
    signal counter     : natural   := 0;
    signal last_lrck   : std_logic := '0';
    
    subtype StatusBits_t is std_logic_vector(0 to 191);
    signal valid_bits   : StatusBits_t := (others => '0');
    signal user_bits    : StatusBits_t := (others => '0');
    signal channel_bits : StatusBits_t := (others => '0');

    -- Frame tracking state

    -- Sending state
    signal frame : natural := 0;
    signal last_lrck_dup   : std_logic := '0';
    signal last_bsync  : std_logic := '0';

    -- Ethernet state
    component ip_clk_wizard_ethernet is
        port (
            i_eth_clk : in  std_logic;
            o_eth_clk : out std_logic;
        );
    end component;
    signal ethernet_phy_tx     : EthernetTxPhy_t;
    signal ethernet_ref_clk    : std_logic := '0';
    signal tx_frame            : Frame_t   := Frame_t_INIT;
    signal tx_valid            : std_logic := '0';

begin

    tx_frame.dest_mac <= MAC_ADDRESS_BROADCAST;
    tx_frame.src_mac  <= MAC_ADDRESS_CCO;
    tx_frame.length   <= Length_t(to_unsigned(148, 16));
    tx_frame.payload(0 to 191)   <= valid_bits;
    tx_frame.payload(192 to 383) <= user_bits;
    tx_frame.payload(384 to 575) <= channel_bits;
    tx_frame.payload(
        (144 * BITS_PER_BYTE) to (148 * BITS_PER_BYTE) - 1
    ) <= X"DEADBEEF";

    -- S/PDIF => serial bridge
    spdif_rx_serial_bridge : work.spdif.spdif_rx_serial_bridge
        generic map (
            reg_width => 5
        )
        port map (
            clk    => i_clk,
            aes3   => i_spdif,
            reset  => reset,
            sdata  => sdata,
            sclk   => sclk,
            bsync  => bsync,
            lrck   => lrck,
            active => active
        );

    parse_sm_proc : process(sclk)
    begin
        if rising_edge(sclk) then
            case state is

                when WAITING_FOR_FRAME =>
                    if lrck /= last_lrck then
                        -- This is the first bit of a preamble
                        counter <= 1;
                        state <= PREAMBLE;
                    end if;

                when PREAMBLE =>
                    -- Wait for the 4th preamble bit, then transit to SAMPLE
                    if counter < 3 then
                        counter <= counter + 1;
                    else
                        counter <= 0;
                        state <= SAMPLE;
                    end if;

                when SAMPLE =>
                    if counter < 23 then
                        counter <= counter + 1;
                    else
                        counter <= 0;
                        state <= STATUS;
                    end if;

                when STATUS =>
                    -- Capture the bits we care about
                    if counter = 0 then
                        valid_bits(frame) <= sdata;
                    elsif counter = 1 then
                        user_bits(frame) <= sdata;
                    elsif counter = 2 then
                        channel_bits(frame) <= sdata;
                    elsif counter = 3 then
                        -- Ignore parity bit
                    end if;

                    -- Wait for the 4th status bit, then transit to WAITING_FOR_FRAME
                    if counter < 3 then
                        counter <= counter + 1;
                    else
                        counter <= 0;
                        state <= WAITING_FOR_FRAME;
                    end if;

            end case;

            last_lrck <= lrck;
        end if;
    end process;

    send_frames : process(i_clk)
    begin
        if rising_edge(i_clk) then

            -- Will be overwritten if needed
            tx_valid <= '0';

            if last_bsync = '0' and bsync = '1' then
                tx_valid <= '1';
                frame <= 0;
            elsif last_lrck_dup = '1' and lrck = '0' then
                if frame < 191 then
                    frame <= frame + 1;
                else
                    frame <= 0;
                end if;
            end if;

            last_lrck_dup <= lrck;
            last_bsync <= bsync;
        end if;
    end process;

    generate_50mhz_ref_clk : ip_clk_wizard_ethernet
        port map (
            i_eth_clk => i_clk,
            o_eth_clk => ethernet_ref_clk
        );
    
    ethernet_tx : sw_transport.ethernet.ethernet_tx
        port map (
            i_ref_clk => ethernet_ref_clk,
            phy       => ethernet_phy_tx,
            i_frame   => tx_frame,
            i_valid   => tx_valid
        );

    ethernet_phy.clkin     <= ethernet_ref_clk;
    ethernet_phy.tx.data   <= ethernet_phy_tx.data;
    ethernet_phy.tx.enable <= ethernet_phy_tx.enable;

end behavioral;
