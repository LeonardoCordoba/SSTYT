############### Script para calcular las paradas de AMBA con la SUBE #################
#rm(list= ls())

## Obtener paradas de AMBA
library(RPostgreSQL)
library(dbscan)
library(dplyr)

### BD
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


######### Cargo datos ##############
data <- dbGetQuery(con, "select desc_linea, latitud_anterior, longitud_anterior, categoria_orientacion, prov, depto from paradas.a2016_05_1_15")


######## Generación de paradas de colectivo #############

set.seed(2001)

lineas <- data %>% distinct(desc_linea)

prov <- data %>% distinct(prov)

depto <- data %>% distinct(depto)

paradas <- NA
orientacion <- c('N','S','E','O')

for (i in 1:nrow(prov))
{
  provincia <- prov[i,]
  df_prov <- data[data$prov == provincia,]
  
  for (j in 1:nrow(depto))
  {
    departamento <- depto[j,]
    df_depto <- df_prov[df_prov$depto == departamento,]
    
    for (k in 1:nrow(lineas))
    {
      linea <- lineas[k,]
      df_linea <- df_depto[df_depto$desc_linea == linea,]
      df_linea <- na.omit(df_linea)
      
      for (h in orientacion)
      {
        df_linea_orientacion <- filter(df_linea, categoria_orientacion == h)
        
        if (nrow(df_linea_orientacion) > 4)
        {
          knn <- as.data.frame(kNNdist(df_linea_orientacion[, c(2, 3)], k = 4))
          knn$total = knn$`1` + knn$`2` + knn$`3` + knn$`4`
          Eps <- quantile(knn$total, 0.95)
          dbscan_obj <-
            dbscan(df_linea_orientacion[, c(2, 3)],
                   eps = Eps,
                   minPts = 4)
          df_linea_orientacion$grupos <- dbscan_obj$cluster
          tbl <-
            df_linea_orientacion %>% filter(grupos != 0) %>% group_by(grupos) %>% summarise(
              long = mean(longitud_anterior),
              lat = mean(latitud_anterior),
              n = n()
            )
          tbl$linea <- linea
          tbl$orientacion <- h
          tbl$depto <- departamento
          tbl$prov <- provincia
          paradas <- rbind(paradas, tbl)
        }
      }
    }
    
  }
}

############ Limpieza de paradas #################
library(spatstat)
library(rgeos) #Para usar gDistance()
library(sp)
library(rgdal) #Para poder establecer proyecciones

paradas <- paradas[-1,]

spdf <- SpatialPointsDataFrame(coords = paradas[,c(2,3)], data = paradas,
                               proj4string = CRS("+init=epsg:4326 + proj=longlat+ellps=WGS84 +datum=WGS84 +no_defs+towgs84=0,0,0"))
spdf <-
  spTransform(
    spdf,
    "+proj=tmerc +lat_0=-34.629269 +lon_0=-58.4633 +k=0.9999980000000001 +x_0=100000 +y_0=100000 +ellps=intl +units=m +no_defs "
  )

paradas_limpias <- NA

i = 1
j = 'O'


for (i in 1:nrow(lineas))
{
  for (j in orientacion)
    
  {
    paradas_candidatas <-
      spdf[spdf$linea == lineas[i, ] & spdf$orientacion ==  j, ]
    paradas_candidatas <-
      paradas_candidatas[with(paradas_candidatas, order(-paradas_candidatas$n)),]
    
    rows <- nrow(paradas_candidatas)
    eliminadas <- c(0)
    
    if (rows > 0)
    {
      for (k in 1:(rows - 1)) {
        for (l in (k + 1):rows)
        {
          if (gDistance(paradas_candidatas[k, ], paradas_candidatas[l, ]) < 150)
          {
            if (!(as.data.frame(paradas_candidatas)[k, "grupos"] %in% eliminadas))
            {
              eliminadas <- rbind(grupo, as.data.frame(paradas_candidatas[l, 'grupos']))
            }
          }
        }
      }
  
          paradas_filtradas <-
        paradas_candidatas[!(paradas_candidatas$grupos %in% eliminadas),]
      
      paradas_limpias <-
        rbind(paradas_limpias, as.data.frame(paradas_filtradas))
  
    }
  }
}

#### Apéndice ETL

#create table paradas.a2016_05_1_15
#as
#select *
#  from gps_mov.a2016_05
#where d >= 1 and d <= 15 and diferencia_tiempo_anterior <= 10;

#alter table paradas.a2016_05_1_15
#rename column grados_azimuth to orientacion

#alter table paradas.a2016_05_1_15
#add column categoria_orientacion character varying;


#update paradas.a2016_05_1_15
#set 
#orientacion = degrees(st_azimuth(geom_ant, geom_sig)),
#categoria_orientacion = CASE 
#WHEN degrees(st_azimuth(geom_ant, geom_sig)) < 45 or degrees(st_azimuth(geom_ant, geom_sig)) >= 315 THEN 'N'
#WHEN degrees(st_azimuth(geom_ant, geom_sig)) >= 45 and degrees(st_azimuth(geom_ant, geom_sig)) < 135 THEN 'E'
#WHEN degrees(st_azimuth(geom_ant, geom_sig)) >= 135 and degrees(st_azimuth(geom_ant, geom_sig)) < 225 THEN 'S'
#WHEN degrees(st_azimuth(geom_ant, geom_sig)) >= 225 and degrees(st_azimuth(geom_ant, geom_sig)) < 315 THEN 'O'
#END;

#select count(1) from paradas.a2016_05_1_15 where orientacion is null
#--177960

#select count(1) from paradas.a2016_05_1_15
#--7198650

#delete from paradas.a2016_05_1_15
#where orientacion is null

#create table paradas.a2016_05_1_15_2
#as
#select a.*, b.prov, b.depto
#from paradas.a2016_05_1_15 a, informacion_geografica.censo_2010 b
#where a.geom_ant&&b.geom and st_distance(a.geom_ant, b.geom) = 0

#drop table paradas.a2016_05_1_15

#alter table paradas.a2016_05_1_15_2
#rename to a2016_05_1_15
