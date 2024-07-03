import matplotlib.pyplot as plt
import json
import numpy as np



def lower_trend(loss):
    loss_val = np.array(loss)
    # loss_val = np.log2(loss_val)
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


with open("./hybrid_watanabe_100_batch1_round0.json", 'r') as file:
    refsim_data = json.load(file)
with open("./simulation_watanabe_100_batch1_round0.json", 'r') as file:
    newsim_data = json.load(file)
# with open("./hybrid_newtpe_250_batch1_round0.json", 'r') as file:
#     newhyb1_data = json.load(file)
# with open("./hybrid_newtpe_250_batch2_round0.json", 'r') as file:
#     newhyb2_data = json.load(file)












trend_refsim, idx_refsim = lower_trend(refsim_data["loss"])
trend_newsim, idx_newsim = lower_trend(newsim_data["loss"])
# trend_newhyb1, idx_newhyb1 = lower_trend(newhyb1_data["loss"])
# trend_newhyb2, idx_newhyb2 = lower_trend(newhyb2_data["loss"])


plt.semilogy(idx_refsim,trend_refsim,'bo--',label="Simulation, Watanabe")
plt.semilogy(idx_newsim,trend_newsim,'o--',color='orange',label="Simulation, TPE-WLO")
# plt.plot(idx_newhyb1,trend_newhyb1,'g^--',label="Hybrid, TPE-WLO (batch size = 1)")
# plt.plot(idx_newhyb2,trend_newhyb2,'r^--',label="Hybrid, TPE-WLO (batch size = 2)")
plt.legend()
plt.grid()
plt.xlabel("# of evaluations")
plt.ylabel("log10( Objective Function value )")
plt.savefig("./fir_trend.pdf")
plt.show()


mse_refsim = np.array(refsim_data["prec"])
mse_newsim = np.array(newsim_data["prec"])
# mse_newhyb1 = np.array(newhyb1_data["prec"])
# mse_newhyb2 = np.array(newhyb2_data["prec"])


area_refsim = np.array(refsim_data["cost"])
area_newsim = np.array(newsim_data["cost"])
# area_newhyb1 = np.array(newhyb1_data["cost"])
# area_newhyb2 = np.array(newhyb2_data["cost"])


mse_refsim=mse_refsim[area_refsim!=-1]
area_refsim=area_refsim[area_refsim!=-1]
mse_newsim=mse_newsim[area_newsim!=-1]
area_newsim=area_newsim[area_newsim!=-1]
# mse_newhyb1=mse_newhyb1[area_newhyb1!=-1]
# area_newhyb1=area_newhyb1[area_newhyb1!=-1]
# mse_newhyb2=mse_newhyb2[area_newhyb2!=-1]
# area_newhyb2=area_newhyb2[area_newhyb2!=-1]



# mse_refsim = np.log10(mse_refsim)
# mse_newsim = np.log10(mse_newsim)
# mse_newhyb1 = np.log10(mse_newhyb1)
# # mse_newhyb2 = np.log10(mse_newhyb2)

plt.scatter(mse_refsim, area_refsim,marker='.',label="Simulation, Watanabe")
plt.scatter(mse_newsim, area_newsim,marker='+',label="Simulation, TPE-WLO")
# plt.scatter(mse_newhyb1, area_newhyb1,marker='^',label="Hybrid, TPE-WLO (batch size = 1)")
# plt.scatter(mse_newhyb2, area_newhyb2,label="Hybrid, TPE-WLO (batch size = 2)")

plt.legend()
plt.grid()
plt.xlabel("MSE")
plt.ylabel("Area / $\mu m^{2}$")

plt.savefig("./fir_point.pdf")
plt.show()
