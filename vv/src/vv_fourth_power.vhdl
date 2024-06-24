library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_fourth_power is
  port (input        : in  par_symbol_type;
        fourth_power : out par_fourth_power_type);
end entity vv_fourth_power;

architecture arch of vv_fourth_power is

  -- Type declarations


  -- Function Declarations
  function square(a : symbol_type) return symbol_squared_type is
    variable re     : signed(2*INPUT_WL downto 0);
    variable im     : signed(2*INPUT_WL downto 0);
    variable result : symbol_squared_type;
  begin
    re        := resize(a.re*a.re - a.im*a.im, re'length) + to_signed(2**(re'left-1-result.re'length), re'length);
    im        := shift_left(resize(a.re*a.im, im'length), 1) + to_signed(2**(im'left-1-result.im'length), im'length);
    result.re := re(re'left-1 downto re'left-1-result.re'length+1);
    result.im := im(im'left-1 downto im'left-1-result.im'length+1);
    return result;
  end function square;

  function square(a : symbol_squared_type) return fourth_power_type is
    variable re     : signed(2*(INPUT_WL+2) downto 0);
    variable im     : signed(2*(INPUT_WL+2) downto 0);
    variable result : fourth_power_type;
  begin
    re        := resize(a.re*a.re - a.im*a.im, re'length)  + to_signed(2**(re'left-2-result.re'length), re'length);
    im        := shift_left(resize(a.re*a.im, im'length), 1)  + to_signed(2**(im'left-2-result.im'length), im'length);
    result.re := re(re'left-2 downto re'left-2-result.re'length+1);
    result.im := im(im'left-2 downto im'left-2-result.im'length+1);
    return result;
  end function square;


  -- Signal declarations
  signal par_symbol_squared : par_symbol_squared_type;

begin

  par_gen : for par_idx in 0 to PARALLELISM-1 generate
    par_symbol_squared(par_idx) <= square(input(par_idx));
    fourth_power(par_idx)       <= square(par_symbol_squared(par_idx));
  end generate par_gen;


end architecture arch;
