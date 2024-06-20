import sys
sys.path.append('../algo')
from host import *
from optimizer import optimizer

# sys.path.append('.')
# from syn_power import *
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
    # mode: simulation or hybrid
    # algo: watanabe or newtpe
    # syn_mode: "cadence" or "yosys"

    # parameters
    # simulation: name, num_ite, mode, algo, bsize=1, syn_mode, ref_seq
    # hybrid: name, num_ite, mode, algo, bsize, syn_mode, uart_ob, num_init

    def __init__(self, name="test", num_ite=100, mode="simulation", algo="watanabe", bsize=1, syn_mode="yosys"):
        # setup the host
        
        super().__init__(name, num_ite, mode, algo)
        self.syn_mode = syn_mode

        if mode == "simulation":
            self.bsize = 1
            self.ref_seq = self.read_ref_seq()
        elif mode == "hybrid":
            self.uart_ob = serial.Serial("/dev/ttyUSB1",115200)

        if algo == "newtpe":
            self.bsize = bsize
            num_init = 6
            if num_ite%2 != 0 or num_init%2 != 0:
                raise ValueError("num_ite and num_init should be even numbers.")
            self.num_init = num_init
            
            
        
        if syn_mode == "cadence":
            self.ssh_ob = paramiko.client.SSHClient()
            self.ssh_ob.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.ssh_ob.connect("knuffodrag.ita.chalmers.se", username="bianj", password="BJS1998@Chalmers")
            self.ssh_chan = self.ssh_ob.invoke_shell()
            self.ssh_power_init()

        self.record = {
            'x1': [],
            'x2': [],
            'x3': [],
            'prec': [],
            'cost': [],
            'loss': [],
            'time': []
        }



            
        
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
        command = "cd Downloads/quad && ls"
        output = self.ssh_send_command(command)
        command = "source setup.sh"
        output = self.ssh_send_command(command)
        command = "cd reference/tcl"
        output = self.ssh_send_command(command)
        command = "genus"
        output = self.ssh_send_command(command,2)
    def ssh_power_run(self,wl_config):
        command = f"delete_obj [get_db design:quad]"
        output = self.ssh_send_command(command,2)
        command = f"shell rm genus.* fv -rf"
        output = self.ssh_send_command(command,2)
        command = f"shell ./run.sh {wl_config[0]} {wl_config[1]} {wl_config[2]}"
        output = self.ssh_send_command(command,2)
        command = "source syn.tcl"
        output = self.ssh_send_command(command,2)
        command = "shell cat ../rpt/power.rpt"
        output = self.ssh_send_command(command,2)
        lines = output.split('\n')
        result = lines[19].split()[4]
        return float(result)
    
    # run simulation
    def run_sim(self,vals):
        try:
            tcl_commands = f"""
            vlib work
            vmap work work
            vlog ./simu/*.sv
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

    def read_ref_seq(self):
        wl_config = np.array([30,30,30])
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

    ####################################################################

    def get_cost(self):
        self.cur_cost = np.array([])
        for i in range(self.bsize):
            cur_config = self.cur_config[i]
            if self.syn_mode == "yosys":
                # modify the wordlength of the design
                with open("./synth/quad_syn.sv",'r') as dsp_design:
                    content = dsp_design.readlines()
                with open("./synth/quad_syn.sv",'w') as dsp_design:
                    content[5] = f"    input  logic [{cur_config[0]-1}:0] a,\n"
                    content[6] = f"    input  logic [{cur_config[1]-1}:0] b,\n"
                    content[7] = f"    output logic [{cur_config[2]-1}:0] c\n"
                    content[10] = f"logic [{2*cur_config[0]-1}:0] a_sq;\n"
                    content[11] = f"logic [{2*cur_config[1]-1}:0] b_sq;\n"
                    dsp_design.writelines(content)

                # run the synthesis script
                subprocess.run("python3 ./syn_power.py", shell=True, capture_output=True,text=True)
        
                # read power information
                rpt_file = "./synth/power.rpt"
                read_power_command = f"awk '/^Total/ {{print $5}}' {rpt_file}"
                res = subprocess.run(read_power_command, shell=True, capture_output=True, text=True)

                if res.returncode == 0:
                    total_power = res.stdout.strip()
                else:
                    print("Failed to extract the power value.")   
                total_power = float(total_power) * 1e9

            elif self.syn_mode == "cadence":
                total_power = self.ssh_power_run(cur_config)
                total_power = float(total_power)

            self.cur_cost = np.append(self.cur_cost, np.array([total_power]))
            # record power
            self.record['cost'] = self.record['cost'] + [total_power]

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


    def obj_func(self, config:dict[str, float])  -> tuple[dict[str, float], float]:
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
        print(f"Power : {self.cur_cost} (nW)")
        print(f"MSE   : {self.cur_prec} ")
        print(f"Loss  : {self.cur_loss}")

        # results
        if self.algo == "watanabe":
            result: tuple[dict[str, float], float]
            result = {"loss": self.cur_loss[0]}, time.time() - start_time
        elif self.algo == "newtpe":
            result = self.cur_loss

        # record configurations
        for i in range(self.bsize):
            self.record['x1'] = self.record['x1'] + [self.cur_config[i][0].tolist()]
            self.record['x2'] = self.record['x2'] + [self.cur_config[i][1].tolist()]
            self.record['x3'] = self.record['x3'] + [self.cur_config[i][2].tolist()]

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
        # self.ref_seq = self.read_ref_seq()
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
    obj = quad_host(name="quad-sim-newtpe-cadence", num_ite=100, mode="simulation", algo="newtpe", syn_mode="cadence")
    obj.run()
