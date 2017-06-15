#1er paso - matriz OD
#Paso de tabla gps_mov a matriz OD completa

################## SETUP ################
rm(list = ls())
library(RPostgreSQL) #Para establecer la conexión
library(data.table) #Por performance
library(dplyr) #Para manipulación
library(foreach) #Para paralelizar
library(doMC) #Para paralelizar
library(spatstat)
library(rgeos) #Para usar gDistance()
library(sp)
library(rgdal) #Para poder establecer proyecciones
library(postGIStools) #Para traer la geometrías de las tablas en PostgreSQL a un formato que R interpreta
library(compiler) #Para compilar a nivel de byte

#registerDoMC(30)

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


gps_mov <- "matriz_od.a2016_05_4"

zonas <- "matriz_od.zonas"

################ MATRIZ OD ####################################################################################

## Cargo la tabla

query <-
  paste(
    "SELECT id, nro_tarjeta, nro_viaje, etapa_viaje, desc_linea, modo, codigo_contrato, tarjeta_passback, tipo_viajero,
    id_zona from
    ",
    gps_mov,
    sep = ''
  )

## data.table
dt_1 <- dbGetQuery(con, query)

dt_1 <- as.data.table(dt_1)

setkey(dt_1, nro_tarjeta, nro_viaje, etapa_viaje)

#Saco los passback
dt_1 <- dt_1 %>% filter(is.na(tarjeta_passback) == TRUE)

#Lista de tarjetas
tarjetas <- dt_1 %>% distinct(nro_tarjeta)
n_tarjetas <- nrow(tarjetas)
tarjetas <- tarjetas$nro_tarjeta
#Tarjetas con una sola trx
tarjeta_1_trx <- (dt_1 %>% group_by(nro_tarjeta) %>% summarise(n = n()) %>% filter(n == 1))$nro_tarjeta

dt_1$id_zona_destino_etapa <- NA
dt_1$id_zona_destino_viaje <- NA
dt_1$id_destino_etapa <- NA
dt_1$id_destino_viaje <- NA


tarj <- c()
dt_tarj <- c()
n_row <- c()
nro_viajes <- c()
nro_viajes_distintos <- c()

dt_1 <- as.data.table(dt_1)
setkey(dt_1, nro_tarjeta)


f <- function(i) {
  
  tarj <- tarjetas[i]
  
  dt_tarj <- dt_1[tarj,]
  
  nro_viaje_ls <- dt_tarj$nro_viaje
  
  etapa_viaje_ls <- dt_tarj$etapa_viaje
  
  zonas_ls <- dt_tarj$id_zona
  
  id_ls <- dt_tarj$id
  
  n_row <-  nrow(dt_tarj)
  
  nro_viajes_distintos <- n_distinct(nro_viaje_ls)
  
  max_nro_viaje <- max(nro_viajes)
  
  for (j in 1:n_row)  {
    
    nro_viaje <- nro_viaje_ls[j]
    
    etapa_viaje <- etapa_viaje_ls[j]
    
    id <- id_ls[j]
    
    origen <- zonas_ls[j]
    if (j > 1) {
      nro_viaje_anterior <- nro_viaje_ls[j - 1]
      etapa_viaje_anterior <- etapa_viaje_ls[j - 1]
      dt_tarj$id_zona_destino_etapa[j - 1] <- zonas_ls[j]
      dt_tarj$id_destino_etapa[j - 1] <- id
      
      if (j == n_row) {
        dt_tarj$id_zona_destino_etapa[j] <- zonas_ls[1]
        dt_tarj$id_zona_destino_etapa[j] <- id_ls[1]
      }
      
      if (nro_viajes_distintos > 1) {
        if (nro_viaje != nro_viaje_anterior)
        {
          dt_tarj$id_zona_destino_viaje[which(dt_tarj$nro_viaje == nro_viaje_anterior)] <-
            origen
          dt_tarj$id_destino_viaje[which(dt_tarj$nro_viaje == nro_viaje_anterior)] <-id
          
        }
        
        if (nro_viaje == max_nro_viaje) {
          dt_tarj$id_zona_destino_viaje[which(dt_tarj$nro_viaje == max_nro_viaje)] <- zonas_ls[1]
          dt_tarj$id_destino_viaje[which(dt_tarj$nro_viaje == max_nro_viaje)] <- id_ls[1]
        }
      }
    }
  }
  return (dt_tarj) 
  
}

