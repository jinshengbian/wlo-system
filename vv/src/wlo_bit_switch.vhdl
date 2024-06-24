library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bit_switch is
    generic (
        MAX_LEN : integer := 32  -- maximum wordlength
    );
    port (
        num_bit : in  std_logic_vector(7 downto 0);  -- number of fractional bits
        -- data path
        data_i  : in  std_logic_vector(MAX_LEN-1 downto 0);
        data_o  : out std_logic_vector(MAX_LEN-1 downto 0)
    );
end entity bit_switch;

architecture behavior of bit_switch is
    signal data_temp : std_logic_vector(MAX_LEN-1 downto 0);
    signal mask      : std_logic_vector(MAX_LEN-1 downto 0);
begin
    process(all) is
    begin
        -- generate mask
        for i in 0 to MAX_LEN-1 loop
            mask(i) <= '0' when i <= MAX_LEN-1 - to_integer(unsigned(num_bit)) else '1';
        end loop;

        -- apply mask
        if to_integer(unsigned(num_bit)) < MAX_LEN then
            data_temp <= data_i and mask;
        else
            data_temp <= data_i;
        end if;

        -- assign output
        data_o <= data_temp;
    end process;
end architecture behavior;