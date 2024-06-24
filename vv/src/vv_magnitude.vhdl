library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_magnitude is
  generic (ITERATIONS : natural := 8;
           COMPENSATE : boolean := false);
  port (input     : in  symbol_type;
        magnitude : out magnitude_type);
end entity vv_magnitude;

architecture arch of vv_magnitude is

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

  function one_over_K(iterations : natural) return unsigned is
    variable K : real;
  begin
    K := 1.0;
    for i in 0 to ITERATIONS-1 loop
      K := K * sqrt(1.0 + tan(arctan(2.0**(real(-i))))**2.0);
    end loop;
    return to_unsigned(integer(round((1.0/K)*(2.0**(INPUT_WL-1)-1.0))), INPUT_WL+2);
  end function one_over_K;

  signal x_out : signed(INPUT_WL+1 downto 0);
  signal y_out : signed(INPUT_WL+1 downto 0);
  signal z_out : signed(2+ITERATIONS-1 downto 0);

  signal compensation : unsigned(INPUT_WL+1 downto 0) := one_over_K(ITERATIONS);

begin

  cordic_inst : cordic
    generic map (XY_WL      => INPUT_WL,
                 Z_WL       => 2+ITERATIONS,
                 ITERATIONS => ITERATIONS)
    port map(x_in  => input.re,
             y_in  => input.im,
             z_in  => to_signed(0, 2+ITERATIONS),
             x_out => x_out,
             y_out => y_out,
             z_out => z_out);

  no_compensation_gen : if COMPENSATE = false generate
    magnitude_largest_gen : if MAGNITUDE_WL > INPUT_WL generate
      magnitude <= shift_left(resize(unsigned(abs(x_out)), MAGNITUDE_WL), MAGNITUDE_WL-INPUT_WL);
    end generate magnitude_largest_gen;

    equal_gen : if MAGNITUDE_WL = INPUT_WL generate
      magnitude <= resize(unsigned(abs(x_out)), MAGNITUDE_WL);
    end generate equal_gen;

    input_largest_gen : if INPUT_WL > MAGNITUDE_WL generate
      magnitude <= resize(shift_right(unsigned(abs(x_out)) + to_unsigned(2**(INPUT_WL-MAGNITUDE_WL-1), 2*INPUT_WL), INPUT_WL-MAGNITUDE_WL), MAGNITUDE_WL);

--      magnitude <= resize(shift_right(unsigned(std_logic_vector(abs(x_out))) + to_unsigned(2**(INPUT_WL-magnitude'length), x_out'length), INPUT_WL+1-magnitude'length), magnitude'length);
--    magnitude <= resize(shift_right(unsigned(std_logic_vector(abs(x_out))) + to_unsigned(2**(INPUT_WL-1-magnitude'length), x_out'length), INPUT_WL-magnitude'length), magnitude'length);
    end generate input_largest_gen;
  end generate no_compensation_gen;


  Compensation_gen : if COMPENSATE = true generate
    magnitude <= resize(shift_right(one_over_K(ITERATIONS)*unsigned(std_logic_vector(abs(x_out))) + to_unsigned(2**(INPUT_WL-2), x_out'length), INPUT_WL-1), magnitude'length);
  end generate compensation_gen;

end architecture arch;
