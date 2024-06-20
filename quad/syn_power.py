import subprocess
import os

clk_en = 1
LIB_FILE = "../library/sky130hd_tt.lib" 
TOP_MODULE = "quad"



# generate yosys script
if os.path.exists("./synth/synth.ys") == False:
    with open("./synth/synth.ys", "w") as file:
        file.write("# read design\n")

        file.write(f"read -sv ./synth/{TOP_MODULE}_syn.sv\n")

        file.write(f"hierarchy -top {TOP_MODULE}\n")
        file.write("# the high-level stuff\n")
        file.write("proc; fsm; opt; memory; opt\n")
        file.write("# mapping to internal cell library\n")
        file.write("techmap; opt\n")
        file.write("# mapping flip-flops to mycells.lib\n")
        file.write(f"dfflibmap -liberty {LIB_FILE}\n")
        file.write(f"abc -liberty {LIB_FILE}\n")
        file.write("# write netlist\n")
        file.write(f"write_verilog -noattr ./synth/{TOP_MODULE}_syn.v\n")
        file.write("# cleanup\n")
        file.write("clean\n")

# perform synth

subprocess.run(["yosys ./synth/synth.ys"],shell=True)

# generate sdc file
if clk_en == 1:
    with open(f"./synth/{TOP_MODULE}_syn.sdc", "w") as file:
        file.write("set_units -time ns\n")
        file.write("create_clock [get_ports clk] -name core_clock -period 10\n")

# generate openSTA script
if os.path.exists("./synth/sta.tcl") == False:
    with open("./synth/sta.tcl", "w") as file:
        file.write(f"read_liberty {LIB_FILE}\n")
        file.write(f"read_verilog ./synth/{TOP_MODULE}_syn.v\n")
        file.write(f"link_design {TOP_MODULE}\n")
        if clk_en == 1:
            file.write(f"read_sdc ./synth/{TOP_MODULE}_syn.sdc\n")
            file.write(f"set_power_activity -input_port rstn -activity 0.2\n")
        file.write("set_power_activity -input -activity 0.9\n")
        file.write("report_power > ./synth/power.rpt\n")

# perform power analysis
subprocess.run(["sta -exit ./synth/sta.tcl"],shell=True)
subprocess.run(["cat ./synth/power.rpt"],shell=True)

# cleanup
# subprocess.run(["rm -f ./synth/synth.ys"],shell=True)
# subprocess.run(["rm -f ./synth/sta.tcl"],shell=True)