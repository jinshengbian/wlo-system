library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_partitioning is
  port (input     : in  par_symbol_type;
        magnitude : in  par_magnitude_type;
        output    : out par_symbol_type);
end entity vv_partitioning;

architecture arch of vv_partitioning is

  constant CORDIC_K : real := 1.646760258121;

  -- Number of different amplitudes in QAM
  function get_n_rings(modulation_format : natural) return natural is
  begin
    if qam = 16 then
      return 3;
    elsif qam = 64 then
      return 9;
    elsif qam = 256 then
      return 34;
    else
      report "Unsupported modulation format" severity failure;
      return 0;
    end if;
  end function get_n_rings;
  constant N_RINGS : natural := get_n_rings(QAM);

  -- Amplitude limits scaled by INPUT_SCALING 
  type magnitude_limits_type is array (0 to N_RINGS-2) of magnitude_type;
  function get_magnitude_limits(modulation_format : natural) return magnitude_limits_type is
    type limits_real_type is array (0 to N_RINGS-2) of real;
    variable limits_real : limits_real_type;
    variable limits_us   : magnitude_limits_type;
  begin
    if modulation_format = 16 then
      limits_real := (0.723606797749979,
                      1.17082039324994);
    elsif modulation_format = 64 then
      limits_real := (0.353083963355129,
                      0.571301853591122,
                      0.72072473158871,
                      0.84326560165594,
                      0.9954124310112,
                      1.13311437698298,
                      1.25125345447712,
                      1.42744641891009);
    elsif modulation_format = 256 then
      limits_real := (0.175500426972831,
                      0.283965655882159,
                      0.358236315582753,
                      0.41914526996874,
                      0.494769870023299,
                      0.542326144546641,
                      0.563214639033471,
                      0.621935681885091,
                      0.67714228319895,
                      0.71106160562851,
                      0.743431738737148,
                      0.774447693995586,
                      0.818389652281048,
                      0.860807575565714,
                      0.900600977116614,
                      0.951457191110988,
                      0.988093530091976,
                      1.0116294615074,
                      1.04575876949102,
                      1.07916033786119,
                      1.11123614756384,
                      1.14270571714517,
                      1.16311601611518,
                      1.18317417565759,
                      1.20289782159214,
                      1.21267812518166,
                      1.24111554015643,
                      1.28782363377661,
                      1.32386754946095,
                      1.37584438116057,
                      1.41834266102368,
                      1.47450969033927,
                      1.57468023404618);
    else
      report "Unsupported modulation format" severity failure;
    end if;
    for limits_idx in 0 to N_RINGS-2 loop
      -- Compensation for CORDIC
      limits_real(limits_idx) := limits_real(limits_idx) * INPUT_SCALING * CORDIC_K;
      limits_us(limits_idx)   := to_unsigned(integer(round(limits_real(limits_idx)*(2.0**(MAGNITUDE_WL-1)-1.0))), limits_us(limits_idx)'length);
    end loop;
    return limits_us;
  end function get_magnitude_limits;
  constant MAGNITUDE_LIMITS : magnitude_limits_type := get_magnitude_limits(QAM);

  signal limits_sig : magnitude_limits_type := get_magnitude_limits(QAM);

begin

  process (input, magnitude)
  begin
    for par_idx in 0 to PARALLELISM-1 loop
      -- Default value, if not matched.
      output(par_idx) <= (others => (others => '0'));
      for sel_ring_idx in 0 to N_SEL_RINGS-1 loop
        if SEL_RINGS(sel_ring_idx) = 0 then
          if magnitude(par_idx) < MAGNITUDE_LIMITS(0) then
            output(par_idx) <= input(par_idx);
          end if;
        elsif SEL_RINGS(sel_ring_idx) = N_RINGS-1 then
          if magnitude(par_idx) > MAGNITUDE_LIMITS(N_RINGS-2) then
            output(par_idx) <= input(par_idx);
          end if;
        else
          if magnitude(par_idx) > MAGNITUDE_LIMITS(SEL_RINGS(sel_ring_idx)-1) and
            magnitude(par_idx) < MAGNITUDE_LIMITS(SEL_RINGS(sel_ring_idx)) then
            output(par_idx) <= input(par_idx);
          end if;
        end if;
      end loop;
    end loop;
  end process;



end architecture arch;
