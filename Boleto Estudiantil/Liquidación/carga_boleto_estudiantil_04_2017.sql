﻿-- 1) Creación de la tabla mensual
CREATE TABLE boleto_estudiantil.liquidacion_2017_04(
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

-- Carga de datos a la tabla
COPY boleto_estudiantil.liquidacion_2017_04 FROM '/home/innovacion/201704-boleto_estudiantil_201704.csv' DELIMITER ';' CSV HEADER;

-- Creación de la columna mes de liquidación
ALTER TABLE boleto_estudiantil.liquidacion_2017_04
ADD COLUMN  mes_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_2017_04
SET mes_liqui = 04
WHERE periodo = '042017'
 
-- Creación columna año de liquidación   
ALTER TABLE boleto_estudiantil.liquidacion_2017_04
ADD COLUMN  ano_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_2017_04
SET ano_liqui = 2017
WHERE periodo = '042017'    

-- 2) Creación de la tabla mensual rezagos (Postgres)
CREATE TABLE boleto_estudiantil.liquidacion_2017_04_rezagos(
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

-- Carga de datos a la tabla (Postgres)
COPY boleto_estudiantil.liquidacion_2017_04_rezagos FROM '/home/innovacion/201704-boleto_estudiantil_201704r.csv' DELIMITER ';' CSV HEADER;

-- Creación de la columna mes de liquidación (Postgres)
ALTER TABLE boleto_estudiantil.liquidacion_2017_04_rezagos
ADD COLUMN  mes_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_2017_04_rezagos
SET mes_liqui = 04
WHERE periodo = '032017'
 
-- Creación columna año de liquidación (Postgres)
ALTER TABLE boleto_estudiantil.liquidacion_2017_04_rezagos
ADD COLUMN  ano_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_2017_04_rezagos
SET ano_liqui = 2017
WHERE periodo = '032017'  

--3) Creación de la tabla ELR (Postgres)
CREATE TABLE tablas_complementarias.elr_2017_05 (
id_empresa integer,
desc_empresa character varying,
cuit bigint,
id_linea integer,
desc_linea character varying,
id_ramal integer,
ramal_corto character varying,
desc_ramal character varying)

-- Carga de datos a la tabla (Postgres)
COPY tablas_complementarias.elr_2017_05 FROM '/home/innovacion/201704-e-l-r-09-05-2017.csv' DELIMITER ';' CSV HEADER;

-- Creación de la columna modo
ALTER TABLE tablas_complementarias.elr_2017_05 
ADD COLUMN modo varchar(100);

-- Seteo BUS en la columna modo
UPDATE tablas_complementarias.elr_2017_05
SET modo = 'BUS'
WHERE id_empresa <> 1

-- Agrega las filas correspondientes a subte (no vienen en el archivo original)
INSERT INTO tablas_complementarias.elr_2017_05
SELECT * FROM tablas_complementarias.elr_a2017_04 where id_empresa = 1

-- Creación de la columna mes de liquidación (Postgres)
ALTER TABLE boleto_estudiantil.liquidacion_año_mes_rezagos
ADD COLUMN  mes_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_año_mes_rezagos
SET mes_liqui = mm
WHERE periodo = 'mmyyyy'
 
-- Creación columna año de liquidación (Postgres)
ALTER TABLE boleto_estudiantil.liquidacion_año_mes_rezagos
ADD COLUMN  ano_liqui integer
    
UPDATE boleto_estudiantil.liquidacion_año_mes_rezagos
SET ano_liqui = yyyy
WHERE periodo = 'mmyyyy'