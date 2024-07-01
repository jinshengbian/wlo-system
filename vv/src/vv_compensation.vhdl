library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_compensation is
  port (clk      : in  std_logic;
        rst      : in  std_logic;
        input    : in  par_symbol_type;
        phase    : in  phase_type;
        quadrant : in  quadrant_type;
        output   : out par_symbol_type);
end entity vv_compensation;

architecture arch of vv_compensation is

  -- Type declarations
  type rotations_type is array (0 to 2**(PHASE_WL)-1) of symbol_type;

  -- Signal declarations
  signal mult_rotation : symbol_type;

  -- Function Declarations
  function "*" (a, b : symbol_type) return symbol_type is
    variable re     : signed(2*INPUT_WL-1 downto 0);
    variable im     : signed(2*INPUT_WL-1 downto 0);
    variable result : symbol_type;
  begin
    re        := a.re*b.re - a.im*b.im + to_signed(2**(INPUT_WL-2), re'length);
    im        := a.re*b.im + a.im*b.re + to_signed(2**(INPUT_WL-2), im'length);
    result.re := re(2*INPUT_WL-2 downto INPUT_WL-1);
    result.im := im(2*INPUT_WL-2 downto INPUT_WL-1);
    return result;
  end function "*";

  function generate_rotations return rotations_type is
    variable result : rotations_type;
  begin
    for i in 0 to 2**(PHASE_WL)-1 loop
      result(i).re := to_signed(integer(round(cos(real(i) / (2.0**(PHASE_WL-1)-1.0)) * (2.0**(INPUT_WL-1)-1.0))), INPUT_WL);
      result(i).im := to_signed(integer(round(sin(real(i) / (2.0**(PHASE_WL-1)-1.0)) * (2.0**(INPUT_WL-1)-1.0))), INPUT_WL);
    end loop;
    return result;
  end function generate_rotations;

  -- Function declared constants
  constant ROTATIONS_LUT : rotations_type := generate_rotations;

begin

  register_proc : process (rst, clk)
  begin
    if rst = '1' then
      mult_rotation <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if quadrant = "00" then
        mult_rotation.re <= ROTATIONS_LUT(to_integer(phase)).re;
        mult_rotation.im <= ROTATIONS_LUT(to_integer(phase)).im;
      elsif quadrant = "01" then
        mult_rotation.re <= -ROTATIONS_LUT(to_integer(phase)).im;
        mult_rotation.im <= ROTATIONS_LUT(to_integer(phase)).re;
      elsif quadrant = "10" then
        mult_rotation.re <= -ROTATIONS_LUT(to_integer(phase)).re;
        mult_rotation.im <= -ROTATIONS_LUT(to_integer(phase)).im;
      else
        mult_rotation.re <= ROTATIONS_LUT(to_integer(phase)).im;
        mult_rotation.im <= -ROTATIONS_LUT(to_integer(phase)).re;
      end if;
    end if;
  end process;

  removed_gen : for par_idx in 0 to PARALLELISM-1 generate
    output(par_idx) <= input(par_idx)*mult_rotation;
  end generate;

end architecture arch;
