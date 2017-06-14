# Manual de liquidación e informe

## Acceso a los datos
Los datos se encuentran en una plataforma del Ministerio de Transporte de Nación.
El acceso se hace por: https://is.transporte.gob.ar/panel

En esta plataforma están los siguientes archivos:
  * Los usos del mes por Boleto Estudiantil
  * Los rezagos del mes por Boleto Estudiantil
  * La tabla de empresa-línea-ramal actualizada
  
Recomendamos leer brevemente los archivos en un bloc de notas (gedit) para chequear que no haya filas en blanco (suele haberlas y esto impide la ejecución de los scripts)

## Creación tabla mensual de usos
### Creación de la tabla mensual (PostgreSQL)

CREATE TABLE boleto_estudiantil.liquidacion_año_mes(
  id_empresa integer,
  id_linea integer,
  nro_interno integer,
  nro_ramal integer,
  contrato integer,
  periodo character varying,
  tarifa double precision,
  descuento double precision,
  cantidad_usos integer,
  total_descuento double precision)

### Carga al server de la base de datos de la operatoria mensual (terminal)

sudo scp file_path/nombre_archivo.csv innovacion@10.78.14.54:/home/innovacion

### Carga de datos a la tabla (Postgres)

COPY boleto_estudiantil.liquidacion_año_mes FROM '/home/innovacion/nombre_archivo' DELIMITER ';' CSV HEADER;

### Modificaciones de la tabla

Creación de la columna mes de liquidación (Postgres)

ALTER TABLE boleto_estudiantil.liquidacion_año_mes ADD COLUMN mes_liqui integer

UPDATE boleto_estudiantil.liquidacion_año_mes (Postgres) SET mes_liqui = mm WHERE periodo = 'mmyyyy'

Creación columna año de liquidación (Postgres)

ALTER TABLE boleto_estudiantil.liquidacion_año_mes ADD COLUMN ano_liqui integer

UPDATE boleto_estudiantil.liquidacion_año_mes SET ano_liqui = yyyy WHERE periodo = 'mmyyyy'

## Creación tabla mensual rezagos
### Creación de la tabla mensual de rezagos (PostgreSQL)

CREATE TABLE boleto_estudiantil.liquidacion_año_mes_rezagos( 
  id_empresa integer,
  id_linea integer,
  nro_interno integer,
  nro_ramal integer,
  contrato integer,
  periodo character varying,
  tarifa double precision,
  descuento double precision,
  cantidad_usos integer,
  total_descuento double precision)

### Carga al server de la base de datos de los rezagos (terminal)

sudo scp file_path/nombre_archivo.csv innovacion@10.78.14.54:/home/innovacion
Carga de datos a la tabla (Postgres)

### Carga de datos a la tabla (Postgres)

COPY boleto_estudiantil.liquidacion_año_mes_rezagos FROM '/home/innovacion/nombre_archivo.csv' DELIMITER ';' CSV HEADER;

### Modificaciones de la tabla

ALTER TABLE boleto_estudiantil.liquidacion_año_mes_rezagos ADD COLUMN mes_liqui integer

UPDATE boleto_estudiantil.liquidacion_año_mes_rezagos SET mes_liqui = mm WHERE periodo = 'mmyyyy'

ALTER TABLE boleto_estudiantil.liquidacion_año_mes_rezagos ADD COLUMN ano_liqui integer

UPDATE boleto_estudiantil.liquidacion_año_mes_rezagos SET ano_liqui = yyyy WHERE periodo = 'mmyyyy'

## Creación tabla mensual de empresa-linea-ramal (ELR)

### Creación de la tabla ELR (Postgres)
CREATE TABLE tablas_complementarias.elr_año_mes (
id_empresa integer,
desc_empresa character varying,
cuit bigint,
id_linea integer,
desc_linea character varying,
id_ramal integer,
ramal_corto character varying,
desc_ramal character varying)
 
### Carga al server de la base de datos de los rezagos (terminal)
sudo scp file_path/nombre_archivo.csv innovacion@10.78.14.54:/home/innovacion
 
### Carga de datos a la tabla (Postgres) 
COPY tablas_complementarias.elr_año_mes FROM '/home/innovacion/nombre_archivo.csv' DELIMITER ';' CSV HEADER;
 
### Modificaciones a la tabla
-- Creación de la columna modo
ALTER TABLE tablas_complementarias.elr_2017_05
ADD COLUMN modo varchar(100);
 
-- Seteo BUS en la columna modo
UPDATE tablas_complementarias.elr_2017_05
SET modo = 'BUS'
WHERE id_empresa <> 1
 
-- Agrega las filas correspondientes a subte (no vienen en el archivo original)
INSERT INTO tablas_complementarias.elr_2017_mes-actual
SELECT * FROM tablas_complementarias.elr_a2017_mes-pasado where id_empresa = 1

## Ejecución de los scripts de liquidación de R

### Liquidación para colectivos

Se deben declarar los nombres de las tablas creadas previamente:

be_nssa <- "boleto_estudiantil.liquidacion_yyyy_mm"

elr <- "tablas_complementarias.elr_yyyy_mm"

Ejecutarlo

### Liquidación de subtes

Resta definir en el convenio de pagos la forma en la cual se va a liquidar. Restará programarlo sobre el script base que está subido en el repositorio

### Envío a Educación

Educación es quien ejecuta el presupuesto para el envío de los fondos a las empresas de colectivos y SBASE.

Hay que enviar por nota oficial los archivos de liquidación en formato PDF y csv.

El envío mensual por colectivos consiste en:
  * Liquidación usos del mes (pdf)
  * Liquidación usos del mes (csv)
  * Liquidación rezagos del mes (pdf)
  * Liquidación rezagos del mes (csv)
  
Para el envío por SBASE falta que se asiente cuál es la periodicidad del envío. El mismo consistirá:
  * Liquidación usos del período (pdf)
  * Liquidación usos del período (csv)
  
## Ejecución del informe de seguimiento en R

### Ejecución del informe

1) Hay que declarar en las variables las tablas correspondientes al informe. Como se trabajan con datos históricos hay que trabajar desde marzo hasta el último mes del que se disponga.

Aclaración: como los rezagos son pocos, se ha decidido generar los reportes de seguimiento sin ellos

2) En la parte de análisis historicos hay que cargar las tablas a los meses pasados y generar las variables para los cuadros y los gráficos

### Envío

Esto sirve para tener una evolución del proyecto de Boleto Estudiantil. Internamente lo requiere el área de prensa para posibles informes.
También resulta de utilidad para el Ministerio de Educación.
