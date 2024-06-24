library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_unwrapping is
  port (clk       : in  std_logic;
        rst       : in  std_logic;
        en        : in  std_logic;
        phase_in  : in  phase_type;
        phase_out : out phase_type;
        quadrant  : out quadrant_type);
end entity vv_unwrapping;

architecture arch of vv_unwrapping is

  -- Signal declarations
  signal phase_prev : phase_type;
  signal q          : quadrant_type;
begin

  process (rst, clk)
    variable diff : signed(PHASE_WL downto 0);
  begin
    if rst = '1' then
      phase_prev <= (others => '0');
      q          <= (others => '0');
    elsif rising_edge(clk) then
      if en = '1' then
        diff := signed(resize(phase_prev, diff'length) - resize(phase_in, diff'length));
        if abs(diff) > to_signed(integer(round(MATH_PI/4.0 * (2.0**(PHASE_WL-1)-1.0))), PHASE_WL+1) then
          if diff < 0 then
            q <= q - 1;
          else
            q <= q + 1;
          end if;
        else
          q <= q;
        end if;
        phase_prev <= phase_in;
      end if;
    end if;
  end process;
  phase_out <= phase_prev;
  quadrant  <= q;

end architecture arch;
