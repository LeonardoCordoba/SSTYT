                                                                                                      
import socket
import datetime
import re 

port = 5000
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(("", port))
print('waiting on port:', port)

while 1:
    data, addr = s.recvfrom(1024)
    timestamp = datetime.datetime.now()
    gps_id = re.findall("RIDD\d{7}", data)[0]
    comando = re.findall("CMD\w{3}", data)[0]
    iodig = re.findall("IOD\w{6}", data)[0]
    hora_val_pattern = re.compile("(GPS\$GPRMC\,\d{6}.\d{3},(A|V))")
    hora_val0 = re.search("((GPS\$GPRMC\,\d{6}.\d{3}),(A|V))", data)
    hora = hora_val0.group(2)
    val = hora_val0.group(3)
    lat = re.findall("\d{4}\.\d{4},S", data)[0]
    lon = re.findall("\d{5}\.\d{4},W", data)[0]
    vel = re.findall(",\d{1}\.\d{2}", data)[0]
    rumbo = re.findall(",\d{3}\.\d{2}", data)[0]
    fecha = re.findall("\d{6},,", data)[0]
   # with open(str(timestamp), "w+") as out_file:
   # out_file.write((str(data) + gps_id))
    print("data: " + str(data) + " id: " + str(gps_id) + " comando: " + str(comando) + " i/o digitales: " + str(iodig) + " hora: " + str(hora) + " validez: " +
    str(val) + " latitud: " + str(lat) + " longitud: " + str(lon) + " velocidad: " + str(vel) + " rumbo: " + str(rumbo) + " fecha: " + str(fecha))
 



