## Análisis de Matriz OD
rm(list=ls())


library(RPostgreSQL) #Para establecer la conexión
library(spatstat)
library(sp)
library(rgdal) #Para poder establecer proyecciones
library(postGIStools)
library(ggmap)
library(geomnet)

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



matriz_od_zona <- dbGetQuery(con, "select * from matriz_od.a2016_05_04_etapas")

zonificacion <- get_postgis_query(con, "select * from matriz_od.zonas", geom_name = 'centroid' )
zonificacion_mtb <- get_postgis_query(con, "select * from informacion_geografica.zonificacion_para_mtb_transversal", geom_name = 'centroid' )

zonificacion$long <- coordinates(zonificacion)[,1]
zonificacion$lat <- coordinates(zonificacion)[,2]

zonificacion <- as.data.frame(zonificacion)

zonificacion_mtb$long <- coordinates(zonificacion_mtb)[,1]
zonificacion_mtb$lat <- coordinates(zonificacion_mtb)[,2]

zonificacion_mtb <- as.data.frame(zonificacion_mtb)

zona <- unique(zonificacion$id)
zona_mtb <- unique(zonificacion_mtb$id)

matriz_od_zona <- matriz_od_zona[which(matriz_od_zona$id_zona %in% zona_mtb) | (matriz_od_zona$id_zona_destino_etapa %in% zona_mtb), ]


matriz_od_zona_grafo <- NA
matriz_od_zona_grafo <- rbind(matriz_od_zona_grafo, matriz_od_zona[matriz_od_zona$id_zona %in% zona_mtb & matriz_od_zona$id_zona_destino_etapa %in% zona,])
matriz_od_zona_grafo <- rbind(matriz_od_zona_grafo, matriz_od_zona[matriz_od_zona$id_zona_destino_etapa %in% zona_mtb & matriz_od_zona$id_zona %in% zona,])



tripnet <- fortify(as.edgedf(matriz_od_zona_grafo[matriz_od_zona_grafo$q_trx > 100,c(2,3,4,8)]), zonificacion[,c(1,16,15)])

quantile(tripnet$q_trx, na.rm =TRUE)


map <- get_map(location = c("Balvanera, CABA, Argentina"), zoom = 12)

map <- get_map(location = c("long" = -58.416212, "lat" = -34.631330), zoom = 12, maptype = 'terrain')

ggmap(map) + geom_net(
  data = tripnet,
  layout.alg = NULL,
  singletons = FALSE,
  labelon = FALSE,
  vjust = -0.5,
  ealpha = 0.5,
  aes(
    from_id = from_id,
    to_id = to_id,
    x = long ,
    y =  lat,
    linewidth = q_trx/1000)
) + scale_color_brewer() +  theme_net() %+replace% theme(aspect.ratio =NULL, legend.position = "bottom") +  coord_map()

