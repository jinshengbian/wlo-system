import sys
sys.path.append('../algo')
from host import *
from optimizer import optimizer
import os
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

class quad_host(host):

    def __init__(self, name="test", num_ite=100, mode="simulation", algo="watanabe", bsize=1):
        # setup the host
        
        super().__init__(name, num_ite, mode, algo)

        if mode == "simulation":
            print("sim init")
            self.bsize = 1
            self.gen_sim_input()
            self.ref_seq = self.read_ref_seq()
        elif mode == "hybrid":
            self.bsize = bsize
            self.uart_ob = serial.Serial("/dev/ttyUSB0",115200)

        if algo == "newtpe":
            self.bsize = bsize
            num_init = 16
            if num_ite%2 != 0 or num_init%2 != 0:
                raise ValueError("num_ite and num_init should be even numbers.")
            self.num_init = num_init
       
        self.ssh_ob = paramiko.client.SSHClient()
        self.ssh_ob.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.ssh_ob.connect("knuffodrag.ita.chalmers.se", username="bianj", password="BJS1998@Chalmers")
        self.ssh_chan = self.ssh_ob.invoke_shell()
        self.ssh_power_init()

        self.ht=  6e-5;
        self.lt = 2e-5;
        self.tar = (self.ht+self.lt)/2
    
        # record
        self.index = 0
        self.conf = np.array([[None for _ in range(3)]])
        self.prec = np.array([None])
        self.cost = np.array([None])
        self.loss = np.array([None])
        self.opt_time = 0




            
        
    ########################## self defined functions ##################
    
    # cadence power
    def ssh_send_command(self,command,method=1):
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
    def ssh_power_init(self):  
        command = "cd Downloads/quad/syn && ls"
        output = self.ssh_send_command(command)
        command = "source setup.sh"
        output = self.ssh_send_command(command)
        command = "genus -overwrite"
        output = self.ssh_send_command(command,2)
    def ssh_power_run(self,wl_config):
        command = f"delete_obj [get_db design:quad]"
        output = self.ssh_send_command(command,2)
        command = f"shell rm genus.* fv -rf"
        output = self.ssh_send_command(command,2)
        command = f"shell ./change_wl.sh {wl_config[0]} {wl_config[1]} {wl_config[2]}"
        output = self.ssh_send_command(command,2)
        # print(output)
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
    
    # run simulation
    def gen_sim_input(self):
        n_simulations = int(131072)
        # Open files outside the loop
        with open("simu/input1.txt", "w") as input_file:
            for _ in range(n_simulations):
                random_data = random.randint(0, 2**14) 
                # Write data to files using the file objects
                input_file.write(str(random_data) + "\n")
        with open("simu/input2.txt", "w") as input_file:
            for _ in range(n_simulations):
                random_data = random.randint(0, 2**14) 
                # Write data to files using the file objects
                input_file.write(str(random_data) + "\n")
    def modify_sim_wl(self,config):

        command = f'./simu/sim_wl.sh {config[0]} {config[1]} {config[2]}'
        
        subprocess.run([command],  shell=True, capture_output=True,text=True)
    def run_sim(self,vals):
        self.modify_sim_wl(vals)
        try:
            tcl_commands = f"""
            vlib work
            vmap work work
            vlog ./simu/*.sv
            vsim quad_tb -voptargs=+acc
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
        wl_config = np.array([12,12,24])
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
        seq = np.array(seq)/2**24
        return seq
    
    # hyp mode: UART communication
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

    def test_sim_batch(self):
        self.bsize = 1
        
        self.ref_seq = self.read_ref_seq()

        config = np.array([9,9,15])
        # config1 = np.ones((15),dtype=int)*1
        # config = np.append(config,config1)
        self.run_sim(config)
        sim_seq = self.read_output()
        print(self.ref_seq)
        print(sim_seq)
        sim_prec =  np.mean((self.ref_seq-sim_seq)**2)
        print("sim mse: ",sim_prec)

        syn_result = self.ssh_power_run(config)
        syn_result = float(syn_result)

        print("syn area: ", syn_result)

        self.uart_send_config(config)
        self.uart_hw_start()
        msg = []
        while(1):
            msg.append(int.from_bytes(self.uart_ob.read(1), byteorder='big'))
            if len(msg)==8*self.bsize:
                break   
        mse_val = 0
        for j in range(8):
            mse_val = mse_val + msg[0*8+j]*256**j
        mse_val = mse_val*2**14/131072/2**48
        print("hyb mse: ", mse_val)
        # mse_val = 0
        # for j in range(8):
        #     mse_val = mse_val + msg[1*8+j]*256**j
        # mse_val = mse_val/131072/2**16
        # print("hyb mse: ", mse_val)
    ####################################################################

    def get_cost(self):
        for i in range(self.bsize):
            cur_index = self.index-(self.bsize-i-1)
            if self.prec[cur_index] < self.lt or self.prec[cur_index] > self.ht:
                self.cost = np.append(self.cost, np.array([-1]))
            else:
                for i in range(1,cur_index):
                    if np.all(self.conf[cur_index] == self.conf[i]):
                        self.cost = np.append(self.cost, self.cost[i])
                        return
                    
                cur_config = self.conf[cur_index]
                
                syn_result = self.ssh_power_run(cur_config)
                # syn_result = np.sum(cur_config)
                syn_result = float(syn_result)
                self.cost = np.append(self.cost, np.array([syn_result]))

    def get_prec(self):
        if self.mode == "simulation":
            cur_config = self.conf[self.index]
            self.run_sim(cur_config)
            cur_seq = self.read_output()
            self.prec = np.append(self.prec, np.mean((self.ref_seq-cur_seq)**2))

        elif self.mode == "hybrid":
            cur_config = np.array([])
            for i in range(self.bsize):
                cur_index = self.index-(self.bsize-i-1)
                cur_config = np.append(cur_config, self.conf[cur_index])
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
                mse_val = mse_val*2**14/131072/2**48
                self.prec = np.append(self.prec, np.array([mse_val]))

    def calc_loss(self):
        for i in range(self.bsize):
            cur_index = self.index-(self.bsize-i-1)
            if self.prec[cur_index] < self.lt or self.prec[cur_index] > self.ht:
                loss_val = abs(self.prec[cur_index]-self.tar)*4625
            else :
                loss_val = abs(self.prec[cur_index]-self.tar)*(self.cost[cur_index])
            self.loss = np.append(self.loss, np.array([loss_val]))

    def obj_func(self, config):
        self.index = self.index + self.bsize
        # get configurations
        if self.algo == "watanabe":
            start_time = time.time() 
            self.conf = np.append(self.conf, [np.array(list(config.values()))],axis=0)
        elif self.algo == "newtpe":
            self.conf = np.append(self.conf, config, axis=0)

        # evaluate the config
        print(f">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ite: {int(self.index/self.bsize)}")
        self.get_prec()
        self.get_cost()
        self.calc_loss()

        print(f"Config: {self.conf[self.index-self.bsize+1:self.index+1]}")
        print(f"Area  : {self.cost[self.index-self.bsize+1:self.index+1]}")
        print(f"MSE   : {self.prec[self.index-self.bsize+1:self.index+1]}")
        print(f"Loss  : {self.loss[self.index-self.bsize+1:self.index+1]}")

        # results
        if self.algo == "watanabe":
            result: tuple[dict[str, float], float]
            result = {"loss": self.loss[self.index]}, time.time() - start_time
        elif self.algo == "newtpe":
            result = self.loss[self.index-self.bsize+1:self.index+1]

        return result

    
    def run(self):
        # define search space
        if self.algo == "watanabe":
            cs = CS.ConfigurationSpace()
            # for d in range(dim):
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x0", lower=0, upper=12))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x1", lower=0, upper=12))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x2", lower=0, upper=24))
        elif self.algo == "newtpe":
            search_space = np.array([
                [0,12],
                [0,12],
                [0,24]
            ])

        # print information
        print(">>>>>>>>>>>>>>> Start optimization")

        time_start = time.time()
        # optimization 
        if self.algo == "watanabe":
            opt = TPEOptimizer(obj_func=self.obj_func, config_space=cs, min_bandwidth_factor=1e-2, resultfile="obj_func", max_evals=self.num_ite,n_ei_candidates=50,n_init=16)
            print(opt.optimize(logger_name="obj_func"))
        elif self.algo == "newtpe":
            opt = optimizer(objec_func=self.obj_func,n_iterations=(self.num_ite-self.num_init),n_init_points=self.num_init,search_space=search_space,SGD_learn_rate=10,batch_size=self.bsize,if_uniform_start=False)
            best_config = opt.optimization()
        time_end = time.time()

        # results
        self.opt_time = time_end - time_start

        print(">> Time in total  : ", self.opt_time, " s")
        self.dump_record()


if __name__ == "__main__":
    for i in range(1):
        obj = quad_host(name=f"simulation_watanabe_70_batch1_round{i}", num_ite=70, mode="simulation", algo="watanabe", bsize=1)
        obj.run()

        obj = quad_host(name=f"hybrid_watanabe_70_batch1_round{i}", num_ite=70, mode="hybrid", algo="watanabe", bsize=1)
        obj.run()

        # obj = quad_host(name=f"hybrid_newtpe_70_batch1_round{i}", num_ite=70, mode="hybrid", algo="newtpe", bsize=1)
        # obj.run()
    # obj.test_sim_batch()


