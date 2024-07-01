library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package vv_support is
  -- Testbench settings
  constant PERIOD : time := 10 ns;

  -- Design settings
  constant PARALLELISM   : natural := 2;
  constant QAM           : natural := 16;
  constant INPUT_WL      : natural := 8;
  constant INPUT_SCALING : real    := 1.0/2.6832;

  constant N_SEL_RINGS : natural             := 2;
  type selected_rings_type is array (0 to N_SEL_RINGS-1) of natural;
  constant SEL_RINGS   : selected_rings_type := (0, 2);

  constant MAGNITUDE_WL         : natural := 16; --for optimization
  constant MAGNITUDE_ITERATIONS : natural := INPUT_WL-6;

  constant PARTITIONED_WL   : natural := 8; --for optimization

  constant SQUARE_WL : natural := 7; --for optimization
  constant FOURTH_WL : natural := 8; --for optimization

  constant AVERAGE_WL     : natural := FOURTH_WL+PARALLELISM-2; --fixed
  constant AVERAGE_LENGTH : natural := 64;  -- In multiples of the parallelism.

  constant PHASE_WL         : natural := 9; --for optimization
  constant PHASE_ITERATIONS : natural := INPUT_WL;

  -- Constants
  constant RINGS_16QAM  : natural := 3;
  constant RINGS_64QAM  : natural := 9;
  constant RINGS_256QAM : natural := 34;

  constant ESTIMATION_DLY : natural;

  -- Type declarations
  type symbol_type is record
    re : signed(INPUT_WL-1 downto 0);
    im : signed(INPUT_WL-1 downto 0);
  end record symbol_type;
  type par_symbol_type is array (0 to PARALLELISM-1) of symbol_type;

  subtype magnitude_type is unsigned(MAGNITUDE_WL-1 downto 0);
  type par_magnitude_type is array (0 to PARALLELISM-1) of magnitude_type;

  type partitioned_type is record
    re : signed(PARTITIONED_WL-1 downto 0);
    im : signed(PARTITIONED_WL-1 downto 0);
  end record partitioned_type;
  type par_partitioned_type is array (0 to PARALLELISM-1) of partitioned_type;

  type square_type is record  -- 3 integer bits, SQUARE_WL-3 fractional bits
    re : signed(SQUARE_WL-1 downto 0);
    im : signed(SQUARE_WL-1 downto 0);
  end record square_type;
  type par_square_type is array (0 to PARALLELISM-1) of square_type;

  type fourth_type is record  -- 4 integer bits, FOURTH_WL-4 fractional bits
    re : signed(FOURTH_WL-1 downto 0);
    im : signed(FOURTH_WL-1 downto 0);
  end record fourth_type;
  type par_fourth_type is array (0 to PARALLELISM-1) of fourth_type;

  type average_type is record
    re : signed(AVERAGE_WL-1 downto 0);
    im : signed(AVERAGE_WL-1 downto 0);
  end record average_type;

-----------------------------for reference-------------------------------------------
--  type symbol_squared_type is record
--    re : signed(INPUT_WL+2-1 downto 0);
--    im : signed(INPUT_WL+2-1 downto 0);
--  end record symbol_squared_type;
--  type par_symbol_squared_type is array (0 to PARALLELISM-1) of symbol_squared_type;


--  type fourth_power_type is record
--    re : signed(INPUT_WL+3-1 downto 0);
--    im : signed(INPUT_WL+3-1 downto 0);
--  end record fourth_power_type;
--  type par_fourth_power_type is array (0 to PARALLELISM-1) of fourth_power_type;
-------------------------------------------------------------------------------------



  subtype phase_type is unsigned(PHASE_WL-1 downto 0);

  subtype quadrant_type is unsigned(1 downto 0);

end package vv_support;

package body vv_support is

  function calc_estimation_delay return natural is
  begin
    if AVERAGE_LENGTH = 1 then
      return 3+1;
    elsif AVERAGE_LENGTH = 2 then
      return 5+1+1;
    else
      return 4+1+AVERAGE_LENGTH; --1+1+AVERAGE_LENGTH
    end if;
  end function calc_estimation_delay;
  constant ESTIMATION_DLY : natural := calc_estimation_delay;

end package body vv_support;
