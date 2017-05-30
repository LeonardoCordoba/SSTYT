                                                                                                      
import socket
import datetime
import re 

port = 5000
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(("", port))
print('waiting on port:', port)

# Loop para el escuchador
while 1:
    data, addr = s.recvfrom(1024)
    timestamp = datetime.datetime.now()
# Regex para las variables generales
    gps_id = re.findall("RIDD\d{7}", data)
    comando = re.findall("CMD\w{3}", data)
    iodig = re.findall("IOD\w{6}", data)
    lat = re.findall("\d{4}\.\d{4},S", data)
    lon = re.findall("\d{5}\.\d{4},W", data)
    vel = re.findall(",\d{1}\.\d{2}", data)
    rumbo = re.findall(",\d{3}\.\d{2}", data)
    fecha = re.findall("\d{6},,", data)
# Regex para separar la hora y la validez del mensaje 
    hora_val_pattern = re.compile("(GPS\$GPRMC\,\d{6}.\d{3},(A|V))")
    hora_val0 = re.search("((GPS\$GPRMC\,\d{6}.\d{3}),(A|V))", data)
    hora = hora_val0.group(2)
    val = hora_val0.group(3)
# Regex para variables eventuales
    log = re.findall("LOG", data)
    reset = re.findall("RST\d{4}", data)
    bat = re.findall("BTR\d{1,3},\d{1,4}",data)
# Genera los archivos con el string parseado    
    with open(str(timestamp), "w+") as out_file:
        out_file.write("data: " + str(data) + "\n id: " + str(gps_id) + "\n comando: " + str(comando) + "\n i/o digitales: " + str(iodig) + "\n hora: " +
            str(hora) + "\n validez: " +  str(val) + "\n latitud: " + str(lat) + "\n longitud: " + str(lon) + "\n velocidad: " + str(vel) + "\n rumbo: " + 
            str(rumbo) + "\n fecha: " + str(fecha) + "\n log: " + str(log) + "\n reset: " + str(reset) + "\n bateria: " + str(bat))

#Print de prueba para no generar archivos
   # print("data: " + str(data) + " id: " + str(gps_id) + " comando: " + str(comando) + " i/o digitales: " + str(iodig) + " hora: " + str(hora) + " validez: " +
   # str(val) + " latitud: " + str(lat) + " longitud: " + str(lon) + " velocidad: " + str(vel) + " rumbo: " + str(rumbo) + " fecha: " + str(fecha) )
   # print("log: " + str(log))
   # print("reset: " + str(reset))
   # print("bateria: " + str(bat))
    s.sendto("[SACK]",addr)

    


