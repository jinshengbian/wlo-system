import matplotlib.pyplot as plt
import json
import numpy as np



def lower_trend(loss):
    loss_val = np.array(loss)
    loss_val = np.log10(loss_val)
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


with open("./fir/result/hybrid_watanabe_300_batch1.json", 'r') as file:
    ref_data = json.load(file)
with open("./fir/result/hybrid_newtpe_300_batch1_round2.json", 'r') as file:
    new_data = json.load(file)
max_value = min(ref_data['loss'])
max_index = ref_data['loss'].index(max_value)

max_value = min(new_data['loss'])
max_index = new_data['loss'].index(max_value)


trend_ref, idx_ref = lower_trend(ref_data["loss"])
trend_new, idx_new = lower_trend(new_data["loss"])


plt.plot(idx_ref,trend_ref,'b^--',label="ref")
plt.plot(idx_new,trend_new,'ro--',label="new")
plt.legend()
plt.grid()
plt.xlabel("# of evaluations")
plt.ylabel("log10( Objective value )")
plt.show()


mse_ref = np.array(ref_data["prec"])
mse_new = np.array(new_data["prec"])


power_ref = np.array(ref_data["cost"])
power_new = np.array(new_data["cost"])



mse_ref = np.log10(mse_ref)
mse_new = np.log10(mse_new)

plt.scatter(mse_ref, power_ref,label="reference")
plt.scatter(mse_new, power_new,label="new")

plt.legend()
plt.grid()
plt.xlabel("log10( MSE )")
plt.ylabel("Power")
plt.show()


# # plt.scatter([i for i in range(1, 101)], mse_ref,label="mse-mult")

# # plt.legend()
# # plt.grid()
# # plt.xlabel("ite")
# # plt.ylabel("value")
# # plt.show()


# # plt.scatter([i for i in range(1, 101)], power_ref,label="power-mult")
# # plt.legend()
# # plt.grid()
# # plt.xlabel("ite")
# # plt.ylabel("value")
# # plt.show()

# plt.scatter([i for i in range(1, 101)], mse_b1,label="mse-plus")

# plt.legend()
# plt.grid()
# plt.xlabel("ite")
# plt.ylabel("value")
# plt.show()


# plt.scatter([i for i in range(1, 101)], power_b1,label="power-plus")
# plt.legend()
# plt.grid()
# plt.xlabel("ite")
# plt.ylabel("value")
# plt.show()

# # plt.scatter(idx_ref,trend_ref,label="reference")
# # plt.scatter(idx_b1,trend_b1,label="batch-1")
# plt.scatter(idx_b2,trend_b2,label="batch-2")
# plt.legend()
# plt.grid()
# plt.xlabel("# of evaluations")
# plt.ylabel("Objective value")
# plt.show()

