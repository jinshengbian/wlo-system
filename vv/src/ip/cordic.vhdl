-- Assumed z is signed with of the format SII.R...
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity cordic is
  generic (XY_WL      : natural := 8;
           Z_WL       : natural := 8;
           ITERATIONS : natural := 8);
  port (x_in  : in  signed(XY_WL-1 downto 0);
        y_in  : in  signed(XY_WL-1 downto 0);
        z_in  : in  signed(Z_WL-1 downto 0);
        x_out : out signed(XY_WL+1 downto 0);
        y_out : out signed(XY_WL+1 downto 0);
        z_out : out signed(Z_WL-1 downto 0));
end entity cordic;

architecture arch of cordic is

  type cordic_type is record
    x : signed(XY_WL+1 downto 0);
    y : signed(XY_WL+1 downto 0);
    z : signed(Z_WL-1 downto 0);
  end record;

  type e_type is array (0 to ITERATIONS-1) of signed(Z_WL-1 downto 0);

  function generate_e return e_type is
    variable output : e_type;
  begin
    for i in output'range loop
      output(i) := to_signed(integer(round(arctan(2.0**real(-i))*(2.0**(Z_WL-3)-1.0))), output(i)'length);
    end loop;
    return output;
  end function generate_e;

  constant e : e_type := generate_e;

  function cordic_block(input : cordic_type; i : integer) return cordic_type is
    variable d        : std_logic;
    variable output   : cordic_type;
    variable rounding : signed(XY_WL+1 downto 0);
  begin
    D := input.x(input.x'left) xor input.y(input.y'left);
    if i = 0 then
      rounding := (others => '0');
    else
      rounding := to_signed(2**(i-1), rounding'length);
    end if;
    if d = '1' then
      output.x := input.x - shift_right(input.y + rounding, i);
      output.y := input.y + shift_right(input.x + rounding, i);
      output.z := input.z - e(i);
    else
      output.x := input.x + shift_right(input.y + rounding, i);
      output.y := input.y - shift_right(input.x + rounding, i);
      output.z := input.z + e(i);
    end if;
    return output;
  end function cordic_block;

  signal e_sig : e_type := generate_e;


begin

  process(x_in, y_in, z_in)
    variable c : cordic_type;
  begin
    c.x := resize(x_in, c.x'length);
    c.y := resize(y_in, c.y'length);
    c.z := z_in;
    for i in 0 to ITERATIONS-1 loop
      C := cordic_block(c, i);
    end loop;
    x_out <= c.x;
    y_out <= c.y;
    z_out <= c.z;
  end process;

end architecture arch;
