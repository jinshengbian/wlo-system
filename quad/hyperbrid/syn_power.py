import subprocess

lang = 0 # 0 for verilog, 1 for VHDL
clk_en = 1
LIB_FILE = "./library/sky130hd_tt.lib" 
TOP_MODULE = "quad"

if lang == 1:
    subprocess.run([f"ghdl -a ./synthesis/{TOP_MODULE}_syn.vhdl"],shell=True)

# generate yosys script
with open("./synthesis/synth.ys", "w") as file:
    file.write("# read design\n")
    if lang == 0:
        file.write(f"read -sv ./synthesis/{TOP_MODULE}_syn.sv\n")
    else:
        file.write(f"ghdl {TOP_MODULE}\n")
    file.write(f"hierarchy -top {TOP_MODULE}\n")
    file.write("# the high-level stuff\n")
    file.write("proc; fsm; opt; memory; opt\n")
    file.write("# mapping to internal cell library\n")
    file.write("techmap; opt\n")
    file.write("# mapping flip-flops to mycells.lib\n")
    file.write(f"dfflibmap -liberty {LIB_FILE}\n")
    file.write(f"abc -liberty {LIB_FILE}\n")
    file.write("# write netlist\n")
    file.write(f"write_verilog -noattr ./synthesis/{TOP_MODULE}_syn.v\n")
    file.write("# cleanup\n")
    file.write("clean\n")

# perform synthesis
if lang == 0:
    subprocess.run(["yosys ./synthesis/synth.ys"],shell=True)
else:
    subprocess.run(["yosys -m ghdl ./synthesis/synth.ys"],shell=True)

# generate sdc file
if clk_en == 1:
    with open(f"./synthesis/{TOP_MODULE}_syn.sdc", "w") as file:
        file.write("set_units -time ns\n")
        file.write("create_clock [get_ports clk] -name core_clock -period 10\n")

# generate openSTA script
with open("./synthesis/sta.tcl", "w") as file:
    file.write(f"read_liberty {LIB_FILE}\n")
    file.write(f"read_verilog ./synthesis/{TOP_MODULE}_syn.v\n")
    file.write(f"link_design {TOP_MODULE}\n")
    if clk_en == 1:
        file.write(f"read_sdc ./synthesis/{TOP_MODULE}_syn.sdc\n")
        file.write(f"set_power_activity -input_port rstn -activity 0.2\n")
    file.write("set_power_activity -input -activity 0.9\n")
    file.write("report_power > ./synthesis/power.rpt\n")

# perform power analysis
subprocess.run(["sta -exit ./synthesis/sta.tcl"],shell=True)
subprocess.run(["cat ./synthesis/power.rpt"],shell=True)

# cleanup
subprocess.run(["rm -f ./synthesis/synth.ys"],shell=True)
subprocess.run(["rm -f ./synthesis/sta.tcl"],shell=True)