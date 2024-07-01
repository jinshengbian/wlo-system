library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.vv_support.all;

entity vv_fourth_power is
  port (input  : in par_partitioned_type;
        fourth_power  : out par_fourth_type);
end entity vv_fourth_power;

architecture power_of_four_arch of vv_fourth_power is


  signal squared : par_square_type;
  signal fourth  : par_fourth_type;

  function square(a : partitioned_type) return square_type is
    variable re : signed(2*PARTITIONED_WL downto 0);  -- 2*PARTITIONED_WL-2 fractional bits
    variable im : signed(2*PARTITIONED_WL downto 0);  -- 2*PARTITIONED_WL-2 fractional bits
    variable z  : square_type;
  begin
    re := resize(a.re*a.re, re'length) - resize(a.im*a.im, re'length);
    im := shift_left(resize(a.re*a.im, im'length), 1);
    -- Resize with rounding
    if (2*PARTITIONED_WL-2) - (SQUARE_WL-2) > 0 then
      z.re := resize(shift_right(shift_right(re, (2*PARTITIONED_WL-2) - (SQUARE_WL-2) - 1) + 1, 1), z.re'length);
      z.im := resize(shift_right(shift_right(im, (2*PARTITIONED_WL-2) - (SQUARE_WL-2) - 1) + 1, 1), z.im'length);
    elsif (2*PARTITIONED_WL-2) - (SQUARE_WL-2) < 0 then
      z.re := shift_left(resize(re, z.re'length), (SQUARE_WL-2) - (2*PARTITIONED_WL-2) -1);
      z.im := shift_left(resize(im, z.im'length), (SQUARE_WL-2) - (2*PARTITIONED_WL-2) -1);
    else -- (2*PARTITIONED_WL-2) - (SQUARE_WL-3) = 0
      z.re := resize(re, z.re'length);
      z.im := resize(im, z.im'length);
    end if;
    return z;
  end function square;

  function square(a : square_type) return fourth_type is
    variable re : signed(2*SQUARE_WL downto 0);  -- 2*SQUARE_WL-6 fractional bits
    variable im : signed(2*SQUARE_WL downto 0);  -- 2*SQUARE_WL-6 fractional bits
    variable z  : fourth_type;
  begin
    re := resize(a.re*a.re, re'length) - resize(a.im*a.im, re'length);
    im := shift_left(resize(a.re*a.im, im'length), 1);
    -- Resize with rounding
    if (2*SQUARE_WL-4) - (FOURTH_WL-3) > 0 then
      z.re := resize(shift_right(shift_right(re, (2*SQUARE_WL-4) - (FOURTH_WL-3) - 1) + 1, 1), z.re'length);
      z.im := resize(shift_right(shift_right(im, (2*SQUARE_WL-4) - (FOURTH_WL-3) - 1) + 1, 1), z.im'length);
    elsif (2*SQUARE_WL-4) - (FOURTH_WL-3) < 0 then
      z.re := shift_left(resize(re, z.re'length), (FOURTH_WL-3) - (2*SQUARE_WL-4));
      z.im := shift_left(resize(im, z.im'length), (FOURTH_WL-3) - (2*SQUARE_WL-4));
    else -- (2*SQUARE_WL-6) - (FOURTH_WL-4) = 0
      z.re := resize(re(2*SQUARE_WL-1 downto 0), z.re'length);
      z.im := resize(im(2*SQUARE_WL-1 downto 0), z.im'length);
    end if;
    return z;
  end function square;

begin

  par_gen : for par_idx in 0 to PARALLELISM-1 generate
    squared(par_idx) <= square(input(par_idx));
    fourth(par_idx)       <= square(squared(par_idx));
  end generate par_gen;
  fourth_power  <= fourth;

end architecture power_of_four_arch;
