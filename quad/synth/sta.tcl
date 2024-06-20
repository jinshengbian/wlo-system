read_liberty ../library/sky130hd_tt.lib
read_verilog ./synth/quad_syn.v
link_design quad
read_sdc ./synth/quad_syn.sdc
set_power_activity -input_port rstn -activity 0.2
set_power_activity -input -activity 0.9
report_power > ./synth/power.rpt
