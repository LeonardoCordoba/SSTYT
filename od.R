#1er paso - matriz OD
#Paso de tabla gps_mov a matriz OD completa


################## SETUP ################
rm(list = ls())
library(RPostgreSQL) #Para establecer la conexión
library(data.table)
library(dplyr)

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

## Tablas


gps_mov <- "mov_dw.a2016_05_4"

zonas <- "matriz_od.zonas"

###################### ETL pre-matriz ##################################

# Modifico la tabla base

# Creo columna 'mejor_geom'

query <- paste("ALTER TABLE ,", gps_mov, " ADD COLUMN mejor_geom public.geometry ;")

dbGetQuery(con, query)

##### Colectivos #####

# Actualizo valor de 'mejor_geom'

query <- paste("UPDATE ,", gps_mov, " SET mejor_geom = ST_SetSRID(st_makepoint(longitud_siguiente,latitud_siguiente),4326)
               where diferencia_tiempo_siguiente < diferencia_tiempo_anterior;", sep = '')

dbGetQuery(con, query)

query <- paste("UPDATE ,", gps_mov, " SET mejor_geom = ST_SetSRID(st_makepoint(longitud_anterior,latitud_anterior),4326)
               where diferencia_tiempo_anterior < diferencia_tiempo_siguiente;", sep = '')

dbGetQuery(con, query)

##### Subtes #####

query <- paste("UPDATE ,", gps_mov, " a SET mejor_geom = (select geom_wgs84 from informacion_geografica.subtes b where b.interno = a.interno)
               WHERE modo = 'SUBTE'", sep = '')

dbGetQuery(con, query)

##### Tarjeta passback ######

query <- paste("SELECT b.nro_tarjeta,b.secuencia_tarjeta INTO matriz_od.tarjeta_passback FROM ", gps_mov, " a INNER JOIN ", gps_mov, " b 
               ON a.nro_tarjeta = b.nro_tarjeta AND a.secuencia_tarjeta < b.secuencia_tarjeta AND datediff('second',a.fecha_trx,b.fecha_trx) < 10", sep = '')

dbGetQuery(con, query)

query <- paste("ALTER TABLE ", gps_mov, " ADD COLUMN tarjeta_passback bit",sep = '')

query <- paste("UPDATE ", gps_mov, " a set tarjeta_passback = 1 where EXISTS (select * from matriz_od.tarjeta_passback b 
               where a.nro_tarjeta = b.nro_tarjeta and a.secuencia_tarjeta = b.secuencia_tarjeta)", sep = '')

dbGetQuery(con, query)

query <- paste("DROP TABLE matriz_od.tarjeta_passback")

dbGetQuery(con, query)

### tipo_viajero #####

query <- paste("SELECT b.nro_tarjeta,count(distinct nro_viaje) as tipo_viajero INTO matriz_od.tipo_viajero 
               FROM ", gps_mov ," where tarjeta_passback is null GROUP BY b.nro_tarjeta; ", sep = '')

dbGetQuery(con, query)

query <- paste("update ", gps_mov ," a set tipo_viajero = (select b.tipo_viajero from matriz_od.tipo_viajero b where b.nro_tarjeta = a.nro_tarjeta)", sep = '')

dbGetQuery(con, query)

query <- paste("DROP TABLE matriz_od.tipo_viajero ")

dbGetQuery(con, query)

##### Zonificación #####

query <- paste("ALTER TABLE", gps_mov, " ADD COLUMN id_zona integer", sep = "")

dbGetQuery(con, query)

query <- paste("update ", gps_mov, " a set id_zona = (SELECT b.id from ", zonas, " b where a.mejor_geom && b.geom and st_distance(a.mejor_geom,b.geom) = 0 LIMIT 1)", sep = "")

dbGetQuery(con, query)

##### Si quiero puedo sacar las tarjetas que hacen movimientos fuera de la zonificación

query <- paste("select distinct nro_tarjeta INTO  matriz_od.tblinter_tarjetas_sin_zona from ", gps_mov , " where id_zona is null", sep = '')

dbGetQuery(con, query)

query <- paste("DELETE FROM ", gps_mov ," a where EXISTS(SELECT b.nro_tarjeta FROM matriz_od.tblinter_tarjetas_sin_zona b WHERE a.nro_tarjeta = b.nro_tarjeta)", sep = '')

dbGetQuery(con, query)

query <- paste("DROP TABLE matriz_od.tblinter_tarjetas_sin_zona",sep='')


################ MATRIZ OD ####################################################################################

## Armo tabla vacía

mov_od <- data.frame(id_zona_origen = as.numeric(character()),
                 id_zona_destino = as.numeric(character()), 
                 hora_inicio = as.Date(character()), 
                 nro_viaje_origen = as.numeric(character()),
                 nro_viaje_destino = as.numeric(character()),
                 stringsAsFactors=FALSE)

## Cargo la tabla

dt <- as.data.table
