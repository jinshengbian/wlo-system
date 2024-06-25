library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.vv_support.all;

entity vv_tb is
end entity vv_tb;

architecture arch of vv_tb is

  component vv_wrapper is
    port (clk   : in  std_logic;
          rst   : in  std_logic;
          i_in  : in  std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
          q_in  : in  std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
          i_out : out std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
          q_out : out std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
        
          --io for WL
          vv_magnitude_wl     : in std_logic_vector(7 downto 0);
          vv_partitioned_wl   : in std_logic_vector(7 downto 0);
          vv_4thPower_wl      : in std_logic_vector(7 downto 0);
          vv_phase_wl         : in std_logic_vector(7 downto 0);
          vv_avgSum_wl         : in std_logic_vector(7 downto 0));
  end component vv_wrapper;

  -- Signal declarations
  signal clk   : std_logic := '0';
  signal rst   : std_logic := '0';
  signal i_in  : std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
  signal q_in  : std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
  signal i_out : std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
  signal q_out : std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
  signal vv_magnitude_wl,vv_partitioned_wl,vv_4thPower_wl,vv_phase_wl,vv_avgSum_wl : std_logic_vector(7 downto 0);

  -- Status flags
  signal output_save : boolean := false;
  signal input_done  : boolean := false;

  -- Files
  type integer_file is file of integer;
  file i_in_file  : integer_file open read_mode is "i_in.vec";
  file q_in_file  : integer_file open read_mode is "q_in.vec";
  file i_out_file : integer_file open write_mode is "i_out.vec";
  file q_out_file : integer_file open write_mode is "q_out.vec";
begin

  vv_wrapper_inst : vv_wrapper
    port map (clk   => clk,
              rst   => rst,
              i_in  => i_in,
              q_in  => q_in,
              i_out => i_out,
              q_out => q_out,
              vv_magnitude_wl => vv_magnitude_wl,
              vv_partitioned_wl => vv_partitioned_wl,
              vv_4thPower_wl => vv_4thPower_wl,
              vv_phase_wl => vv_phase_wl,
              vv_avgSum_wl => vv_avgSum_wl);

  vv_magnitude_wl <= x"08";
  vv_partitioned_wl <= x"02";
  vv_4thPower_wl <= x"08";
  vv_phase_wl <= x"04";
  vv_avgSum_wl <= x"01";

  clk <= not clk after PERIOD/2;
  rst <= '1'     after PERIOD, '0' after 2*PERIOD;

  save_ctrl : process
  begin
    wait until rst = '1';
    wait until rst = '0';
    for i in 0 to ESTIMATION_DLY+3 loop
      wait until rising_edge(clk);
    end loop;
    output_save <= true;
    wait until input_done;
    for i in 0 to ESTIMATION_DLY+3 loop
      wait until rising_edge(clk);
    end loop;
    output_save <= false;
    wait;
  end process save_ctrl;

  input_proc : process
    variable i_in_int : integer;
    variable q_in_int : integer;
  begin
    wait until rst = '1';
    for i in 0 to PARALLELISM-1 loop
      read(i_in_file, i_in_int);
      read(q_in_file, q_in_int);
      i_in(INPUT_WL*(i+1)-1 downto INPUT_WL*i) <= std_logic_vector(to_signed(i_in_int, INPUT_WL));
      q_in(INPUT_WL*(i+1)-1 downto INPUT_WL*i) <= std_logic_vector(to_signed(q_in_int, INPUT_WL));
    end loop;
    wait until rst = '0';
    while (not(endfile(i_in_file)) and not(endfile(q_in_file))) loop
      wait until rising_edge(clk);
      wait for PERIOD/4*3;
      for i in 0 to PARALLELISM-1 loop
        read(i_in_file, i_in_int);
        read(q_in_file, q_in_int);
        i_in(INPUT_WL*(i+1)-1 downto INPUT_WL*i) <= std_logic_vector(to_signed(i_in_int, INPUT_WL));
        q_in(INPUT_WL*(i+1)-1 downto INPUT_WL*i) <= std_logic_vector(to_signed(q_in_int, INPUT_WL));
      end loop;
    end loop;
    input_done <= true;
    file_close(i_in_file);
    file_close(q_in_file);
    wait;
  end process;

  output_proc : process
  begin
    wait until output_save;
    while output_save loop
      wait until rising_edge(clk);
      for i in 0 to PARALLELISM-1 loop
        write(i_out_file, to_integer(signed(i_out(INPUT_WL*(i+1)-1 downto INPUT_WL*i))));
        write(q_out_file, to_integer(signed(q_out(INPUT_WL*(i+1)-1 downto INPUT_WL*i))));
      end loop;
    end loop;
    file_close(i_out_file);
    file_close(q_out_file);
    report("Testbench Done!") severity failure;
    wait;
  end process output_proc;

end architecture arch;


