# Check that CPR_BASE_PATH exists
if [ -z "$CPR_BASE_PATH" ]
then
    echo "ERROR: Please source setup script first."
    return
fi

# Save old path and current directory
OLD_PATH=$PATH;
CURR_DIR=${PWD}

# Set tool paths
# PATH=$PATH:/usr/local/cad/incisive-15.20.061/tools.lnx86/bin

# Enter run directory
cd $CPR_BASE_PATH/sim/run
rm -rf $CPR_BASE_PATH/sim/run/work
# vsim -c
vlib work
vmap work work


vcom $CPR_BASE_PATH/src/vv_support.vhdl
vcom $CPR_BASE_PATH/src/ip/cordic.vhdl
vcom $CPR_BASE_PATH/src/vv_magnitude.vhdl
vcom $CPR_BASE_PATH/src/vv_par_magnitude.vhdl
vcom $CPR_BASE_PATH/src/vv_partitioning.vhdl
vcom $CPR_BASE_PATH/src/vv_fourth_power.vhdl
vcom $CPR_BASE_PATH/src/vv_average.vhdl
vcom $CPR_BASE_PATH/src/vv_sum_average.vhdl
vcom $CPR_BASE_PATH/src/vv_phase.vhdl
vcom $CPR_BASE_PATH/src/vv_unwrapping.vhdl
vcom $CPR_BASE_PATH/src/vv_delay_buffer.vhdl
vcom $CPR_BASE_PATH/src/vv_compensation.vhdl
vcom $CPR_BASE_PATH/src/vv.vhdl
vcom $CPR_BASE_PATH/src/vv_wrapper.vhdl
vcom $CPR_BASE_PATH/src/vv_tb.vhdl
vsim -c vv_tb -voptargs=+acc -do "run -all; quit"


rm -rf $CPR_BASE_PATH/sim/run/work
# Restore path and unset license variables
cd $CURR_DIR
PATH=$OLD_PATH
unset CDS_LIC_FILE
unset OLD_PATH
unset CURR_DIR



