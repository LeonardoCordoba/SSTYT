-- Function: gps_mov.usp_join_gps_mov_mayo()

-- DROP FUNCTION gps_mov.usp_join_gps_mov_mayo();

CREATE OR REPLACE FUNCTION gps_mov.usp_join_gps_mov_mayo()
  RETURNS void AS
$BODY$
BEGIN
--
-- Construcción de la tabla mov_gps_anterior
--
SELECT a.id as id_mov, MIN(DATEDIFF('second', b.date_time, a.fecha_trx)) as diferencia_tiempo_anterior
--INTO gps_mov.a2016_05_int_anterior_1
FROM mov_dw.a2016_05 a
INNER JOIN gps_dw.a2016_05 b
ON a.interno = b.interno AND a.id_ramal = b.id_ramal AND a.d = b.d AND a.h = b.h 
WHERE a.fecha_trx > b.date_time
GROUP BY a.id;

CREATE UNIQUE INDEX a2016_05_int_anterior_1_idx ON gps_mov.a2016_05_int_anterior_1 (id_mov);

SELECT a.id as id_mov, MIN(b.id) as id_gps_anterior
--INTO gps_mov.a2016_05_int_anterior
FROM gps_mov.a2016_05_int_anterior_1 c
INNER JOIN mov_dw.a2016_05 a ON a.id = c.id_mov
INNER JOIN  gps_dw.a2016_05 b ON b.id_ramal = a.id_ramal AND b.interno = a.interno AND a.d = b.d AND a.h = b.h 
where a.fecha_trx > b.date_time AND datediff('second',b.date_time, a.fecha_trx) = c.diferencia_tiempo_anterior
GROUP BY a.id;


SELECT a.id as id_mov, MIN(DATEDIFF('second', b.date_time, a.fecha_trx)) as diferencia_tiempo_anterior
--INTO gps_mov.a2016_05_int_anterior_2
FROM mov_dw.a2016_05 a
INNER JOIN gps_dw.a2016_05 b 
ON a.interno = b.interno AND a.id_ramal = b.id_ramal AND a.d = b.d AND a.h = b.h +1
LEFT JOIN gps_mov.a2016_05_int_anterior c ON c.id_mov = a.id
WHERE c.id_gps_anterior IS NULL
AND a.fecha_trx > b.date_time
GROUP BY a.id;

CREATE UNIQUE INDEX a2016_05_int_anterior_2_idx ON gps_mov.a2016_05_int_anterior_2 (id_mov);

INSERT INTO gps_mov.a2016_05_int_anterior
SELECT a.id as id_mov, MIN(b.id) as id_gps_anterior
FROM gps_mov.a2016_05_int_anterior_2 c
INNER JOIN mov_dw.a2016_05 a ON a.id = c.id_mov
INNER JOIN  gps_dw.a2016_05 b ON b.id_ramal = a.id_ramal AND b.interno = a.interno AND a.d = b.d AND a.h = b.h +1
WHERE a.fecha_trx > b.date_time AND datediff('second',b.date_time, a.fecha_trx) = c.diferencia_tiempo_anterior
GROUP BY a.id;

CREATE UNIQUE INDEX a2016_05_int_anterior_idx ON gps_mov.a2016_05_int_anterior (id_mov);

--
-- Construcción de la tabla mov_gps_siguiente
--

-- El siguiente gps está en la misma hora
SELECT a.id as id_mov, MIN(DATEDIFF('second', a.fecha_trx, b.date_time)) as diferencia_tiempo_siguiente
--INTO gps_mov.a2016_05_int_siguiente_1
FROM mov_dw.a2016_05 a
INNER JOIN gps_dw.a2016_05 b
ON a.interno = b.interno AND a.id_ramal = b.id_ramal AND a.d = b.d AND a.h = b.h 
WHERE a.fecha_trx < b.date_time
GROUP BY a.id;

