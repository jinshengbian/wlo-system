import paramiko
import paramiko.client
import getpass
import time

host = "knuffodrag.ita.chalmers.se"
username = "bianj"
password = "BJS1998@Chalmers"
#password = getpass.getpass("Password:  ")

# def remote_BER(configs:np.array):
#     global ssh_cli
#     global num_ite,x,y
#     BER = np.zeros((len(configs),1),dtype=float)
#     for i in range(len(configs)):
        
#         command = "python3 test.py ttyUSB4 " + " ".join(map(str,configs[i].astype(int)))
#         # print(command)
#         _stdin, _stdout,_stderr = ssh_cli.exec_command(command)
#         # BER[i] = float(_stdout.read().decode()) * 1000 + np.sum(configs[i],dtype=float)
#         BER[i] = float(_stdout.read().decode())


#         num_ite += 1
#         x = np.append(x,num_ite)
#         y = np.append(y,BER[i])
#     if num_ite % 20 == 0: print(num_ite) 

#     ber = BER.tolist()
#     print(ber)

#     return BER
def send_command(channel,command,method=1):
    channel.send(command + "\n")
    if method == 1:
        while not channel.recv_ready():
            time.sleep(1)
        
        output = ""
        while channel.recv_ready():
            output += channel.recv(999999).decode('utf-8')
    elif method == 2:
        output = ""
        while 1:
            while not channel.recv_ready():
                time.sleep(1)
            while channel.recv_ready():
                output += channel.recv(999999).decode('utf-8')
            if "@genus:root:" in output:
                break
    return output

if __name__ == "__main__":
   

    global ssh_cli 
    # global channel
    ssh_cli = paramiko.client.SSHClient()
    ssh_cli.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh_cli.connect(host, username=username, password=password)

    channel= ssh_cli.invoke_shell()


    command = "cd Downloads/quad && ls"
    output = send_command(channel,command)

    command = "source setup.sh"
    output = send_command(channel,command)

    command = "cd reference/tcl"
    output = send_command(channel,command)


    command = "source ./run.sh 5 5 6"
    output = send_command(channel,command)


    command = "genus"
    output = send_command(channel,command,2)

    # command = "source syn.tcl"
    # output = send_command(channel,command,2)

    command = "shell cat ../rpt/power.rpt"
    output = send_command(channel,command,2)

    lines = output.split('\n')
    result = lines[19].split()[4]
    print(result)