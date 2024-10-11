-- CRC polynomial coefficients: x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1
--                              0xEDB88320 (hex)
-- CRC width:                   32 bits
-- CRC shift direction:         right (little endian)
-- Input word width:            2 bits

library ieee;
    use ieee.std_logic_1164.all;

library work;
    use work.ethernet.all;

entity fcs_calculator is
    port (
        i_crc   : in  EthernetFCS_t;
        i_dibit : in  std_logic_vector(1 downto 0);
        o_crc   : out EthernetFCS_t;
        -- Post-complement of o_crc, required by FCS
        o_fcs   : out EthernetFCS_t;
    );
end entity fcs_calculator;

architecture dataflow of fcs_calculator is

    -- Intermediate signals
    signal crc : EthernetFCS_t := (others => '0');
    
begin

    -- CRC32 calculation
    crc(0)  <= i_crc(30) xor i_dibit(0);
    crc(1)  <= i_crc(30) xor i_crc(31) xor i_dibit(0) xor i_dibit(1);
    crc(2)  <= i_crc(0) xor i_crc(30) xor i_crc(31) xor i_dibit(0) xor i_dibit(1);
    crc(3)  <= i_crc(1) xor i_crc(31) xor i_dibit(1);
    crc(4)  <= i_crc(2) xor i_crc(30) xor i_dibit(0);
    crc(5)  <= i_crc(3) xor i_crc(30) xor i_crc(31) xor i_dibit(0) xor i_dibit(1);
    crc(6)  <= i_crc(4) xor i_crc(31) xor i_dibit(1);
    crc(7)  <= i_crc(5) xor i_crc(30) xor i_dibit(0);
    crc(8)  <= i_crc(6) xor i_crc(30) xor i_crc(31) xor i_dibit(0) xor i_dibit(1);
    crc(9)  <= i_crc(7) xor i_crc(31) xor i_dibit(1);
    crc(10) <= i_crc(8) xor i_crc(30) xor i_dibit(0);
    crc(11) <= i_crc(9) xor i_crc(30) xor i_crc(31) xor i_dibit(0) xor i_dibit(1);
    crc(12) <= i_crc(10) xor i_crc(30) xor i_crc(31) xor i_dibit(0) xor i_dibit(1);
    crc(13) <= i_crc(11) xor i_crc(31) xor i_dibit(1);
    crc(14) <= i_crc(12);
    crc(15) <= i_crc(13);
    crc(16) <= i_crc(14) xor i_crc(30) xor i_dibit(0);
    crc(17) <= i_crc(15) xor i_crc(31) xor i_dibit(1);
    crc(18) <= i_crc(16);
    crc(19) <= i_crc(17);
    crc(20) <= i_crc(18);
    crc(21) <= i_crc(19);
    crc(22) <= i_crc(20) xor i_crc(30) xor i_dibit(0);
    crc(23) <= i_crc(21) xor i_crc(30) xor i_crc(31) xor i_dibit(0) xor i_dibit(1);
    crc(24) <= i_crc(22) xor i_crc(31) xor i_dibit(1);
    crc(25) <= i_crc(23);
    crc(26) <= i_crc(24) xor i_crc(30) xor i_dibit(0);
    crc(27) <= i_crc(25) xor i_crc(31) xor i_dibit(1);
    crc(28) <= i_crc(26);
    crc(29) <= i_crc(27);
    crc(30) <= i_crc(28);
    crc(31) <= i_crc(29);
    o_crc <= crc;

    -- Post-complement to generate final frame check sequence (FCS)
    o_fcs <= not crc;

end architecture dataflow;
