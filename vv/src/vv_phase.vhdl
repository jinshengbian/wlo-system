library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_phase is
  generic (ITERATIONS : natural := 8);
  port (average : in  average_type;
        phase   : out phase_type);
end entity vv_phase;

architecture arch of vv_phase is

  constant PI  : signed(2+ITERATIONS-1 downto 0) := to_signed(integer(round(MATH_PI * (2.0**(ITERATIONS-1)-1.0))), 2+ITERATIONS);
  constant PI_OVER_FOUR : signed(2+ITERATIONS-1 downto 0) := to_signed(integer(round(MATH_PI/4.0 * (2.0**(ITERATIONS-1)-1.0))), 2+ITERATIONS);

  component cordic is
    generic (XY_WL      : natural;
             Z_WL       : natural;
             ITERATIONS : natural);
    port (x_in  : in  signed;
          y_in  : in  signed;
          z_in  : in  signed;
          x_out : out signed;
          y_out : out signed;
          z_out : out signed);
  end component cordic;

  function adjust_phase(average : average_type; input : signed(2+ITERATIONS-1 downto 0)) return unsigned is
    variable result   : signed(2+ITERATIONS-1 downto 0);
  begin
    If average.re(average.re'left) = '0' and average.im(average.im'left) = '0' then
      result   := input;
    elsif average.re(average.re'left) = '1' and average.im(average.im'left) = '0' then
      result   := PI + input;
    elsif average.re(average.re'left) = '1' and average.im(average.im'left) = '1' then
      result   := input - PI;
    else
      result   := input;
    end if;
    result := abs(shift_right(result + to_signed(2, result'length), 2) - PI_OVER_FOUR);
    if PHASE_WL > result'length-3 then
      return unsigned(std_logic_vector(result(result'left-2 downto 0))) & (PHASE_WL-result'length+1 downto 0 => '0');
    else
      return resize(unsigned(std_logic_vector(shift_right(result + to_signed(2**(result'length-PHASE_WL-3), Result'length), result'length-PHASE_WL-2))), PHASE_WL);
    end if;   
  end function adjust_phase;



  signal x_out : signed(AVERAGE_WL+1 downto 0);
  signal y_out : signed(AVERAGE_WL+1 downto 0);
  signal z_out : signed(2+ITERATIONS-1 downto 0);

  signal z_out_comp : signed(2+ITERATIONS-1 downto 0);

begin

  cordic_inst : cordic
    generic map (XY_WL      => AVERAGE_WL,
                 Z_WL       => 2+ITERATIONS,
                 ITERATIONS => ITERATIONS)
    port map(x_in  => average.re,
             y_in  => average.im,
             z_in  => to_signed(0, 2+ITERATIONS),
             x_out => x_out,
             y_out => y_out,
             z_out => z_out);

  phase <= adjust_phase(average, z_out);


end architecture arch;
