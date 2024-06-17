import numpy as np

class host:
    from abc import abstractmethod
    
    
    def __init__(self, name, num_ite):
        self.name = name

        self.num_ite = num_ite
        self.cur_config = np.array([])
        self.cur_cost = np.array([]) # power, area, etc.
        self.cur_prec = np.array([]) # precision: mse, etc. 
        self.cur_loss = np.array([])
        self.opt_time = 0

        self.record = {}
    
    
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
        with open('./result/'+self.name+'.json', 'w') as file:
            json.dump(self.record, file, indent=4)
    

    def lower_trend(self):
        loss_val = np.array(self.record['loss'])
        loss_len = np.size(loss_val)
        trend = np.array([])
        index = np.array([])
        for i in range(loss_len):
            if i == 0:
                trend = np.append(trend, [loss_val[i]])
                index = np.append(index, [i+1])
            elif i == loss_len - 1:
                if loss_val[i] < trend[-1]:
                    trend = np.append(trend, [loss_val[i]])
                    index = np.append(index, [i+1])
                else:
                    trend = np.append(trend, [trend[-1]])
                    index = np.append(index, [i+1])
            elif loss_val[i] < trend[-1]:
                trend = np.append(trend, [loss_val[i]])
                index = np.append(index, [i+1])
        return trend, index
    
    def draw_figure(self, type):
        import matplotlib.pyplot as plt
        import json
        # mse = self.record['mse']
        # power = self.record['power']
        # loss = self.record['loss']

        with open("./result/"+self.name+".json", 'r') as file:
            self.record = json.load(file)

        mse = self.record['mse']
        power = self.record['power']

        loss = self.record['loss']
    
        trend,tidx = self.lower_trend()
        trend = trend.tolist()
        tidx = tidx.tolist()
        print(np.size(trend))
        ite = np.arange(1, np.size(trend) + 1)
        # if type == 0:
        #     plt.scatter(mse, power)
        #     plt.xlabel('Mean Squared Error')
        #     plt.ylabel('Power')
        #     plt.show()
        if type == 2:
            plt.semilogy(mse, power)
            plt.xlabel('Mean Squared Error')
            plt.ylabel('Power')
            plt.show()
            plt.semilogy(tidx, trend,'ro--')
            plt.xlabel('# of iterations')
            plt.ylabel('Objective value')
            plt.show()

    @abstractmethod
    def run(self):
        pass

    