#install.packages("RODBC")
#install.packages("sqldf")
require("sqldf")

options(sqldf.RPostgreSQL.user ="postgres", 
        sqldf.RPostgreSQL.password ="postgres",
        sqldf.RPostgreSQL.dbname ="sube",
        sqldf.RPostgreSQL.host ="localhost", 
        sqldf.RPostgreSQL.port =5432)


install.packages("fpc")
install.packages("dbscan")
install.packages("ggmap")
require("fpc")
require("dbscan")
require("ggmap")

#Tomo los movimientos bien posicionados.
tblMovGpsOK <- sqldf("SELECT id,latitud_anterior,longitud_anterior FROM gps_mov.a2016_05_full WHERE d = 3 and diferencia_tiempo_anterior < 20 and latitud_anterior <> 0",drv="PostgreSQL")

#Tomo una muestra
set.seed(989898)
#tbl_sample <- tblMovGpsOK[sample(nrow(tblMovGpsOK), 1000000), ]
tbl_sample <- tblMovGpsOK

df <- tbl_sample[, 2:3]
#db <- dbscan(df, 0.000904, minPts = 10)
db <- dbscan(df, 0.001000, minPts = 75, borderPoints = T)

#plot(df, col=db$cluster)
df$cluster <- db$cluster
#View(df)

representacion_map <- sqldf("SELECT cluster,AVG(latitud_anterior) as lat,AVG(longitud_anterior) as long,count(1) as cantidad FROM df WHERE cluster <> 0 GROUP BY cluster",drv="SQLite")

#View(representacion_map)

#library("ggmap")

# ZONA SUR: 
map <- get_googlemap(center=as.numeric(geocode("Pilar")),
               scale=2,zoom=12)
p <- ggmap(map) +
  geom_point(data = representacion_map, aes(x = long, y = lat, size=cantidad),
             colour = "darkgreen") +
  theme_bw()
print(p)


#index <- duplicated(representacion_map_final[,c("lat","long")])
#representacion_map_final <- representacion_map_final[index == FALSE,]
write.csv(representacion_map,file = "ascensos_001_75.csv" ,row.names = FALSE, dec = ".")

# ZONA NORTE:



# ZONA OESTE:


p <- ggmap(map) +
  geom_point(data = tblMovGpsOK, aes(x = longitud_anterior, y = latitud_anterior),
             colour = "darkgreen") +
  theme_bw()

#CENTRO: 




