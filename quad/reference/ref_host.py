import sys
sys.path.append('../../algo')
from host import *

import subprocess
import time
import numpy as np

import ConfigSpace as CS
import ConfigSpace.hyperparameters as CSH

import matplotlib.pyplot as plt
from tpe.optimizer import TPEOptimizer
import random
import json

class ref_host(host):
    def __init__(self, name, num_ite):
        super().__init__(name, num_ite)
        self.cur_cost = 0.0
        self.cur_prec = 0.0
        self.cur_loss = 0.0
        self.record = {
            'x1': [],
            'x2': [],
            'x3': [],
            'mse': [],
            'power': [],
            'loss': [],
            'time': []
        }


    ##### self defined functions #####

    # run simulation
    def run_sim(self,vals):
        try:
            tcl_commands = f"""

            vlib work
            vmap work work
            vlog ./design/*.sv
            vsim top_tb -voptargs=+acc
            force num_frac_a 8'd{vals[0]}
            force num_frac_b 8'd{vals[1]}
            force num_frac_c 8'd{vals[2]}
            run -all
            quit sim

            """
            
            # Start ModelSim and pass TCL commands via stdin
            p = subprocess.Popen(['vsim', '-c'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
            
            # Send TCL commands
            stdout, stderr = p.communicate(input=tcl_commands)

            # Print any errors
            if stderr:
                print(stderr)
                
        except Exception as e:
            print(f"Error adding waveform in ModelSim: {e}")




    # read reference sequence
    def read_ref_seq(self):
        wl_config = np.array([30,30,30])
        self.run_sim(wl_config)
        ref_seq = self.read_output()
        return ref_seq

    # read_output
    def read_output(self):
        seq = []
        with open('simulation/output.txt', 'r') as file:
            for line in file:
                for item in line.split():
                    try:
                        seq.append(float(item))
                    except ValueError:
                        pass
        seq = np.array(seq)
        return seq

    ##################################
    
    def get_cost(self,wl_config):
        # get configurations
        input_wl1 = wl_config[0]
        input_wl2 = wl_config[1]
        output_wl = wl_config[2]

        # modify the wordlength of the design
        with open("./synthesis/quad_syn.sv",'r') as dsp_design:
            content = dsp_design.readlines()
        with open("./synthesis/quad_syn.sv",'w') as dsp_design:
            content[5] = f"    input  logic [{input_wl1-1}:0] a,\n"
            content[6] = f"    input  logic [{input_wl2-1}:0] b,\n"
            content[7] = f"    output logic [{output_wl-1}:0] c\n"
            content[10] = f"logic [{2*input_wl1-1}:0] a_sq;\n"
            content[11] = f"logic [{2*input_wl2-1}:0] b_sq;\n"
            dsp_design.writelines(content)
            
        # run the synthesis script
        subprocess.run("python3 ./syn_power.py", shell=True, capture_output=True,text=True)
        # read power info
        rpt_file = "./synthesis/power.rpt"
        read_power_command = f"awk '/^Total/ {{print $5}}' {rpt_file}"
        res = subprocess.run(read_power_command, shell=True, capture_output=True, text=True)

        if res.returncode == 0:
            total_power = res.stdout.strip()
            print(f"Total Power: {total_power} Watts")
        else:
            print("Failed to extract the power value.")   
        total_power = float(total_power) 
        self.cur_cost = total_power
        # record power
        self.record['power'] = self.record['power'] + [self.cur_cost]


    def get_prec(self,wl_config,ref_seq):
        self.run_sim(wl_config)
        seq = self.read_output()
        self.cur_prec = np.mean((ref_seq-seq)**2)
        # record mse
        self.record['mse'] = self.record['mse'] + [self.cur_prec]

    def cal_loss(self):
        alpha = 10000
        power_max = 1e-4
        power_min = 5*1e-5
        power_diff = 0.0
        if self.cur_cost > power_max:
            power_diff = self.cur_cost - power_max
        elif self.cur_cost < power_min:
            power_diff = power_min - self.cur_cost
        else:
            power_diff = 0
        self.cur_loss = self.cur_prec + alpha*power_diff
        # record loss
        self.record['loss'] = self.record['loss'] + [self.cur_loss]


    def obj_func(self, eval_config: dict[str, float]) -> tuple[dict[str, float], float]:
        start_time = time.time() 
        # get reference sequence
        ref_seq = self.read_ref_seq()
        # Run simulation
        wl_config = np.array(list(eval_config.values()))
        self.run_sim(wl_config)
        # Calculate loss
        self.get_cost(wl_config)
        self.get_prec(wl_config,ref_seq)
        self.cal_loss()
        print(f"MSE: {self.cur_cost}")
        print(f"Loss: {self.cur_loss}")

        # record config
        self.record['x1'] = self.record['x1'] + [wl_config[0]]
        self.record['x2'] = self.record['x2'] + [wl_config[1]]
        self.record['x3'] = self.record['x3'] + [wl_config[2]]

        return {"loss": self.cur_loss}, time.time() - start_time



    def run(self):
        # Open files outside the loop
        with open("simulation/input1.txt", "w") as input_file1, open("simulation/input2.txt", "w") as input_file2:
            for _ in range(self.num_ite):
                random_data_1 = random.randint(0, 2**14)
                random_data_2 = random.randint(0, 2**14)
                # Write data to files using the file objects
                input_file1.write(str(random_data_1) + "\n")
                input_file2.write(str(random_data_2) + "\n")
        dim = 3
        cs = CS.ConfigurationSpace()
        for d in range(dim):
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x{d}", lower=1, upper=30))

        start_time = time.time()

        opt = TPEOptimizer(obj_func=self.obj_func, config_space=cs, min_bandwidth_factor=1e-2, resultfile="obj_func", max_evals=self.num_ite)
        print(opt.optimize(logger_name="obj_func"))

        sim_time = time.time() - start_time
        print("Overall time spent: ", sim_time, ", speed: ", sim_time/self.num_ite, " s/ite")
        self.record['time'] = self.record['time'] + [sim_time]

        self.dump_record()

if __name__ == "__main__":
    obj = ref_host("ref_host", 20)
    obj.run()
