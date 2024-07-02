import sys
sys.path.append('../algo')
from host import *
from optimizer import optimizer
import os
import paramiko
import paramiko.client
import struct
import time
import subprocess
import numpy as np
import matplotlib.pyplot as plt
import ConfigSpace as CS
import ConfigSpace.hyperparameters as CSH
from tpe.optimizer import TPEOptimizer





class vv_host(host):
    def __init__(self, name="test", num_ite=100, mode="hybrid", algo="watanabe"):
        super().__init__(name, num_ite, mode, algo)

        self.ssh_cad = paramiko.client.SSHClient()
        self.ssh_cad.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.ssh_cad.connect("knuffodrag.ita.chalmers.se", username="bianj", password="BJS1998@Chalmers")
        self.ssh_cad_chan = self.ssh_cad.invoke_shell()
        self.ssh_cad_init()

        if mode == "simulation":
            self.simu_init()
        elif mode == "hybrid":
            self.ssh_emu = paramiko.client.SSHClient()
            self.ssh_emu.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.ssh_emu.connect("twix.mc2.chalmers.se", username="bianj", password="ah669824")
            # self.ssh_emu_chan = self.ssh_emu.invoke_shell()
            # self.ssh_emu_init()
        
        if algo == "newtpe":
            num_init = 16
            if num_ite%2 != 0 or num_init%2 != 0:
                raise ValueError("num_ite and num_init should be even numbers.")
            self.num_init = num_init

        self.ht=  0.014;
        self.lt = 0.013;
        self.tar = (self.ht+self.lt)/2
        
        # record
        self.index = 0
        self.conf = np.array([[None for _ in range(5)]])
        self.prec = np.array([None])
        self.cost = np.array([None])
        self.loss = np.array([None])
        self.opt_time = 0


    ########################## self defined functions ##################
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
        command = "cd Downloads/vv/syn && ls"
        output = self.ssh_send_command(command)
        
        command = "source setup.sh"
        output = self.ssh_send_command(command)
        command = "genus -overwrite"
        output = self.ssh_send_command(command,2)
    def ssh_cad_run(self,wl_config):
        command = f"delete_obj [get_db design:vv_wrapper]"
        output = self.ssh_send_command(command,2)
        command = f"shell rm genus.* fv -rf"
        output = self.ssh_send_command(command,2)
        command = f"shell bash ./change_wl.sh {wl_config[0]} {wl_config[1]} {wl_config[2]} {wl_config[3]} {wl_config[4]}"
        output = self.ssh_send_command(command,2)
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
    def simu_init(self):
        with open("./sim/GN_1.txt","r") as gn_file1, open("./sim/GN_2.txt","r") as gn_file2, open("./sim/GN_3.txt","r") as gn_file3,\
        open("./sim/bit_in.txt","r") as bit_file:
            self.gn_1 = gn_file1.readlines()
            self.gn_2 = gn_file2.readlines()
            self.gn_3 = gn_file3.readlines()
            bit_data = bit_file.readlines()
            self.noise1 = np.zeros(len(self.gn_1),dtype=float)
            self.noise2 = np.zeros(len(self.gn_1),dtype=float)
            self.noise3 = np.zeros(len(self.gn_1),dtype=float)
            for i in range(len(self.gn_1)):
                self.noise1[i] = self.gn_1[i]
                self.noise2[i] = self.gn_2[i]
                self.noise3[i] = self.gn_3[i]
            self.bit_vector = np.zeros(len(bit_data),dtype=int)
            for i in range(len(bit_data)):
                self.bit_vector[i] = bit_data[i]

    def MOD_16QAM(self, bit_vector):
        n_sym = int(len(bit_vector)/4)
        symbols = np.zeros(n_sym,dtype=complex)
        amp = np.sqrt(0.9)
        for i in range(n_sym):
            if bit_vector[i*4+1] == 0:
                real_part = -amp if bit_vector[i*4+0] == 0 else amp
            elif bit_vector[i*4+1] == 1:
                real_part = -amp/3 if bit_vector[i*4+0] == 0 else amp/3
            if bit_vector[i*4+3] == 0:
                imag_part = -amp if bit_vector[i*4+2] == 1 else amp
            elif bit_vector[i*4+3] == 1:
                imag_part = -amp/3 if bit_vector[i*4+2] == 1 else amp/3
            symbols[i] = real_part + imag_part*1j
        return symbols

    def DEMOD_16QAM(self,symbol_vector):
        n_symbols = int(len(symbol_vector))
        bits = np.zeros(n_symbols*4,dtype=int)
        amp = np.sqrt(0.9)
        for i in range(n_symbols):
            real_value = symbol_vector[i].real
            if real_value > amp*2/3:
                bits[i*4+0] = 1;bits[i*4+1] = 0
            elif real_value <= amp*2/3 and real_value >= 0:
                bits[i*4+0] = 1;bits[i*4+1] = 1
            elif real_value >= -amp*2/3 and real_value < 0:
                bits[i*4+0] = 0;bits[i*4+1] = 1
            elif real_value < -amp*2/3:
                bits[i*4+0] = 0;bits[i*4+1] = 0
            imag_value = symbol_vector[i].imag
            if imag_value > amp*2/3:
                bits[i*4+2] = 0;bits[i*4+3] = 0
            elif imag_value <= amp*2/3 and imag_value >= 0:
                bits[i*4+2] = 0;bits[i*4+3] = 1
            elif imag_value >= -amp*2/3 and imag_value < 0:
                bits[i*4+2] = 1;bits[i*4+3] = 1
            elif imag_value < -amp*2/3:
                bits[i*4+2] = 1;bits[i*4+3] = 0
        return bits
    def add_complex_awgn(self,x,mu,sigma2):
        # return x+mu+np.sqrt(sigma2/2)*np.random.randn(np.size(x))+1j*np.sqrt(sigma2/2)*np.random.randn(np.size(x))
        return x+mu+np.sqrt(sigma2/2)*self.noise2+1j*np.sqrt(sigma2/2)*self.noise3
    def add_phase_drif(self,x, phase_var):
        phi = np.cumsum(np.sqrt(phase_var)*self.noise1)
        return x*np.exp(1j*phi)
    def import_vectors(self):
        with open("sim/run/i_out.vec","rb",) as i_out, open("sim/run/q_out.vec","rb") as q_out:
            i_binary = i_out.read()
            q_binary = q_out.read()
            i_int32 = struct.unpack('i' * (len(i_binary) // 4), i_binary)
            q_int32 = struct.unpack('i' * (len(q_binary) // 4), q_binary)
        real_part = np.array(i_int32)
        imag_part = np.array(q_int32)
        output = np.array(real_part + 1j*imag_part,dtype=complex)
        return output
    
    def export_vectors(self,symbols):
        with open("sim/run/i_in.vec","wb",) as i_in, open("sim/run/q_in.vec","wb") as q_in:
            imag_int = np.floor(symbols.imag)
            real_int = np.floor(symbols.real)
            for i in range(len(symbols)):
                i_in.write(real_int[i].astype(np.int32).tobytes())
                q_in.write(imag_int[i].astype(np.int32).tobytes())
    def update_tb(self,config):
        command = f'./sim/sim_wl.sh {config[0]} {config[1]} {config[2]} {config[3]} {config[4]}'
        os.system(command)
        
    def simu_vv(self,config):
        # Number of symbols
        num_symbols = 32000*4
        
        # QAM modulation and fiber settings
        M = 16.0  # 16-QAM
        snr=8.0
        linewidth=100e3
        baudrate = 10e9
        input_wl = 8.0
        # Generate random integer symbols
        # symbols = np.random.randint(0,2, size=num_symbols)
        symbols = self.bit_vector
        # QAM modulation
        modulated_symbols = self.MOD_16QAM(symbols)
        scaling_AMP = 2.6832

        symb_pn = self.add_phase_drif(modulated_symbols,2*np.pi*linewidth/baudrate)
        symb_awgn = self.add_complex_awgn(symb_pn,0,1/np.log2(M)/10**(snr/10))
        symb_awgn = symb_awgn/scaling_AMP
        symb_expo = symb_awgn*(2**(input_wl-1)-1)

        self.export_vectors(symb_expo)
        BER = 0.0
        BER_ref = 0.0

        self.update_tb(config)
        os.system(" ./sim/sim.sh > sim_log.log")
        out_vhdl = self.import_vectors()
        out_rescal = out_vhdl/(2**(input_wl-1)-1)*scaling_AMP
            # sym_rescal = symb_expo/(2**(input_wl-1)-1)*scaling_AMP
        out_demod = self.DEMOD_16QAM(out_rescal)
            # ref_demod = DEMOD_16QAM(sym_rescal)
        BER = np.sum(symbols != out_demod)/len(symbols)
            # BER_ref[i] = np.sum(symbols != ref_demod)/len(symbols)

        return float(BER)
    # remote BER
    def remote_BER(self,configs):

        command = "python3 test.py ttyUSB8 " + " ".join(map(str,configs.astype(int)))
        # print(command)
        _stdin, _stdout,_stderr = self.ssh_emu.exec_command(command)
        
        ber = float(_stdout.read().decode())

        return ber
    ####################################################################
    def get_cost(self):
        cur_index = self.index
        if self.prec[cur_index] < self.lt or self.prec[cur_index] > self.ht:
            self.cost = np.append(self.cost, np.array([-1]))
        else:
            for i in range(1,cur_index):
                if np.all(self.conf[cur_index] == self.conf[i]):
                    self.cost = np.append(self.cost, self.cost[i])
                    return
            cur_config = self.conf[cur_index]
            syn_result = self.ssh_cad_run(cur_config)
            # syn_result = np.sum(cur_config)
            syn_result = float(syn_result)
            self.cost = np.append(self.cost, np.array([syn_result]))


    def get_prec(self):
        cur_config = self.conf[self.index]
        if self.mode == "simulation":
            prec = self.simu_vv(cur_config)
            self.prec = np.append(self.prec, np.array([prec]))
        elif self.mode == "hybrid":
            prec = self.remote_BER(cur_config)
            self.prec = np.append(self.prec, np.array([prec]))


    def calc_loss(self):
        cur_index = self.index
        if self.prec[cur_index] < self.lt or self.prec[cur_index] > self.ht:
            loss_val = abs(self.prec[cur_index]-self.tar)*35000
        else :
            loss_val = abs(self.prec[cur_index]-self.tar)*(self.cost[cur_index])
        self.loss = np.append(self.loss, np.array([loss_val]))


    def obj_func(self, config):
        self.index = self.index + 1
        # get configurations
        if self.algo == "watanabe":
            start_time = time.time() 
            self.conf = np.append(self.conf, [np.array(list(config.values()))],axis=0)
        elif self.algo == "newtpe":
            self.conf = np.append(self.conf, config, axis=0)

        # evaluate the config
        print(f">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ite: {int(self.index)}")
        print(f"Config: {self.conf[self.index:self.index+1]}")
        self.get_prec()
        self.get_cost()
        self.calc_loss()
        
        print(f"Area  : {self.cost[self.index:self.index+1]}")
        print(f"MSE   : {self.prec[self.index:self.index+1]}")
        print(f"Loss  : {self.loss[self.index:self.index+1]}")

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
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x0", lower=2, upper=8))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x1", lower=2, upper=8))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x2", lower=2, upper=12))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x3", lower=2, upper=12))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x4", lower=2, upper=10))
        elif self.algo == "newtpe":
            search_space = np.array([
                [2,8],
                [2,8],
                [2,12],
                [2,12],
                [2,10]
            ])
        # print information
        print(">>>>>>>>>>>>>>> Start optimization")

        time_start = time.time()
        # optimization 
        if self.algo == "watanabe":
            opt = TPEOptimizer(obj_func=self.obj_func, config_space=cs, min_bandwidth_factor=1e-2, resultfile="obj_func", max_evals=self.num_ite,n_ei_candidates=50,n_init=16)
            print(opt.optimize(logger_name="obj_func"))
        elif self.algo == "newtpe":
            opt = optimizer(objec_func=self.obj_func,n_iterations=(self.num_ite-self.num_init),n_init_points=self.num_init,search_space=search_space,SGD_learn_rate=10,batch_size=1,if_uniform_start=False)
            best_config = opt.optimization()
        time_end = time.time()

        # results
        self.opt_time = time_end - time_start
        print(">> Time in total  : ", self.opt_time, " s")
        self.dump_record()

if __name__ == "__main__":
    obj = vv_host(name = "simulation_watanabe_100_batch1_round0", num_ite=100, mode="simulation", algo="watanabe")
    # obj.run()
    # obj = vv_host(name = "hybrid_watanabe_100_batch1_round0", num_ite=100, mode="hybrid", algo="watanabe")
    # obj.run()
    # obj = vv_host(name = "simulation_newtpe_100_batch1_round0", num_ite=100, mode="simulation", algo="newtpe")
    # obj.run()
    # obj = vv_host(name = "hybrid_newtpe_100_batch1_round0", num_ite=100, mode="hybrid", algo="newtpe")
    # obj.run()
    conf = [8,8,8,8,8]
    result = obj.simu_vv(conf)
    print(conf)
    print(result)

