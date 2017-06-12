# Manual de liquidación

## Creación tabla de liquidación mensual

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
 
### Creación de la columna mes de liquidación (Postgres)

ALTER TABLE boleto_estudiantil.liquidacion_año_mes
ADD COLUMN  mes_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_año_mes (Postgres)
SET mes_liqui = mm
WHERE periodo = 'mmyyyy'
 
### Creación columna año de liquidación (Postgres)
ALTER TABLE boleto_estudiantil.liquidacion_año_mes
ADD COLUMN  ano_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_año_mes
SET ano_liqui = yyyy
WHERE periodo = 'mmyyyy'    
 
## Creación tabla de liquidación mensual de rezagos

### Creación de la tabla mensual rezagos (Postgres)
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
 
### Carga de datos a la tabla (Postgres)
COPY boleto_estudiantil.liquidacion_año_mes_rezagos FROM '/home/innovacion/nombre_archivo.csv' DELIMITER ';' CSV HEADER;
 
### Creación de la columna mes de liquidación (Postgres)
ALTER TABLE boleto_estudiantil.liquidacion_año_mes_rezagos
ADD COLUMN  mes_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_año_mes_rezagos
SET mes_liqui = mm
WHERE periodo = 'mmyyyy'
 
### Creación columna año de liquidación (Postgres)
ALTER TABLE boleto_estudiantil.liquidacion_año_mes_rezagos
ADD COLUMN  ano_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_año_mes_rezagos
SET ano_liqui = yyyy
WHERE periodo = 'mmyyyy'    
 