CREATE UNIQUE INDEX a2016_05_int_siguiente_1_idx ON gps_mov.a2016_05_int_siguiente_1 (id_mov);

SELECT a.id as id_mov, MIN(b.id) as id_gps_siguiente
--INTO gps_mov.a2016_05_int_siguiente
from gps_mov.a2016_05_int_siguiente_1 c
INNER JOIN mov_dw.a2016_05 a ON a.id = c.id_mov
INNER JOIN  gps_dw.a2016_05 b ON b.id_ramal = a.id_ramal AND b.interno = a.interno AND a.d = b.d AND a.h = b.h 
WHERE a.fecha_trx < b.date_time AND datediff('second', a.fecha_trx, b.date_time) = c.diferencia_tiempo_siguiente
GROUP BY a.id;

-- El siguiente gps está en la hora siguiente
SELECT a.id as id_mov, MIN(DATEDIFF('second', a.fecha_trx, b.date_time)) as diferencia_tiempo_siguiente
--INTO gps_mov.a2016_05_int_siguiente_2
FROM mov_dw.a2016_05 a
INNER JOIN gps_dw.a2016_05 b 
ON a.interno = b.interno AND a.id_ramal = b.id_ramal AND a.d = b.d AND a.h = b.h - 1
LEFT JOIN gps_mov.a2016_05_int_siguiente c ON c.id_mov = a.id
WHERE c.id_gps_siguiente IS NULL 
AND a.fecha_trx < b.date_time
GROUP BY a.id;

CREATE UNIQUE INDEX a2016_05_int_siguiente_2_idx ON gps_mov.a2016_05_int_siguiente_2 (id_mov);

INSERT INTO gps_mov.a2016_05_int_siguiente
SELECT a.id as id_mov, MIN(b.id) as id_gps_siguiente
from gps_mov.a2016_05_int_siguiente_2 c
INNER JOIN mov_dw.a2016_05 a ON a.id = c.id_mov
INNER JOIN  gps_dw.a2016_05 b ON b.id_ramal = a.id_ramal AND b.interno = a.interno AND a.d = b.d AND a.h = b.h -1
where a.fecha_trx < b.date_time AND datediff('second', a.fecha_trx, b.date_time) = c.diferencia_tiempo_siguiente
GROUP BY a.id;

CREATE UNIQUE INDEX a2016_05_int_siguiente_idx ON gps_mov.a2016_05_int_siguiente (id_mov);


--
-- Construcción de la tabla FULL con toda la info
--
SELECT a.*,
b.id as id_gps_anterior , b.latitud as latitud_anterior, b.longitud as longitud_anterior, datediff('second', b.date_time, a.fecha_trx) as diferencia_tiempo_anterior, b.velocity as velocity_anterior,
c.id as id_gps_siguiente,c.latitud as latitud_siguiente, c.longitud as longitud_siguiente,datediff('second', a.fecha_trx, c.date_time) as diferencia_tiempo_siguiente, c.velocity as velocity_siguiente
--INTO gps_mov.a2016_05_full
FROM mov_dw.a2016_05 a 
INNER JOIN gps_mov.a2016_05_int_anterior ant on a.id = ant.id_mov
INNER JOIN gps_mov.a2016_05_int_siguiente sig on a.id = sig.id_mov
INNER JOIN gps_dw.a2016_05 b on ant.id_gps_anterior = b.id
INNER JOIN gps_dw.a2016_05 c on sig.id_gps_siguiente = c.id;

DROP TABLE gps_mov.a2016_05_int_anterior_1;
DROP TABLE gps_mov.a2016_05_int_anterior;
DROP TABLE gps_mov.a2016_05_int_anterior_2;
DROP TABLE gps_mov.a2016_05_int_siguiente_1;
DROP TABLE gps_mov.a2016_05_int_siguiente_2;
DROP TABLE gps_mov.a2016_05_int_siguiente;

RETURN;
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION gps_mov.usp_join_gps_mov_mayo()
  OWNER TO postgres;

