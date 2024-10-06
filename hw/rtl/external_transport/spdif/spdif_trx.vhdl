library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.spdif.all;

entity spdif_trx is
    port (
        i_clk   : in  std_logic;
        i_spdif : in  std_logic;
        o_spdif : out std_logic
    );
end spdif_trx;

architecture behavioral of spdif_trx is

    --signal valid   : std_logic                     := '0';
    --signal channel : std_logic                     := '0';
    --signal sample  : std_logic_vector(23 downto 0) := (others => '0');
    --signal sclk    : std_logic                     := '0';

    signal spdif_tx_clk : std_logic  := '0';

    component ip_clk_wizard_spdif
        port (
            i_spdif_clk : in  std_logic;
            o_spdif_clk : out std_logic;
        );
    end component;

    signal spdif_tx_subframe        : Subframe_t := Subframe_t_SQUARE_WAVE_LOW;
    signal spdif_tx_channel_left    : std_logic_vector(0 to 191) := (others => '0');
    signal spdif_tx_channel_right   : std_logic_vector(0 to 191) := (others => '0');
    signal spdif_tx_enable          : std_logic  := '1';
    signal spdif_tx_finish_subframe : std_logic  := '0';

    -- (48,000 sample/1s)*(1s/440 transition) ~= 109 sample/transition
    constant samples_to_hold_value : natural := 109;
    signal sine_wave_counter       : natural := 0;

begin

    -- S/PDIF receiver
    --spdif_rx : work.spdif.spdif_rx
    --    port map (
    --        i_clk     => i_clk,
    --        i_spdif   => i_spdif,
    --        o_valid   => valid,
    --        o_channel => channel,
    --        o_sample  => sample,
    --        o_sclk    => sclk
    --    );

    generate_spdif_tx_clk : ip_clk_wizard_spdif
        port map (
            i_spdif_clk => i_clk,
            o_spdif_clk => spdif_tx_clk
        );

    -- Channel bit setting
    --
    -- Copy permit
    spdif_tx_channel_left(2)  <= '1';
    spdif_tx_channel_right(2) <= '1';
    --
    -- sampling frequency = 48khz
    spdif_tx_channel_left(24 to 27)  <= "0100";
    spdif_tx_channel_right(24 to 27) <= "0100";
    --
    -- word length = 24 bit, full word
    spdif_tx_channel_left(32 to 35)  <= "1101";
    spdif_tx_channel_right(32 to 35) <= "1101";

    -- S/PDIF transmitter
    spdif_tx : work.spdif.spdif_tx
        port map (
            i_clk             => spdif_tx_clk,
            i_subframe        => spdif_tx_subframe,
            i_channel_left    => spdif_tx_channel_left,
            i_channel_right   => spdif_tx_channel_right,
            i_enable          => spdif_tx_enable,
            o_finish_subframe => spdif_tx_finish_subframe,
            o_spdif           => o_spdif
        );

    -- Create a 440hz sine wave to transmit
    create_440hz_sine_wave : process(spdif_tx_finish_subframe)
    begin
        if rising_edge(spdif_tx_finish_subframe) then

            if sine_wave_counter < samples_to_hold_value then
                spdif_tx_subframe <= Subframe_t_SQUARE_WAVE_LOW;
            else
                spdif_tx_subframe <= Subframe_t_SQUARE_WAVE_HIGH;
            end if;

            if sine_wave_counter < 2*samples_to_hold_value then
                sine_wave_counter <= sine_wave_counter + 1;
            else
                sine_wave_counter <= 0;
            end if;
        end if;
    end process;

end behavioral;
