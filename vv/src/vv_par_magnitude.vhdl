library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_par_magnitude is
  generic (ITERATIONS : natural := 8;
           COMPENSATE : boolean := true);
  port (input     : in  par_symbol_type;
        magnitude : out par_magnitude_type);
end entity vv_par_magnitude;

architecture arch of vv_par_magnitude is

  component vv_magnitude is
    generic (ITERATIONS : natural;
             COMPENSATE : boolean);
    port (input     : in  symbol_type;
          magnitude : out magnitude_type);
  end component vv_magnitude;

begin

  par_gen : for par_idx in 0 to PARALLELISM-1 generate
    vv_magnitude_inst : vv_magnitude
      generic map (ITERATIONS => ITERATIONS,
                   COMPENSATE => COMPENSATE)
      port map(input     => input(par_idx),
               magnitude => magnitude(par_idx));
  end generate par_gen;
  
end architecture arch;
