import sys
sys.path.append('../../algo')
from host import *
import paramiko
import paramiko.client

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
        self.ssh_cli = paramiko.client.SSHClient()
        self.ssh_cli.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.ssh_cli.connect("knuffodrag.ita.chalmers.se", username="bianj", password="BJS1998@Chalmers")
        self.ssh_chan = self.ssh_cli.invoke_shell()

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
    
    # power
    def send_command(self,command,method=1):
        self.ssh_chan.send(command + "\n")
        if method == 1:
            while not self.ssh_chan.recv_ready():
                time.sleep(1)
            
            output = ""
            while self.ssh_chan.recv_ready():
                output += self.ssh_chan.recv(999999).decode('utf-8')
        elif method == 2:
            output = ""
            while 1:
                while not self.ssh_chan.recv_ready():
                    time.sleep(1)
                while self.ssh_chan.recv_ready():
                    output += self.ssh_chan.recv(999999).decode('utf-8')
                if "@genus:root:" in output:
                    break
        return output
    def power_init(self):  
        command = "cd Downloads/quad && ls"
        output = self.send_command(command)
        command = "source setup.sh"
        output = self.send_command(command)
        command = "cd reference/tcl"
        output = self.send_command(command)
        command = "genus"
        output = self.send_command(command,2)
    def power_run(self,wl_config):
        command = f"delete_obj [get_db design:quad]"
        output = self.send_command(command,2)
        command = f"shell rm genus.* fv -rf"
        output = self.send_command(command,2)
        command = f"shell ./run.sh {wl_config[0]} {wl_config[1]} {wl_config[2]}"
        output = self.send_command(command,2)
        command = "source syn.tcl"
        output = self.send_command(command,2)
        command = "shell cat ../rpt/power.rpt"
        output = self.send_command(command,2)
        lines = output.split('\n')
        result = lines[19].split()[4]
        return float(result)

        

    ##################################
    
    def get_cost(self,wl_config):

        total_power = self.power_run(wl_config)
        print(f"Total Power: {total_power} nWatts")
         
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
        
        self.cur_loss = (self.cur_prec + 1e-8) * self.cur_cost
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
        print(f"Current Configuration: {wl_config}")
        self.get_cost(wl_config)
        self.get_prec(wl_config,ref_seq)
        self.cal_loss()
        print(f"MSE: {self.cur_prec}")
        print(f"Loss: {self.cur_loss}")

        # record config
        config_list = wl_config.tolist()
        self.record['x1'] = self.record['x1'] + [config_list[0]]
        self.record['x2'] = self.record['x2'] + [config_list[1]]
        self.record['x3'] = self.record['x3'] + [config_list[2]]

        return {"loss": self.cur_loss}, time.time() - start_time



    def run(self):
        # Open files outside the loop
        with open("simulation/input1.txt", "w") as input_file1, open("simulation/input2.txt", "w") as input_file2:
            for _ in range(131072):
                random_data_1 = random.randint(0, 2**14)
                random_data_2 = random.randint(0, 2**14)
                # Write data to files using the file objects
                input_file1.write(str(random_data_1) + "\n")
                input_file2.write(str(random_data_2) + "\n")
        dim = 3
        cs = CS.ConfigurationSpace()
        # for d in range(dim):
        cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x0", lower=0, upper=12))
        cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x1", lower=0, upper=12))
        cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x2", lower=0, upper=24))

        self.power_init()

        start_time = time.time()

        opt = TPEOptimizer(obj_func=self.obj_func, config_space=cs, min_bandwidth_factor=1e-2, resultfile="obj_func", max_evals=self.num_ite)
        print(opt.optimize(logger_name="obj_func"))

        sim_time = time.time() - start_time
        print("Overall time spent: ", sim_time, ", speed: ", sim_time/self.num_ite, " s/ite")
        self.record['time'] = self.record['time'] + [sim_time]
        print("Record: ", self.record)
        self.dump_record()

if __name__ == "__main__":
    obj = ref_host("ref-100", 100)
    obj.run()
