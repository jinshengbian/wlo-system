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
        self.batch_siz = batch_siz
        
    def uart_send_config(self, serial_ob:serial.Serial,config: np.array):
        cmd = bytes([2])
        serial_ob.write(cmd)
        print(config)
        for i in config:
            cmd = bytes([int(i)])
            serial_ob.write(cmd)

    def HW_start(self, serial_ob:serial.Serial):
        cmd = bytes([1])
        serial_ob.write(cmd)

    def HW_rst(self, serial_ob:serial.Serial):
        cmd = bytes([4])
        serial_ob.write(cmd)


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
                mse_val = mse_val/2**14/1e5
            self.cur_prec = np.append(self.cur_prec, np.array([mse_val]))
                # record mse

if __name__ == '__main__':
    serial_ob = serial.Serial('/dev/ttyUSB0', 115200)
    host = hyb_host('hyb_host', 100, 10,2)
    host.cur_config = np.array([[30,30,30],[2,2,2]])
    host.get_prec()
    print(host.cur_prec)