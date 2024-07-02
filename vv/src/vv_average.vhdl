library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.vv_support.all;

entity vv_average is
  port (fourth_power : in  par_fourth_type;
        average      : out average_type);
end entity vv_average;

architecture arch of vv_average is

  function block_average(input : par_fourth_type) return average_type is
    variable sum_re, sum_im : signed(12+PARALLELISM-2 downto 0);
    variable msb            : integer range AVERAGE_WL-1 to sum_re'left;
    variable result         : average_type;
  begin
    sum_re := (others => '0');
    sum_im := (others => '0');
    for par_idx in 0 to PARALLELISM-1 loop
      sum_re := sum_re + resize(input(par_idx).re, sum_re'length);
      sum_im := sum_im + resize(input(par_idx).im, sum_re'length);
    end loop;
    msb := AVERAGE_WL-1;
    for bit_idx in sum_re'left-1 downto AVERAGE_WL-1 loop
      if ((sum_re(bit_idx) /= sum_re(sum_re'left)) or
        (sum_im(bit_idx) /= sum_im(sum_im'left))) then
        msb := bit_idx+1;
        exit;
      end if;
    end loop;
    -- result.re := resize(shift_left(sum_re,sum_re'left-msb),result.re'length);
    -- result.im := resize(shift_left(sum_im,sum_im'left-msb),result.im'length);
    result.re := sum_re(msb downto msb - result.re'length+1);
    result.im := sum_im(msb downto msb - result.im'length+1);
    return result;
  end function block_average;

begin

  average <= block_average(fourth_power);
end architecture arch;
