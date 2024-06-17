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


with open("./reference/result/ref-100.json", 'r') as file:
    ref_data = json.load(file)
with open("./hyperbrid/result/batch1-100.json", 'r') as file:
    b1_data = json.load(file)
with open("./hyperbrid/result/batch2-100re.json", 'r') as file:
    b2_data = json.load(file)



trend_ref, idx_ref = lower_trend(ref_data["loss"])
trend_b1, idx_b1 = lower_trend(b1_data["loss"])
trend_b2, idx_b2 = lower_trend(b2_data["loss"])

plt.plot(idx_ref,trend_ref,'b^--',label="reference")
plt.plot(idx_b1,trend_b1,'ro--',label="batch-1")
plt.plot(idx_b2,trend_b2,'gx--',label="batch-2")
plt.legend()
plt.grid()
plt.xlabel("# of evaluations")
plt.ylabel("log10( Objective value )")
plt.show()


mse_ref = np.array(ref_data["mse"])
mse_b1 = np.array(b1_data["mse"])
mse_b2 = np.array(b2_data["mse"])

power_ref = np.array(ref_data["power"])
power_b1 = np.array(b1_data["power"])
power_b2 = np.array(b2_data["power"])


mse_ref = np.log10(mse_ref)
mse_b1 = np.log10(mse_b1)
mse_b2 = np.log10(mse_b2)

plt.scatter(mse_ref, power_ref,label="reference")
plt.scatter(mse_b1, power_b1,label="batch-1")
plt.scatter(mse_b2, power_b2,label="batch-2")
plt.legend()
plt.grid()
plt.xlabel("log10( MSE )")
plt.ylabel("Power")
plt.show()

# plt.scatter(idx_ref,trend_ref,label="reference")
# plt.scatter(idx_b1,trend_b1,label="batch-1")
# plt.scatter(idx_b2,trend_b2,label="batch-2")
# plt.legend()
# plt.grid()
# plt.xlabel("# of evaluations")
# plt.ylabel("Objective value")
# plt.show()

