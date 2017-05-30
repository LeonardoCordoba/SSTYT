sessionInfo()

#Script para joinear GPS a ramales
rm(list = ls())
library(RPostgreSQL) #Para establecer la conexión
library(sqldf) #Para hacer consultar sql a df
library(spatstat)
library(rgeos) #Para usar gDistance()
library(sp)
library(rgdal) #Para poder establecer proyecciones
library(postGIStools)
library(foreach)
library(doMC)
library(data.table)
#Primero establezco la conexión a la base sube en Postgresql

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

#Esto lo hago para que sqldf no 'choque' con RPostgreSQL
options(sqldf.driver = "SQLite")

#Importo rutas de USIG
rutas <- get_postgis_query(con,
                           "select *
                           from informacion_geografica.recorridos_bacomollego",
                           geom_name = 'trip_geom_wgs84')

#Cargo tabla con empresa, línea, ramal
elr <-
  dbGetQuery(con,
             "select * from elr")

#gps_test <-
#  get_postgis_query(
#    con,
#    "select * from gps_dw.a2016_05_01_linea_12 where latitud <> 0 and longitud <> 0",
#    geom_name = 'geom'
#  )
#summary(gps_test)

#Nombre de tablas

tbl_name <- "gps_dw.a2016_05_3"
tbl_servicios <- "servicios.a2016_05_3"
# Importo puntos GPS con servicio asociado



gps_query = paste("SELECT * FROM ",tbl_name," where latitud <> 0 and longitud <> 0")

gps = get_postgis_query(con, gps_query, geom_name = 'geom') 

#Agrego una columna con nulos, es la columna que me interesa completar

gps$id_trip_correccion <- NA

# Importo tabla de servicios

serv_query <- paste("SELECT * FROM ", tbl_servicios)

servicios <- dbGetQuery(con, serv_query)

# Importo tabla de cabeceras

cabec_query <- "SELECT * FROM informacion_geografica.cabeceroides"

cabeceras <-
  dbGetQuery(con, cabec_query)

#Mergeo tablas

serv_trip <-  merge(cabeceras, servicios, by.x = "id", by.y = "id_cabeceroide_origen")
serv_trip <- serv_trip[,c(4,7)]

#sqldf("select a.id, b.trip_direction from servicios a inner join cabeceras b on a.id_cabecera_origen = b.id")

#Si alguna coordenada se graba mal borro el dato gps
neg<-function(x) -x 
gps <- gps[which((round(gps$coords.x1) > neg(50))==FALSE),]
gps <- gps[which((round(gps$coords.x1) < neg(70))==FALSE),]
gps <- gps[which((round(gps$coords.x2) > neg(30))==FALSE),]
gps <- gps[which((round(gps$coords.x2) < neg(40))==FALSE),]


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

#Servicios

min_serv <- min(servicios$id)
max_serv <- max(servicios$id)

#Para los puntos GPS de cada servicio calculo la distancia a los ramales candidatos

#Para cada servicio
registerDoMC(40)
getDoParWorkers()


