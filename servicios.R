
rm(list=ls())
#install.packages("RODBC")
#install.packages("sqldf")
require("sqldf")
library(postGIStools)
library(RPostgreSQL)
pw <- {
  "postgres"
}

# loads the PostgreSQL driver
drv <- dbDriver("PostgreSQL")
# creates a connection to the postgres database
# note that "con" will be used later in each connection to the database
con <- dbConnect(
  drv,
  dbname = "sube",
  host = "10.78.14.54",
  port = 5432,
  user = "postgres",
  password = pw
)

#Parámetros
#Día
dia <- 3
#Tabla de análisis
schema <- "gps_dw"
tbl_name <- "a2016_05"
tbl <- paste(schema,".",tbl_name, sep = "")

#Esto lo hago para que sqldf no 'choque' con RPostgreSQL
options(sqldf.driver = "SQLite")

#Tabla donde se van a guardar los resultados

dbGetQuery(con,paste("CREATE TABLE gps_dw.",tbl_name,"_",dia,"
        (
        interno integer,
        id_ramal integer,
        file_id character varying,
        date_time timestamp without time zone,
        type character varying,
        direction character varying,
        longitud double precision,
        latitud double precision,
        velocity double precision,
        distance double precision,
        geom geometry(Point,4326),
        desc_linea character varying,
        desc_ramal character varying,
        id_linea integer,
        id bigint,
        d integer,
        h integer,
        id_servicio character varying,
        id_cabeceroide_asociado character varying,
        trip_direction character varying
        )
        WITH (
        OIDS=FALSE
        )",sep=""))

#Tabla de cabeceroides
#tbl_servicios <- paste("informacion_geografica.cabeceroide","_", tbl_name,"_",dia,"", sep ='')

#Construyo cabeceroides-> problemas con las líneas 61 y 62
###dbGetQuery(con,(paste("DROP TABLE informacion_geografica.cabeceroides ", sep = '')))
###dbGetQuery(con,(paste("CREATE TABLE informacion_geografica.cabeceroides AS (select row_number() over() as id, linea, ST_MinimumBoundingCircle(ST_COLLECT(geom4326_buffer)) as geom4326, trip_direction from informacion_geografica.cabeceras group by linea, trip_direction)", sep = '')))
###dbGetQuery(con,(paste("ALTER TABLE informacion_geografica.cabeceroides ADD COLUMN id_linea_sube integer", sep = ''))) 
###dbGetQuery(con,(paste("UPDATE informacion_geografica.cabeceroides a SET id_linea_sube =   (select id_linea from elr where desc_linea = 'LINEA ' || a.linea::character varying(10) LIMIT 1)", sep = ''))) 

#Cargo tabla con empresa, línea, ramal
elr <- dbGetQuery(con,"select * from elr")

#Rutas de USIG
rutas <- get_postgis_query(con,
                           "select *
                           from informacion_geografica.recorridos_bacomollego",
                           geom_name = 'trip_geom_wgs84')

# Líneas
lineas_tbl <-c(195,96,8,117,47)
  
  #unique(rutas$linea)

#Creo tabla de servicios
tbl_servicios <- paste("servicios.",tbl_name,"_",dia, sep = "")

dbGetQuery(con,paste("CREATE TABLE ", tbl_servicios, " (id_cabeceroide_origen integer, id_cabeceroide_destino integer, id bigserial NOT NULL) ", sep = ""))

#Actualizo valores de id_cabeceroide_asociado
dbGetQuery(con,paste("select a.*,b.id as id_cabeceroide_asociado, b.trip_direction
INTO gps_by_linea.cabeceroide_",tbl_name,"_",dia,"
from ",tbl," a LEFT JOIN informacion_geografica.cabeceroides b
ON a.id_linea = b.id_linea_sube and st_distance(a.geom,b.geom4326) <= 0
where a.latitud <> 0 AND date_part('day', date_time) =", dia,sep=""))

# Agrego columna con id de servicio
###dbGetQuery(con, paste("ALTER TABLE ", tbl, "ADD COLUMN id_servicio character varying"))

# Cargo los datos en el df

df <- dbGetQuery(con, paste("select * from gps_by_linea.cabeceroide_",tbl_name,"_",dia, sep = ""))

############## Obtengo el id_linea de sube para las líneas de usig
#  for (linea in lineas_tbl) {dbGetQuery(con,paste("update informacion_geografica.cabeceras a 
#        set id_linea_sube = (select id_linea from elr where desc_linea = ", "'LINEA ", linea,"'","::character varying(10) LIMIT 1) where linea = ",linea, sep = ''))
#  }


for (linea in lineas_tbl) {

#GPS de la línea
  tblGPS <- df[which(df$desc_linea == paste("LINEA ", linea, sep = '')),]

#GPS de los internos
  tblInternos <-unique(tblGPS$interno)

#Cabeceroide

cabeceroide <- dbGetQuery(con,paste("Select * from informacion_geografica.cabeceroides"))

#if ((linea %in% c(28,45, 79, 80, 103, 160, 174, 185, 61, 62))==FALSE) {
if ((linea %in% lineas_tbl)==TRUE) {
for (i in 1:length(tblInternos)){
  query2 <- paste('select * from tblGPS where interno = ', tblInternos[i],' ORDER BY date_time', sep = "")  
  tblGPS2 <- sqldf(query2)

  cabeceroideAnterior <- 0
  id_servicio <- 0
  
  for (j in 1:nrow(tblGPS2)){
    id_cabeceroide_asociado <- tblGPS2[j,"id_cabeceroide_asociado"]
    
    if(!is.null(id_cabeceroide_asociado))  {
      if(!is.na(id_cabeceroide_asociado))  {
        if (cabeceroideAnterior != id_cabeceroide_asociado) {
          # Incremento el número de servicio únicamente cuando paso por un cabeceroide que es distinta a la anterior Y tiene un sentido
          # diferente al cabeceroide anterior.
          oCabeceroideActual <- cabeceroide[cabeceroide$id==id_cabeceroide_asociado,]
          
          if (cabeceroideAnterior == 0){
            # Es el PRIMER SERVICIO DEL DÍA para el interno.
            id_servicio <- dbGetQuery(con,paste("insert into ", tbl_servicios, " values (", id_cabeceroide_asociado,
                                       ",NULL) RETURNING id;",sep=""))
            cabeceroideAnterior = id_cabeceroide_asociado
          } else {
            # Si no está en 0, la cabecera anterior existe siempre.
            ocabeceroideAnterior <- cabeceroide[cabeceroide$id==cabeceroideAnterior,]
            if (ocabeceroideAnterior["trip_direction"] != oCabeceroideActual["trip_direction"]) {
              #Caso en el que el sentido cambia.
              #Creo el nuevo servicio
              id_servicio <- dbGetQuery(con,paste("insert into ",tbl_servicios,  " values (", id_cabeceroide_asociado,
                                         ",NULL) RETURNING id;",sep=""))
              # Si NO ES EL PRIMER SERVICIO del día para el interno,
              # actualizo el servicio anterior con la cabecera actual como
              # la cabecera de destino
              id_servicio_anterior = id_servicio - 1
              dbGetQuery(con,paste("UPDATE ", tbl_servicios, " SET id_cabeceroide_destino = ", id_cabeceroide_asociado,
                          " WHERE id = ",id_servicio_anterior,sep = ""))
              
              #Actualizo la cabecera anterior
              cabeceroideAnterior = id_cabeceroide_asociado
              
            } #Fin las cabeceras tienen distintos sentidos
          }
          
        } # Fin del is null 
      } # Fin de  if cabeceroideAnterior != regGPS["id_cabeceroide_asociado"]
    } # Fin if(!is.na(regGPS["id_cabeceroide_asociado"]) )  

    # EN TODOS LOS CASOS: si el servicio no es 0 (son los primeros registros GPS y no se encuentran en ninguna cabecera)
    # Asigno el número de servicio actual a la tabla GPS y el trip_direction
    if(id_servicio != 0){tblGPS2[j,"id_servicio"] <- id_servicio
      if ((tblGPS2[j,"trip_direction"] %in% c("vuelta","ida")) == FALSE)
        {trip_direction <- tblGPS2[j-1,"trip_direction"]}
          else {trip_direction <- tblGPS2[j, "trip_direction"]}
              tblGPS2[j, "trip_direction"] <- trip_direction
    }
  } # FIn del FOR
  # Copio en alguna ubicación la tabla construida
  tblGPS2[is.na(tblGPS2)] <- ""
  write.csv(tblGPS2,paste("/home/innovacion/cabeceroide","_", tbl_name,"_",dia,".csv", sep = ""), row.names = FALSE)
  dbGetQuery(con,"CREATE TABLE gps_by_linea.tmp

        (
        interno integer,
        id_ramal integer,
        file_id character varying,
        date_time timestamp without time zone,
        type character varying,
        direction character varying,
        longitud double precision,
        latitud double precision,
        velocity double precision,
        distance double precision,
        geom geometry(Point,4326),
        desc_linea character varying,
        desc_ramal character varying,
        id_linea integer,
        id bigint,
        d integer,
        h integer,
        id_servicio character varying,
        id_cabeceroide_asociado character varying,
        trip_direction character varying
        )
        
        WITH (
        OIDS=FALSE
        );
        ")

dbGetQuery(con,paste("COPY gps_by_linea.tmp FROM '/home/innovacion/cabeceroide","_", tbl_name,"_",dia,".csv", "' WITH DELIMITER AS ',' CSV HEADER;", sep = "")) 

dbGetQuery(con,paste("INSERT INTO gps_dw.",tbl_name,"_",dia," SELECT 
                       interno, id_ramal, file_id, date_time, type, direction, longitud, latitud,   velocity,  distance,
                       geom , desc_linea, desc_ramal, id_linea, id, d, h, id_servicio, id_cabeceroide_asociado, trip_direction
                        FROM gps_by_linea.tmp", sep =""))

dbGetQuery(con,paste("DROP TABLE gps_by_linea.tmp;"))

} # FIn del FOR interno
# Drop de la tabla creada al incio
#  dbGetQuery(con,paste("update gps_by_linea.",tbl_name,"_",dia, "set id_servicio = null where id_servicio = '';
 #    update gps_by_linea.",tbl_name,"_",dia, " set id_cabeceroide_asociado = null where id_cabeceroide_asociado = '';",sep=""))
}}

dbGetQuery(con,paste("drop table gps_by_linea.cabeceroide_",tbl_name,"_",dia ,sep=""))

### Sobre la tabla creada agrego un id por vez que entra un interno a la cabecera

dbGetQuery(con, paste("CREATE TABLE gps_dw.",tbl_name,"_",dia,"_2
                      AS
                      SELECT *, row_number() OVER (PARTITION BY interno, id_servicio ORDER BY date_time) AS id_cab_serv
                      FROM gps_dw.",tbl_name,"_",dia,";
                      
                      --Elimino el datawarehouse original
                      DROP TABLE gps_dw.",tbl_name,"_",dia,";
                      -- Renombro la tabla ordenada por secuencia de tarjetas como la original
                      ALTER TABLE gps_dw.",tbl_name,"_",dia,"_2
                      RENAME TO ",tbl_name,"_",dia,"; ",sep=""))


### Mejoro los datos asignando la mitad de los gps dentro de los cabeceroide a ida y la mitad a vuelta

dbGetQuery(con,paste("update gps_dw.",tbl_name,"_",dia, " set id_servicio = null where id_servicio = ''", sep =""))

df <- dbGetQuery(con, paste("select * from gps_dw.",tbl_name,"_",dia, sep= ""))

for (linea in lineas_tbl) {
  
  #GPS de la línea
  tblGPS <- df[which(df$desc_linea == paste("LINEA ", linea, sep = '')),]
  
  #GPS de los internos
  tblInternos <-unique(tblGPS$interno)
  
  id_linea <- tblGPS[1, 'id_linea']

  #####  id_count <- dbGetQuery(con, paste("SELECT MAX(cast (id_servicio as integer)) from gps_dw.",tbl_name,"_",dia,"; ",sep=""))

for (i in 1:length(tblInternos)){

  query2 <- paste('select * from tblGPS where interno = ', tblInternos[i],' ORDER BY date_time', sep = "")
  tblGPS2 <- sqldf(query2)
  
  interno <- tblInternos[i]

  tblServicios <- as.data.frame(na.omit(as.integer(unique(tblGPS2$id_servicio))))
  
  tblServicios <- tblServicios[with(tblServicios, order(tblServicios)),]
  
  cantidad_serv <- length(tblServicios)
  
#Para cada servicio
for (j in tblServicios[-1]) {
  
  #Tomo los datos del servicio
  tblGPS3 <-tblGPS2[tblGPS2$id_servicio==j,]
  
  #Me quedo sólo con los que están dentro de un cabeceroide
  tblGPS3 <- tblGPS3[which(tblGPS3$id_cabeceroide_asociado != ''),]
  
  #Tomo el id del primer GPS del servicio
  id_inicial <- tblGPS3[1,'id']
  
  #Tomo la dirección de los GPS
  trip_direction <- tblGPS3[tblGPS3$id==id_inicial, "trip_direction"]
  
  #Armo la nueva trip_direction
  if (trip_direction == 'ida') {trip_direction_new = 'vuelta'} else {trip_direction_new = 'ida'}
  
  #Cuento cuántos datos GPS tengo dentro del cabeceroide
  count <- nrow(tblGPS3)
  
  #Calculo la mitad
  if ((round(count/2) == count/2)==TRUE){ mitad = count/2} else {mitad = (count+1)/2}
  
  #Traigo el id correspondiente al GPS de la mitad
  id_final <- tblGPS3[mitad,'id']
  
  #Actualizo los datos de la base de datos
  dbGetQuery(con, paste("update gps_dw.",tbl_name,"_",dia, " set trip_direction = ", paste("'",trip_direction_new,"'", sep = ''),
              ", id_servicio = ", paste("'",j-1,"'", sep='')  ,        " where id_linea = ", paste("'",id_linea,"'", sep = ''), "AND interno = ",interno," AND id >= ", id_inicial," AND id <= ",id_final, sep=''))

}
}
}

