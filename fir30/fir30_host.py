
import sys
sys.path.append('../algo')
from host import *
from optimizer import optimizer

sys.path.append('../fir')
from fir_host import *

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

class fir30_host(fir_host):

    
    def __init__(self, name="test", num_ite=100, mode="simulation", algo="watanabe", bsize=1):
        super().__init__(name, num_ite, mode, algo)
        self.dimension = 30
        self.search_space = 24 # 0-24
        self.max_cost = 20000
        self.frac_wl = 12

        if mode == "simulation":
            self.gen_sim_input()
            self.ref_seq = self.read_ref_seq()

        self.ht = 5e-9
        self.lt = 5e-10
        self.tar = 1e-9
        # self.tar = (self.ht+self.lt)/2

        self.conf = np.array([[None for _ in range(self.dimension)]])
        
    ########################## self defined functions ##################

    # cadence synthesis
    
    def ssh_cad_init(self):  
        command = "cd Downloads/fir30/syn && ls"
        output = self.ssh_send_command(command)
        command = "source setup.sh"
        output = self.ssh_send_command(command)
        command = "genus -overwrite"
        output = self.ssh_send_command(command,2)
    
    # test
    def test_sim_batch(self):
        self.bsize = 1
        self.gen_sim_input()
        self.ref_seq = self.read_ref_seq()

        # config = np.ones((30),dtype=int)*22
        config = np.array([23,23,22,23,23,23,22,22,23,22,23,22,23,23,22,23,23,23,23,23,23,23,23,23,23,23,22,22,23,23])
        self.run_sim(config)
        sim_seq = self.read_output()
        sim_prec =  np.mean((self.ref_seq-sim_seq)**2)
        print("sim mse: ",sim_prec)

        # syn_result = self.ssh_cad_run(config)
        # syn_result = float(syn_result)

        # print("syn area: ", syn_result)

        self.uart_send_config(config)
        time.sleep(0.001)
        self.uart_hw_start()
        msg = []
        while(1):
            msg.append(int.from_bytes(self.uart_ob.read(1), byteorder='big'))
            if len(msg)==8*self.bsize:
                break   
        mse_val = 0
        for j in range(8):
            mse_val = mse_val + msg[0*8+j]*256**j
        mse_val = mse_val/131072/(2**(2*self.frac_wl))
        print("hyb mse: ", mse_val)
        # mse_val = 0
        # for j in range(8):
        #     mse_val = mse_val + msg[1*8+j]*256**j
        # mse_val = mse_val/131072/2**16
        # print("hyb mse: ", mse_val)

    ####################################################################

    
if __name__ == "__main__":
    

    # obj = fir30_host(name=f"simulation_watanabe_400_batch1_round0", num_ite=400, mode="simulation", algo="watanabe", bsize=1)
    # obj.run()



    obj = fir30_host(name=f"hybrid_watanabe_400_batch1_round0", num_ite=1000, mode="hybrid", algo="watanabe", bsize=1)
    obj.run()

    # obj.test_sim_batch()





    

    # cur_config = np.ones((30),dtype=int)*24
    # obj.run_sim(cur_config)
    # cur_seq = obj.read_output()
    # mse = np.mean((obj.ref_seq-cur_seq)**2)
    # print(mse)
