library ieee;
use ieee.std_logic_1164.all;

use work.vv_support.all;

entity vv_wrapper is
  port (clk   : in  std_logic;
        rst   : in  std_logic;
        i_in  : in  std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
        q_in  : in  std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
        i_out : out std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
        q_out : out std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0));
        
end entity vv_wrapper;


architecture arch of vv_wrapper is

  -- Component declarations
  component vv is
    port(clk   : in  std_logic;
         rst   : in  std_logic;
         i_in  : in  std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
         q_in  : in  std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
         i_out : out std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
         q_out : out std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0));
        
  end component vv;

  -- Signal declarations
  signal i_in_vv  : std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
  signal q_in_vv  : std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
  signal i_out_vv : std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
  signal q_out_vv : std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
  -- signal vv_magnitude_wl,vv_partitioned_wl,vv_4thPower_wl,vv_phase_wl,vv_avgSum_wl : std_logic_vector(7 downto 0);


begin

  -- I/O registers
  io_registers_proc : process (rst, clk)
  begin
    if rst = '1' then
      i_in_vv <= (others => '0');
      q_in_vv <= (others => '0');
      i_out   <= (others => '0');
      q_out   <= (others => '0');
    elsif rising_edge(clk) then
      i_in_vv <= i_in;
      q_in_vv <= q_in;
      i_out   <= i_out_vv;
      q_out   <= q_out_vv;
    end if;
  end process io_registers_proc;

  -- Component instantiations
  vv_inst : vv
    port map (clk   => clk,
              rst   => rst,
              i_in  => i_in_vv,
              q_in  => q_in_vv,
              i_out => i_out_vv,
              q_out => q_out_vv);

end architecture arch;



