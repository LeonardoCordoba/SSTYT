import socket
import datetime

port = 5000
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(("", port))
print('waiting on port:', port)

while 1:
    data, addr = s.recvfrom(1024)
    timestamp = datetime.datetime.now()
    with open(str(timestamp), "w+") as out_file:
        out_file.write(str(data))
