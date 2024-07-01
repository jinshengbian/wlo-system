import numpy as np

class host:
    from abc import abstractmethod
    
    
    def __init__(self, name, num_ite, mode, algo):
        self.name = name

        self.num_ite = num_ite
        # record
        self.index = 0
        self.conf = np.array([[None for _ in range(3)]])
        self.prec = np.array([None])
        self.cost = np.array([None])
        self.loss = np.array([None])
        self.opt_time = 0

        self.algo = algo
        self.mode = mode

    
    
    # get cost (power, area, etc.)
    @abstractmethod
    def get_cost(self):
        pass
    
    # get prec (mse, etc.)
    @abstractmethod
    def get_prec(self):
        pass
    
    # calculate loss
    @abstractmethod
    def calc_loss(self):
        pass
    
    def dump_record(self):
        import json
        record = {
            'conf': self.conf[1:self.num_ite+1].tolist(),
            'prec': self.prec[1:self.num_ite+1].tolist(),
            'cost': self.cost[1:self.num_ite+1].tolist(),
            'loss': self.loss[1:self.num_ite+1].tolist(),
            'opt_time': self.opt_time
        }
        with open('./result/'+self.name+'.json', 'w') as file:
            json.dump(record, file, indent=4)
    

    
    def draw_figure(self, type):
        pass

    @abstractmethod
    def run(self):
        pass

    