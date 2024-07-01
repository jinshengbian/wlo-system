library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.vv_support.all;

entity vv is
  port(clk   : in  std_logic;
       rst   : in  std_logic;
       i_in  : in  std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
       q_in  : in  std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
       i_out : out std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0);
       q_out : out std_logic_vector(INPUT_WL*PARALLELISM-1 downto 0));
end entity vv;


architecture arch of vv is

  -- Component declarations
  component vv_par_magnitude is
    generic (ITERATIONS : natural;
             COMPENSATE : boolean);
    port (input     : in  par_symbol_type;
          magnitude : out par_magnitude_type);
  end component vv_par_magnitude;

  component vv_partitioning is
    port (input     : in  par_symbol_type;
          magnitude : in  par_magnitude_type;
          output    : out par_partitioned_type);
  end component vv_partitioning;

  component vv_fourth_power is
    port (input        : in  par_partitioned_type;
          fourth_power : out par_fourth_type);
  end component vv_fourth_power;

  component vv_average is
    port (fourth_power : in  par_fourth_type;
          average      : out average_type);
  end component vv_average;

  component vv_sum_average is
    port (clk         : in  std_logic;
          rst         : in  std_logic;
          en          : in  std_logic;
          average     : in  average_type;
          average_sum : out average_type);
  end component vv_sum_average;

  component vv_phase is
    generic (ITERATIONS : natural);
    port (average : in  average_type;
          phase   : out phase_type);
  end component vv_phase;

  component vv_unwrapping is
    port (clk       : in  std_logic;
          rst       : in  std_logic;
          en        : in  std_logic;
          phase_in  : in  phase_type;
          phase_out : out phase_type;
          quadrant  : out quadrant_type);
  end component vv_unwrapping;

  component vv_delay_buffer is
    generic (DELAY : natural);
    port (clk    : in  std_logic;
          rst    : in  std_logic;
          input  : in  par_symbol_type;
          output : out par_symbol_type);
  end component vv_delay_buffer;

  component vv_compensation is
    port (clk      : in  std_logic;
          rst      : in  std_logic;
          input    : in  par_symbol_type;
          phase    : in  phase_type;
          quadrant : in  quadrant_type;
          output   : out par_symbol_type);
  end component vv_compensation;

  -- Signal declarations
  signal input      : par_symbol_type;
  signal input_reg  : par_symbol_type;
  signal output     : par_symbol_type;
  signal output_reg : par_symbol_type;

  signal magnitude        : par_magnitude_type;
  signal magnitude_reg    : par_magnitude_type;
  signal partitioned      : par_partitioned_type;
  signal fourth_power     : par_fourth_type;
  signal fourth_power_reg : par_fourth_type;
  signal average          : average_type;
  signal average_sum      : average_type;
  signal input_delayed    : par_symbol_type;

  signal phase           : phase_type;
  signal phase_reg       : phase_type;
  signal phase_unwrapped : phase_type;
  signal quadrant        : quadrant_type;

  signal enable_cnt    : integer range 0 to AVERAGE_LENGTH-1;
  signal en_sum        : std_logic;
  signal en_phase_wait : std_logic;
  signal en_phase      : std_logic;
  signal en_unwrapping : std_logic;

begin

  -- Convert input
  convert_input_gen : for i in 0 to PARALLELISM-1 generate
    input(i).re <= signed(i_in(INPUT_WL*(i+1)-1 downto INPUT_WL*i));
    input(i).im <= signed(q_in(INPUT_WL*(i+1)-1 downto INPUT_WL*i));
  end generate convert_input_gen;

  -- Convert output
  convert_output_gen : for i in 0 to PARALLELISM-1 generate
    i_out(INPUT_WL*(i+1)-1 downto INPUT_WL*i) <= std_logic_vector(output(i).re);
    q_out(INPUT_WL*(i+1)-1 downto INPUT_WL*i) <= std_logic_vector(output(i).im);
  end generate convert_output_gen;

  -- Generate enable signals
  enable_proc : process (rst, clk)
  begin
    if rst = '1' then
      enable_cnt    <= 0;
      en_sum        <= '0';
      en_phase      <= '0';
      en_phase_wait <= '0';
      en_unwrapping <= '0';
    elsif rising_edge(clk) then
      if enable_cnt = AVERAGE_LENGTH-1 then
        enable_cnt <= 0;
        en_sum     <= '1';
      else
        enable_cnt <= enable_cnt + 1;
        en_sum     <= '0';
      end if;
      en_phase_wait <= en_sum;
      en_phase      <= en_phase_wait;
      en_unwrapping <= en_phase;
    end if;
  end process enable_proc;

  -- Pipeline registers
  pipeline_proc : process (rst, clk)
  begin
    if rst = '1' then
      input_reg        <= (others => (others => (others => '0')));
      magnitude_reg    <= (others => (others => '0'));
      fourth_power_reg <= (others => (others => (others => '0')));
      phase_reg        <= (others => '0');
    elsif rising_edge(clk) then
      input_reg        <= input;
      magnitude_reg    <= magnitude;
      fourth_power_reg <= fourth_power;
      if en_phase = '1' then
        phase_reg <= phase;
      end if;
    end if;

  end process pipeline_proc;


  -- Component instantiations
  vv_par_magnitude_inst : vv_par_magnitude
    generic map (ITERATIONS => MAGNITUDE_ITERATIONS,
                 COMPENSATE => false)
    port map (input     => input,
              magnitude => magnitude);

  vv_partitioning_inst : vv_partitioning
    port map(input     => input_reg,
             magnitude => magnitude_reg,
             output    => partitioned);

  vv_fourth_power_inst : vv_fourth_power
    port map(input        => partitioned,
             fourth_power => fourth_power);

  simple_averaging_gen : if AVERAGE_LENGTH = 1 generate
    vv_average_inst : vv_average
      port map (fourth_power => fourth_power_reg,
                average      => average);

    vv_phase_inst : vv_phase
      generic map (ITERATIONS => PHASE_ITERATIONS)
      port map (average => average,
                phase   => phase);
  end generate simple_averaging_gen;


  sum_averaging_gen : if AVERAGE_LENGTH > 1 generate
    vv_average_inst : vv_average
      port map (fourth_power => fourth_power_reg,
                average      => average);

    vv_sum_average_inst : vv_sum_average
      port map (clk         => clk,
                rst         => rst,
                en          => en_sum,
                average     => average,
                average_sum => average_sum);

    vv_phase_inst : vv_phase
      generic map (ITERATIONS => PHASE_ITERATIONS)
      port map (average => average_sum,
                phase   => phase);
  end generate sum_averaging_gen;

  vv_unwrapping_inst : vv_unwrapping
    port map (clk       => clk,
              rst       => rst,
              en        => en_unwrapping,
              phase_in  => phase_reg,
              phase_out => phase_unwrapped,
              quadrant  => quadrant);

  vv_delay_buffer_inst : vv_delay_buffer
    generic map (DELAY => ESTIMATION_DLY)
    port map (clk    => clk,
              rst    => rst,
              input  => input_reg,
              output => input_delayed);


  vv_compensation_inst : vv_compensation
    port map (clk      => clk,
              rst      => rst,
              input    => input_delayed,
              phase    => phase_unwrapped,
              quadrant => quadrant,
              output   => output);

end architecture arch;
