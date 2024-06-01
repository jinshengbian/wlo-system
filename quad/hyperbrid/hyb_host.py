import sys
sys.path.append('../../algo')
from host import *
from optimizer import optimizer

# sys.path.append('.')
# from syn_power import *

import serial
import time
import subprocess
import numpy as np
import matplotlib.pyplot as plt

class hyb_host(host):
    def __init__(self, name, num_ite, num_init, batch_siz):
        super().__init__(name, num_ite)
        self.record = {
            'x1': [],
            'x2': [],
            'x3': [],
            'mse': [],
            'power': [],
            'loss': [],
            'time': []
        }
        if num_ite%2 != 0 or num_init%2 != 0:
            raise ValueError("num_ite and num_init should be even numbers.")
        self.num_init = num_init
        self.num_ite = num_ite - num_init   
        self.batch_siz = batch_siz
        
    
    ##### self defined functions #####

    def uart_send_config(self, serial_ob:serial.Serial,config: np.array):
        cmd = bytes([2])
        serial_ob.write(cmd)
        for i in config:
            cmd = bytes([int(i)])
            serial_ob.write(cmd)

    def HW_start(self, serial_ob:serial.Serial):
        cmd = bytes([1])
        serial_ob.write(cmd)

    def HW_rst(self, serial_ob:serial.Serial):
        cmd = bytes([4])
        serial_ob.write(cmd)

    ##################################

    def get_cost(self):
        self.cur_cost = np.array([])
        for i in range(self.batch_siz):
            config = self.cur_config[i]
            # get configurations
            input_wl1 = config[0]
            input_wl2 = config[1]
            output_wl = config[2]

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
                #print(f"Total Power: {total_power} Watts")
            else:
                print("Failed to extract the power value.")   
            total_power = float(total_power) 

            self.cur_cost = np.append(self.cur_cost, np.array([total_power]))
            # record power
            self.record['power'] = self.record['power'] + [total_power]

    def get_prec(self):
        self.cur_prec = np.array([])
        cur_config = np.array([])
        for config in self.cur_config:
            cur_config = np.append(cur_config, config, axis=0)
        self.uart_send_config(serial_ob,cur_config)
        self.HW_start(serial_ob)
        # read received data
        msg = []
        while(1):
            msg.append(int.from_bytes(serial_ob.read(1), byteorder='big'))
            if len(msg)==16:
                break      
        # calculate mse
        for i in range(self.batch_siz):
            mse_val = 0
            for j in range(8):
                mse_val = mse_val + msg[i*8+j]*256**j
                mse_val = mse_val*2**14/131072
            self.cur_prec = np.append(self.cur_prec, np.array([mse_val]))
            # record mse
            self.record['mse'] = self.record['mse'] + [mse_val]


    # def calc_loss(self):
    #     self.cur_loss = np.array([])
    #     power_diff = np.array([])
    #     alpha = 10000
    #     power_max = 5*1e-5
    #     power_min = 1e-5
    #     print(self.cur_cost[0])
    #     for i in range(self.batch_siz):
    #         cur_cost = float(self.cur_cost[i])
    #         if cur_cost > power_max:
    #             power_diff = np.append(power_diff, cur_cost - power_max)
    #         elif cur_cost < power_min:
    #             power_diff = np.append(power_diff, power_min - cur_cost)
    #         else:
    #             power_diff = np.append(power_diff, np.array([0]))
            
    #         loss_val = self.cur_prec[i] + alpha * power_diff[i]
    #         self.cur_loss = np.append(self.cur_loss, np.array([loss_val]))
    #         # record loss
    #         self.record['loss'] = self.record['loss'] + [loss_val]

    def calc_loss(self):
        self.cur_loss = np.array([])
        alpha = 0.01
        for i in range(self.batch_siz):
            loss_val = (self.cur_prec[i]+1e-8) * (self.cur_cost[i])
            self.cur_loss = np.append(self.cur_loss, np.array([loss_val]))
            # record loss
            self.record['loss'] = self.record['loss'] + [loss_val]


    def obj_func(self, config: np.array):
        self.cur_config = config
        print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
        self.get_cost()
        self.get_prec()
        self.calc_loss()
        print(f"Config: {config}")
        print(f"Power : {self.cur_cost} Watts")
        print(f"MSE   : {self.cur_prec} ")

        # record configurations
        if self.batch_siz == 1:
            self.record['x1'] = self.record['x1'] + [config[0].tolist()]
            self.record['x2'] = self.record['x2'] + [config[1].tolist()]
            self.record['x3'] = self.record['x3'] + [config[2].tolist()]
        else:
            self.record['x1'] = self.record['x1'] + [config[0][0].tolist()]
            self.record['x2'] = self.record['x2'] + [config[0][1].tolist()]
            self.record['x3'] = self.record['x3'] + [config[0][2].tolist()]
        return self.cur_loss
        
    
    def run(self):
        search_space = np.array([
            [1,30],
            [1,30],
            [1,30]
        ])

        global serial_ob
        serial_ob = serial.Serial("/dev/ttyUSB0",115200)
        time_start = time.time()

        ############################## timer start
        print(self.num_ite)
        hyb_opt = optimizer(objec_func=self.obj_func,n_iterations=self.num_ite,n_init_points=self.num_init,search_space=search_space,SGD_learn_rate=10,batch_size=self.batch_siz)
        best_config = hyb_opt.optimization()
        ############################## timer end

        time_end = time.time()
        self.opt_time = time_end - time_start
        self.record['time'] = self.opt_time

        print(">> Best config is : ", best_config)
        print(">> Time in total  : ", self.opt_time, " s, average speed:", self.opt_time/self.num_ite," s/ite")

        self.dump_record()
        self.draw_figure(2)


if __name__ == "__main__":
    obj = hyb_host("test111", 200, 16, 2)
    obj.draw_figure(2)
