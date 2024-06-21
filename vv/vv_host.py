import sys
sys.path.append('../algo')
from host import *
from optimizer import optimizer

import paramiko
import paramiko.client

import time
import subprocess
import numpy as np
import matplotlib.pyplot as plt
import ConfigSpace as CS
import ConfigSpace.hyperparameters as CSH
from tpe.optimizer import TPEOptimizer





class vv_host(host):
    def __init__(self, name="test", num_ite=100, mode="simulation", algo="watanabe"):
        super().__init__(name, num_ite, mode, algo)

        self.ssh_cad = paramiko.client.SSHClient()
        self.ssh_cad.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.ssh_cad.connect("knuffodrag.ita.chalmers.se", username="bianj", password="BJS1998@Chalmers")
        self.ssh_cad_chan = self.ssh_cad.invoke_shell()
        self.ssh_cad_init()

        if mode == "simulation":
            self.bsize = 1
            self.ref_seq = self.read_ref_seq()
        elif mode == "hybrid":
            self.ssh_emu = paramiko.client.SSHClient()
            self.ssh_emu.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.ssh_emu.connect("knuffodrag.ita.chalmers.se", username="bianj", password="BJS1998@Chalmers")
            self.ssh_emu_chan = self.ssh_emu.invoke_shell()
            self.ssh_emu_init()
        self.record = {
            'x1': [],
            'x2': [],
            'x3': [],
            'x4': [],
            'x5': [],
            'prec': [],
            'cost': [],
            'loss': [],
            'time': []
        }
    
    ########################## self defined functions ##################




    ####################################################################
    def get_cost(self):
        pass

    def get_prec(self):
        pass

    def calc_loss(self):
        pass

    def obj_func(self, config):
        # get configurations
        if self.algo == "watanabe":
            start_time = time.time() 
            self.cur_config = np.array([list(config.values())])
        elif self.algo == "newtpe":
            self.cur_config = config

    def run(self):
        # define search space
        if self.algo == "watanabe":
            cs = CS.ConfigurationSpace()
            # for d in range(dim):
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x0", lower=0, upper=8))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x1", lower=0, upper=8))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x2", lower=0, upper=11))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x3", lower=0, upper=7))
            cs.add_hyperparameter(CSH.UniformIntegerHyperparameter(f"x4", lower=0, upper=8))
        elif self.algo == "newtpe":
            search_space = np.array([
                [0,8],
                [0,8],
                [0,11],
                [0,7],
                [0,8]
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
    obj = vv_host()
    obj.run()