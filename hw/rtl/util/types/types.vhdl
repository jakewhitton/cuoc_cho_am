package types is

    -- Unit conversions
    constant BITS_PER_DIBIT  : natural := 2;
    constant DIBITS_PER_BYTE : natural := 4;
    constant BITS_PER_BYTE   : natural := DIBITS_PER_BYTE * BITS_PER_DIBIT;

end package types;