## Preparo dataset
fc <- cmpfun(f)

dt_resultado <- NULL

for (i in seq(1:n_tarjetas)) {
  dt_resultado <- rbind(dt_resultado, fc(i))
  print(i)
}

write.csv(data.frame(dt_resultado, stringsAsFactors=FALSE), "/home/innovacion/dt_resultado.csv", sep = ";")

rm(dt_1)
rm(dt_tarj)

dt_tarj$id_zona_destino_viaje[which(dt_tarj$id_zona_destino_viaje == "NA")] <- NA

setkey(dt_tarj, id)

##Calculo distancia entre la línea que tomó y el destino
#No está optimizado


#Cargo tabla con empresa, línea, ramal
elr <- 
  dbGetQuery(con,
             "select * from elr")

#Cargo rutas
rutas <-
  get_postgis_query(
    con,
    "select * from informacion_geografica.recorridos_bacomollego_wgs84",
    geom_name = "geom"
  )


#Cargo tabla con zonas
zonas <-
  get_postgis_query(con, "select * from matriz_od.zonas",  geom_name = 'geom')

#Cargo tabla con id de gps_mov

gps <-   get_postgis_query(con, paste("select id, mejor_geom from ", gps_mov,sep=''),  geom_name = 'mejor_geom')

#Establezco la proyección original

proj4string(rutas) <-
  CRS("+init=epsg:4326 + proj=longlat+ellps=WGS84 +datum=WGS84 +no_defs+towgs84=0,0,0")

proj4string(gps) <-
  CRS("+init=epsg:4326 + proj=longlat+ellps=WGS84 +datum=WGS84 +no_defs+towgs84=0,0,0")

#Transformo a GK-BA

rutas <-
  spTransform(
    rutas,
    "+proj=tmerc +lat_0=-34.629269 +lon_0=-58.4633 +k=0.9999980000000001 +x_0=100000 +y_0=100000 +ellps=intl +units=m +no_defs "
  )

gps <-
  spTransform(
    gps,
    "+proj=tmerc +lat_0=-34.629269 +lon_0=-58.4633 +k=0.9999980000000001 +x_0=100000 +y_0=100000 +ellps=intl +units=m +no_defs "
  )

#Calculo la distancia entre la línea que se tomó y la línea donde se subió

id_tbl <- as.data.table(dt_1 %>% distinct(id))

dt_tarj_final <- foreach(i = 1:nrow(dt_tarj), .combine = rbind) %dopar% {
  
  modo <- dt_tarj[i, modo]
  
  if (modo == "BUS")
  {
    id <- dt_tarj[i, id]
    id_destino_viaje_dt <- dt_tarj[i, id_destino_viaje]
    id_destino_etapa_dt <- dt_tarj[i, id_destino_etapa]
    
    destino_etapa <- gps[which(id == id_destino_etapa_dt),]
    destino_viaje <- gps[which(id == id_destino_viaje_dt),]
    
    linea <- dt_tarj[i, desc_linea]
    linea <- gsub("[[:space:]]", "", linea)
    linea <- as.integer(gsub("[A-Z]", "", linea))
    
    
    #Ramales candidatos de la línea
    ruta <-  rutas[which(rutas$linea == linea), ]
    
    dist <- gDistance(destino_etapa, ruta, byid = TRUE)
    
    #Esto es horrible pero funciona
    dist <- as.data.frame(t(dist))
    dist <- min(colnames(dist))
    
    dt_tarj$distancia[which(dt_tarj$id == id)] <- dist
    
    rm(dist)
  }
  return(dt_tarj[i])
  
}

###################### ETL pre-matriz ##################################

# Modifico la tabla base

# Creo columna 'mejor_geom'

query <-
  paste("ALTER TABLE ,",
        gps_mov,
        " ADD COLUMN mejor_geom public.geometry ;")

dbGetQuery(con, query)

##### Colectivos #####