res <- foreach (i= min_serv:max_serv, .combine=rbind) %dopar% {
  
  serv <- i
  #Tomo todos los puntos GPS de un servicio y creo tablas chicas
  gps_servicio <- subset(gps, id_servicio == serv)
  #Ordeno la tabla
  gps_servicio <- gps_servicio[with(gps_servicio, order(gps_servicio$date_time)), ]
  
  if (nrow(gps_servicio) > 0) {
    
    #Tomo el sentido y línea
    
    trip_direction <-
      serv_trip[which(serv_trip$id == serv), "trip_direction"]
    
    id_linea <- unique(gps_servicio$id_linea)
    
#    linea <- subset(elr, id_linea == id_linea, select = desc_linea)
    linea <- elr[which(elr$id_linea == id_linea), "desc_linea"]
    
    linea <- gsub("[[:space:]]", "", linea)
    linea <- as.integer(gsub("[A-Z]", "", linea))
    linea <- unique(linea)
    
    #Ramales candidatos de la línea
    candidatos <-
      rutas[which(rutas$trip_direction == trip_direction &
                    rutas$linea == linea), ]

    #Si no hay candidatos no hago nada
    #Si hay un solo candidato asigno el trip_id del candidato a los gps que tienen ese número de servicio
    if (nrow(candidatos) == 1) {
      gps[which(gps$id_servicio == serv), 'trip_id'] <- candidatos$trip_id
      id_trip <- candidatos$trip_id
      id_trip_correccion <- ''
      id <- 0
    }
    #Si hay más de un candidato
    if (nrow(candidatos) > 1) {
      #Para cada punto de cada servicio
      
      for (punto in 1:nrow(gps_servicio)) {
        id <- as.data.frame(gps_servicio)[punto, 'id']
        #Calculo la distancia a los ramales candidatos
        dist <- gDistance(gps_servicio[punto, ], candidatos, byid = TRUE)
        #Si sólo uno está en la proximidad (20 metros) entonces lo agrego a la tabla gps_dist
        if (sum(apply(as.data.frame(dist), MARGIN = 2, function(x)
          x < 20)) == 1)
        {
          if (exists('gps_dist') == FALSE) {
            gps_dist <- as.data.frame(t(dist))
          } else {
            gps_dist <- rbind(gps_dist, t(dist))
          }
        }
        
      }
      
      if (exists('gps_dist') == TRUE) {
        #Calculo la distancia promedio a cada ramal en la tabla gps_dist
        avg_dist <- t(as.data.frame(colMeans(gps_dist)))
        
        #Traigo el id_trip del ramal al que está más cerca
        row_n <-
          as.integer(colnames(avg_dist)[apply(avg_dist, 1, which.min)])
        
        id_trip <- as.data.frame(rutas)[row_n, "trip_id"]
        id_trip_correccion <- ''
        #Agrego el id_trip a la tabla
        gps[which(gps$id_servicio == serv), 'id_trip'] <- id_trip
        
        #Borro gps_dist
        rm(gps_dist)
        
      }
      else {
        gps[which(gps$id_servicio == serv), 'id_trip'] <- "indeterminado"
        id_trip <- "indeterminado"
        #Calculo la distancia promedio a cada ramal en la tabla gps_dist
        
        dist <- gDistance(gps_servicio, candidatos, byid = TRUE)
        avg_dist <- t(as.data.frame(colMeans(t(dist))))
        
        #Traigo el id_trip del ramal al que está más cerca
        row_n <-as.integer(colnames(avg_dist)[apply(avg_dist, 1, which.min)])
        
        id_trip_correccion <- as.data.frame(rutas)[row_n, "trip_id"]
        
        #Agrego el id_trip a la tabla
        gps[which(gps$id_servicio == serv), 'id_trip_correccion'] <- id_trip_correccion
        
      }
    }
    return(c(id, id_trip, id_trip_correccion, serv))
      }
    }

colnames(res) <- c("id","id_trip","id_trip_correccion", "serv")

write.csv(res,paste("/home/innovacion/join_ramales.csv", sep = ""), row.names = FALSE)

## Actualizo la tabla gps
gps <- gps[,c('id','id_servicio')]

gps$id_trip <- NA
gps$id_trip_correccion <- NA

gps <- as.data.table(gps)
res <- as.data.table(res)

setkey(gps,id_servicio)
setkey(res,serv)

gps <- res[gps,nomatch=0]

gps <- gps[,c(2,3,4,5)]

colnames(gps) <- c('id_trip','id_trip_correccion', 'id_servicio', 'id')


##Calculo id_trip_final

gps$id_trip_final <- NA

gps1 <- gps[id_trip == 'indeterminado']
gps1$id_trip_final <- gps1$id_trip_correccion

gps2 <- gps[id_trip != 'indeterminado']
gps2$id_trip_final <- gps2$id_trip

gps <- rbind(gps1,gps2)

rm(gps1)
rm(gps2)

#Impacto en la base de datos - No paraleliza - Mejorar

rutas <- as.data.frame(rutas)

registerDoMC(20)

foreach (i= 1:nrow(gps), .inorder=FALSE, .packages=c("DBI", "RPostgreSQL")) %do% {
  id_trip_final <- gps[i,'id_trip_final']
  ramal <- rutas[which(rutas$trip_id == id_trip_final), "trip_ident"] 
  id <- gps[i, 'id']
  query <- paste("UPDATE ",tbl_name, " SET ramal2 = ", "'", ramal,"'", ", trip_id = '", id_trip, "'", " WHERE id = ", id, sep='')
  dbGetQuery(con, query)
}

