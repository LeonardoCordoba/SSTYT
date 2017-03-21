#2do paso - matriz OD
#Paso de matriz od completa a la matriz od por nivel de agregación

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
  host = "10.78.10.215",
  port = 5432,
  user = "postgres",
  password = pw
)


#Cargo las tablas

m_od_comp <- "matriz_od.a2016_05_4_m_od_comp"
  
m_od_comp_tbl <- dbGetQuery(con, paste("select * from ", m_od_comp, sep = ''))

mov_gps <- "matriz_od.a2016_05_4"

mov_gps_tbl <- dbGetQuery(con, paste("select codigo_contrato, modo, nro_viaje, etapa_viaje from ", mov_gps, sep = ''))

#Convierto los data frames a data tables

m_od_comp_tbl <- as.data.table(m_od_comp_tbl)

mov_gps_tbl <- as.data.table(mov_gps_tbl)

#Joineo

setkey(m_od_comp_tbl, nro_viaje_origen) 

setkey(mov_gps_tbl, nro_viaje)

test <- mov_gps_tbl[m_od_comp_tbl, nomatch = 0]

#Armo agrupamientos por columna
m_od_bus <- test[modo == "BUS",.(COUNT = .N), by = .(id_zona_origen, id_zona_destino)]
m_od_subte <- test[modo == "SUBTE",.(COUNT = .N), by = .(id_zona_origen, id_zona_destino)]
m_od_viajes <- test[etapa_viaje == 1,.(COUNT = .N), by = .(id_zona_origen, id_zona_destino)]
m_od_as <- test[codigo_contrato == 621,.(COUNT = .N), by = .(id_zona_origen, id_zona_destino)]
m_od_transbordo <- test[etapa_viaje == 2,.(COUNT = .N), by = .(id_zona_origen, id_zona_destino)]

#Junto todo
m_od <- m_od_viajes

setkey(m_od, id_zona_origen, id_zona_destino)
setkey(m_od_bus, id_zona_origen, id_zona_destino)
setkey(m_od_subte, id_zona_origen, id_zona_destino)
setkey(m_od_as, id_zona_origen, id_zona_destino)
setkey(m_od_transbordo, id_zona_origen, id_zona_destino)

m_od <- m_od_bus[m_od]
m_od <- m_od_subte[m_od]
m_od <- m_od_as[m_od]
m_od <- m_od_transbordo[m_od]

#Nombres de columnas
colnames(m_od) <- c("id_zona_origen","id_zona_destino","q_transbordo","q_as","q_subte","q_bus","q_viajes")

#Agrego columnas

m_od$q_trx <- 0
m_od$porc_as <- 0
m_od$porc_transbordo <- 0
m_od$porc_bus <- 0
m_od$porc_subte <- 0

#Reemplazo los NA

m_od[is.na(m_od)] <- 0

#Updateo
m_od <- m_od[, q_trx := q_bus + q_subte]
m_od <- m_od[,porc_as := round(q_as/q_trx*100, digits = 2)]
m_od <- m_od[,porc_transbordo := round(q_transbordo/q_viajes*100, digits = 2)]

#Expando
#calcular la cantidad de viajes originados por área en la población
origen_viajes <- test[etapa_viaje == 1, .(muestra_origen = .N), by = .(id_zona_origen)]
muestra <- m_od[,.(total_origen = sum(q_trx)), by = .(id_zona_origen)]

setkey(origen_viajes, id_zona_origen)
setkey(muestra, id_zona_origen)

setkey(m_od, id_zona_origen)

m_od <- origen_viajes[m_od]
m_od <- muestra[m_od]

#Columnas expandidas
m_od$q_trx_expand <- 0
m_od$q_subte_expand <- 0
m_od$q_bus_expand <- 0
m_od$q_transbordo_expand <- 0
m_od$q_viajes_expand <- 0

#Updateo
m_od <- m_od[,q_trx_expand := round(q_trx*total_origen/muestra_origen, digits = 1)]
m_od <- m_od[,q_subte_expand := round(q_subte*total_origen/muestra_origen, digits = 1)]
m_od <- m_od[,q_bus_expand := round(q_bus*total_origen/muestra_origen, digits = 1)]
m_od <- m_od[,q_transbordo_expand := round(q_transbordo*total_origen/muestra_originen, digits = 1)]
m_od <- m_od[,q_viajes_expand := round(q_viajes*total_origen/muestra_originen, digits = 1)]

#Guardo la tabla

m_od_final <- m_od[,c(1,4,15:19,5:12)]

write.csv(m_od_final, "/home/innovacion/m_od.csv", row.names = TRUE)