# Actualizo valor de 'mejor_geom'

query <-
  paste(
    "UPDATE ,",
    gps_mov,
    " SET mejor_geom = ST_SetSRID(st_makepoint(longitud_siguiente,latitud_siguiente),4326)
    where diferencia_tiempo_siguiente < diferencia_tiempo_anterior;",
    sep = ''
  )

dbGetQuery(con, query)

query <-
  paste(
    "UPDATE ,",
    gps_mov,
    " SET mejor_geom = ST_SetSRID(st_makepoint(longitud_anterior,latitud_anterior),4326)
    where diferencia_tiempo_anterior < diferencia_tiempo_siguiente;",
    sep = ''
  )

dbGetQuery(con, query)

##### Subtes #####

query <-
  paste(
    "UPDATE ,",
    gps_mov,
    " a SET mejor_geom = (select geom_wgs84 from informacion_geografica.subtes b where b.interno = a.interno)
    WHERE modo = 'SUBTE'",
    sep = ''
  )

dbGetQuery(con, query)

##### Tarjeta passback ######

query <-
  paste(
    "SELECT b.nro_tarjeta,b.secuencia_tarjeta INTO matriz_od.tarjeta_passback FROM ",
    gps_mov,
    " a INNER JOIN ",
    gps_mov,
    " b
    ON a.nro_tarjeta = b.nro_tarjeta AND a.secuencia_tarjeta < b.secuencia_tarjeta AND datediff('second',a.fecha_trx,b.fecha_trx) < 10",
    sep = ''
  )

dbGetQuery(con, query)

query <-
  paste("ALTER TABLE ", gps_mov, " ADD COLUMN tarjeta_passback bit", sep = '')

query <-
  paste(
    "UPDATE ",
    gps_mov,
    " a set tarjeta_passback = 1 where EXISTS (select * from matriz_od.tarjeta_passback b
    where a.nro_tarjeta = b.nro_tarjeta and a.secuencia_tarjeta = b.secuencia_tarjeta)",
    sep = ''
    )

dbGetQuery(con, query)

query <- paste("DROP TABLE matriz_od.tarjeta_passback")

dbGetQuery(con, query)

### tipo_viajero #####

query <-
  paste(
    "SELECT b.nro_tarjeta,count(distinct nro_viaje) as tipo_viajero INTO matriz_od.tipo_viajero
    FROM ",
    gps_mov ,
    " where tarjeta_passback is null GROUP BY b.nro_tarjeta; ",
    sep = ''
  )

dbGetQuery(con, query)

query <-
  paste(
    "update ",
    gps_mov ,
    " a set tipo_viajero = (select b.tipo_viajero from matriz_od.tipo_viajero b where b.nro_tarjeta = a.nro_tarjeta)",
    sep = ''
  )

dbGetQuery(con, query)

query <- paste("DROP TABLE matriz_od.tipo_viajero ")

dbGetQuery(con, query)

##### Zonificación #####

query <-
  paste("ALTER TABLE", gps_mov, " ADD COLUMN id_zona integer", sep = "")

dbGetQuery(con, query)

query <-
  paste(
    "update ",
    gps_mov,
    " a set id_zona = (SELECT b.id from ",
    zonas,
    " b where a.mejor_geom && b.geom and st_distance(a.mejor_geom,b.geom) = 0 LIMIT 1)",
    sep = ""
  )

dbGetQuery(con, query)

##### Si quiero puedo sacar las tarjetas que hacen movimientos fuera de la zonificación

query <-
  paste(
    "select distinct nro_tarjeta INTO  matriz_od.tblinter_tarjetas_sin_zona from ",
    gps_mov ,
    " where id_zona is null",
    sep = ''
  )

dbGetQuery(con, query)

query <-
  paste(
    "DELETE FROM ",
    gps_mov ,
    " a where EXISTS(SELECT b.nro_tarjeta FROM matriz_od.tblinter_tarjetas_sin_zona b WHERE a.nro_tarjeta = b.nro_tarjeta)",
    sep = ''
  )

dbGetQuery(con, query)

query <-
  paste("DROP TABLE matriz_od.tblinter_tarjetas_sin_zona", sep = '')

