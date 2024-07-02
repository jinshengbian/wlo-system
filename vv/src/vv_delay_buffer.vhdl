library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_delay_buffer is
  generic (DELAY : natural);
  port (clk    : in  std_logic;
        rst    : in  std_logic;
        input  : in  par_symbol_type;
        output : out par_symbol_type);
end entity vv_delay_buffer;

architecture arch of vv_delay_buffer is

  -- Type declarations
  type buff_type is array (0 to DELAY-1) of par_symbol_type;

  -- Signal declarations
  signal pointer     : natural range 0 to DELAY-1;
  signal buff        : buff_type;
  signal mult_inputs : par_symbol_type;

begin

  simple_delay_gen : if DELAY = 1 generate
    delay_proc : process (rst, clk)
    begin
      if rst = '1' then
        output <= (others => (others => (others => '0')));
      elsif rising_edge(clk) then
        output <= input;
      end if;
    end process delay_proc;
  end generate;


  buffer_delay_gen : if DELAY > 1 generate
    buffer_proc : process (rst, clk)
      variable pointer_bps : integer;
    begin
      if rst = '1' then
        pointer <= 0;
        buff    <= (others => (others => (others => (others => '0'))));
        output  <= (others => (others => (others => '0')));
      elsif rising_edge(clk) then
        if pointer = DELAY-1 then
          pointer <= 0;
        else
          pointer <= pointer + 1;
        end if;
        buff(pointer) <= input;
        output        <= buff(pointer);
      end if;
    end process buffer_proc;
  end generate buffer_delay_gen;
end architecture arch;
