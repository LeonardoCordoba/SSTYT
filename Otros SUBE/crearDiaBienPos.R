library(RPostgreSQL)
require("sqldf")

mydb <- dbConnect(drv = PostgreSQL(), user = "postgres", dbname = "sube", host = "localhost",  password = "postgres",port = "5432")

dia <- '17'

sql <- paste(
"SELECT * INTO gps_mov.a2016_05_",dia,"_bien_pos  FROM gps_mov.a2016_05_",dia," 
WHERE diferencia_tiempo_anterior <= diferencia_tiempo_siguiente AND
diferencia_tiempo_anterior < 10;

INSERT INTO gps_mov.a2016_05_",dia,"_bien_pos 
SELECT * FROM gps_mov.a2016_05_",dia," 
WHERE diferencia_tiempo_siguiente < diferencia_tiempo_anterior AND diferencia_tiempo_siguiente < 10;
",sep='')

dbGetQuery(mydb,sql)

sql <- paste("UPDATE gps_mov.a2016_05_",dia,"_bien_pos SET orientacion_grados = 
degrees(ST_Azimuth(geom_ant,geom_sig));

UPDATE gps_mov.a2016_05_",dia,"_bien_pos SET orientacion_categoria = 
CASE
WHEN orientacion_grados > 315 or orientacion_grados <=45 THEN 'N'
WHEN orientacion_grados > 45 and orientacion_grados <=135 THEN 'E'
WHEN orientacion_grados > 135 and orientacion_grados <=225 THEN 'S'
WHEN orientacion_grados > 225 and orientacion_grados <=315 THEN 'O'
END;",sep='')

dbGetQuery(mydb,sql)
