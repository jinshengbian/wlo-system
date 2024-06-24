library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_sum_average is
  port (clk         : in  std_logic;
        rst         : in  std_logic;
        en          : in  std_logic;
        average     : in  average_type;
        average_sum : out average_type);
end entity vv_sum_average;

architecture arch of vv_sum_average is

  type sum_type is record
    re : signed(AVERAGE_WL+AVERAGE_LENGTH-2 downto 0);
    im : signed(AVERAGE_WL+AVERAGE_LENGTH-2 downto 0);
  end record sum_type;

  signal sum : sum_type;

begin

  process (rst, clk)
  begin
    if rst = '1' then
      sum <= (others => (others => '0'));
      average_sum <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if en = '1' then
        average_sum.re <= resize(shift_right(sum.re + to_signed(2**(integer(ceil(log2(real(AVERAGE_LENGTH)))) - 1), sum.re'length), integer(ceil(log2(real(AVERAGE_LENGTH))))), average_sum.re'length);
        average_sum.im <= resize(shift_right(sum.im + to_signed(2**(integer(ceil(log2(real(AVERAGE_LENGTH)))) - 1), sum.im'length), integer(ceil(log2(real(AVERAGE_LENGTH))))), average_sum.im'length);
        sum.re <= resize(average.re, sum.re'length);
        sum.im <= resize(average.im, sum.im'length);
      else
        sum.re <= sum.re + resize(average.re, sum.re'length);
        sum.im <= sum.im + resize(average.im, sum.im'length);
      end if;
    end if;
  end process;


end architecture arch;

