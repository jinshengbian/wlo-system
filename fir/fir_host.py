
import sys
sys.path.append('../algo')
from host import *
from optimizer import optimizer
import random
import paramiko
import paramiko.client
import serial
import time
import subprocess
import numpy as np
import matplotlib.pyplot as plt
import ConfigSpace as CS
import ConfigSpace.hyperparameters as CSH
from tpe.optimizer import TPEOptimizer

class fir_host(host):
    def __init__(self, name="test", num_ite=100, mode="simulation", algo="watanabe", bsize=1):
        super().__init__(name, num_ite, mode, algo)
        self.ssh_cad = paramiko.client.SSHClient()
        self.ssh_cad.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.ssh_cad.connect("knuffodrag.ita.chalmers.se", username="bianj", password="BJS1998@Chalmers")
        self.ssh_cad_chan = self.ssh_cad.invoke_shell()
        self.ssh_cad_init()
        if mode == "simulation":
            self.bsize = 1
            self.gen_sim_input()
            self.ref_seq = self.read_ref_seq()
        elif mode == "hybrid":
            self.uart_ob = serial.Serial("/dev/ttyUSB1",115200)

        if algo == "newtpe":
            self.bsize = bsize
            num_init = 6
            if num_ite%2 != 0 or num_init%2 != 0:
                raise ValueError("num_ite and num_init should be even numbers.")
            self.num_init = num_init

        self.record = {
            'conf': [],
            'prec': [],
            'cost': [],
            'loss': [],
            'time': []
        }

    ########################## self defined functions ##################
    
    # cadence synthesis
    def ssh_send_command(self,command,method=1):
        self.ssh_cad_chan.send(command + "\n")
        if method == 1:
            while not self.ssh_cad_chan.recv_ready():
                time.sleep(1)
            
            output = ""
            while self.ssh_cad_chan.recv_ready():
                output += self.ssh_cad_chan.recv(999999).decode('utf-8')
        elif method == 2:
            output = ""
            while 1:
                while not self.ssh_cad_chan.recv_ready():
                    time.sleep(1)
                while self.ssh_cad_chan.recv_ready():
                    output += self.ssh_cad_chan.recv(999999).decode('utf-8')
                if "@genus:root:" in output:
                    break
        return output
    
    def ssh_cad_init(self):  
        command = "cd Downloads/fir/syn && ls"
        output = self.ssh_send_command(command)
        command = "source setup.sh"
        output = self.ssh_send_command(command)
        command = "genus -overwrite"
        output = self.ssh_send_command(command,2)
    def ssh_cad_run(self,wl_config):
        command = f"delete_obj [get_db design:FIR]"
        output = self.ssh_send_command(command,2)
        command = f"shell rm genus.* fv -rf"
        output = self.ssh_send_command(command,2)
        command = f"shell ./change_wl.sh {wl_config[0]} {wl_config[1]} {wl_config[2]} {wl_config[3]} {wl_config[4]} {wl_config[5]} {wl_config[6]} {wl_config[7]} {wl_config[8]} {wl_config[9]} {wl_config[10]} {wl_config[11]} {wl_config[12]} {wl_config[13]} {wl_config[14]}"
        output = self.ssh_send_command(command,2)
        print(command)
        print(output)
        command = "source synthesis.tcl"
        output = self.ssh_send_command(command,2)
        command = "shell cat ./report/gates.rpt"
        output = self.ssh_send_command(command,2)
        lines = output.split('\n')
        for line in lines:  
            elements = line.split()  
            if elements and elements[0] == "total":  
                if len(elements) == 4:
                    result = elements[2]
                    break 
        # print(output)
        # print("area: ", result)
        return float(result)

    # simulation
    def gen_sim_input(self):
        n_simulations = int(131072)
        # Open files outside the loop
        with open("simu/input.txt", "w") as input_file:
            for _ in range(n_simulations):
                random_data = random.randint(0, 2**10)
                
                # Write data to files using the file objects
                input_file.write(str(random_data) + "\n")

    def modify_sim_wl(self,config):
        print(config)
        command = f'./simu/sim_wl.sh {config[0]} {config[1]} {config[2]} {config[3]} {config[4]} {config[5]} {config[6]} {config[7]} {config[8]} {config[9]} {config[10]} {config[11]} {config[12]} {config[13]} {config[14]}'
        
        
        subprocess.run([command],  shell=True, capture_output=True,text=True)

    def run_sim(self,vals):
        self.modify_sim_wl(vals)
        try:
            tcl_commands = f"""
            vlib work
            vmap work work
            vlog ./simu/*.sv
            vsim FIR_tb -voptargs=+acc

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
    def read_ref_seq(self):
        wl_config = np.array([16,16,16,16,16,16,16,16,16,16,16,16,16,16,16])
        #wl_config = np.array([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0])
        self.run_sim(wl_config)
        ref_seq = self.read_output()
        return ref_seq
    def read_output(self):
        seq = []
        with open('simu/output.txt', 'r') as file:
            for line in file:
                for item in line.split():
                    try:
                        seq.append(float(item))
                    except ValueError:
                        pass
        seq = np.array(seq)
        return seq
    # # hyp mode: UART communication
    def uart_send_config(self,config: np.array):
        cmd = bytes([2])
        self.uart_ob.write(cmd)
        for i in config:
            cmd = bytes([int(i)])
            self.uart_ob.write(cmd)
    def uart_hw_start(self):
        cmd = bytes([1])
        self.uart_ob.write(cmd)
    def uart_hw_reset(self):
        cmd = bytes([4])
        self.uart_ob.write(cmd)

    ####################################################################
    def get_cost(self): # cadence
        self.cur_cost = np.array([])
        for i in range(self.bsize):
            cur_config = self.cur_config[i]
            syn_result = self.ssh_cad_run(cur_config)
            syn_result = float(syn_result)
            self.cur_cost = np.append(self.cur_cost, np.array([syn_result]))
            # record cost
            self.record['cost'] = self.record['cost'] + [syn_result]

    def get_prec(self):
        self.cur_prec = np.array([])
        if self.mode == "simulation":
            cur_config = self.cur_config[0]
            print(cur_config)
            self.run_sim(cur_config)
            cur_seq = self.read_output()
            self.cur_prec = np.append(self.cur_prec, np.mean((self.ref_seq-cur_seq)**2))
            # record mse
            self.record['prec'] = self.record['prec'] + self.cur_prec.tolist()
        elif self.mode == "hybrid":
            cur_config = np.array([])
            for config in self.cur_config:
                cur_config = np.append(cur_config, config, axis=0)
            self.uart_send_config(cur_config)
            self.uart_hw_start()
            # read received data
            msg = []
            while(1):
                msg.append(int.from_bytes(self.uart_ob.read(1), byteorder='big'))
                if len(msg)==8*self.bsize:
                    break      
            # calculate mse
            for i in range(self.bsize):
                mse_val = 0
                for j in range(8):
                    mse_val = mse_val + msg[i*8+j]*256**j
                mse_val = mse_val*2**13/131072
                self.cur_prec = np.append(self.cur_prec, np.array([mse_val]))
                # record mse
                self.record['prec'] = self.record['prec'] + [mse_val]



    def calc_loss(self):
        self.cur_loss = np.array([])
        for i in range(self.bsize):
            loss_val = abs(self.cur_prec[i]-1e8) + (self.cur_cost[i])
            self.cur_loss = np.append(self.cur_loss, np.array([loss_val]))
            # record loss
            self.record['loss'] = self.record['loss'] + [loss_val]
    
    def obj_func(self, config):
        # get configurations
        if self.algo == "watanabe":
            start_time = time.time() 
            self.cur_config = np.array([list(config.values())])
        elif self.algo == "newtpe":
            self.cur_config = config
        
        # evaluate the config
        print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
        self.get_cost()
        self.get_prec()
        self.calc_loss()
        print(f"Config: {self.cur_config}")
        print(f"Area  : {self.cur_cost}")
        print(f"MSE   : {self.cur_prec}")
        print(f"Loss  : {self.cur_loss}")

        # results
        if self.algo == "watanabe":
            result: tuple[dict[str, float], float]
            result = {"loss": self.cur_loss[0]}, time.time() - start_time
        elif self.algo == "newtpe":
            result = self.cur_loss

        # record configurations
        for i in range(self.bsize):
            self.record['conf'] = self.record['conf'] + [self.cur_config[i].tolist()]
        return result
    
    def run(self):
        # define search space
        if self.algo == "watanabe":
            cs = CS.ConfigurationSpace()
            dim = 15
            for d in range(dim):
                cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x{d}", lower=0, upper=16))

        elif self.algo == "newtpe":
            search_space = np.array([
                [0, 16],[0, 16],[0, 16],[0, 16],[0, 16],
                [0, 16],[0, 16],[0, 16],[0, 16],[0, 16],
                [0, 16],[0, 16],[0, 16],[0, 16],[0, 16]
            ])

        # print information
        print(">>>>>>>>>>>>>>> Start optimization")

        time_start = time.time()
        # optimization 
        if self.algo == "watanabe":
            opt = TPEOptimizer(obj_func=self.obj_func, config_space=cs, min_bandwidth_factor=1e-2, resultfile="obj_func", max_evals=self.num_ite)
            print(opt.optimize(logger_name="obj_func"))
        elif self.algo == "newtpe":
            opt = optimizer(objec_func=self.obj_func,n_iterations=(self.num_ite-self.num_init),n_init_points=self.num_init,search_space=search_space,SGD_learn_rate=10,batch_size=self.bsize)
            best_config = opt.optimization()
        time_end = time.time()

        # results
        self.opt_time = time_end - time_start
        self.record['time'] = self.opt_time
        print(">> Time in total  : ", self.opt_time, " s")
        self.dump_record()
  
if __name__ == "__main__":
    obj = fir_host()
    obj.run()
