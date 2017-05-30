-- Function: mov_dw.usp_cursor_transbordos()

-- DROP FUNCTION mov_dw.usp_cursor_transbordos();

CREATE OR REPLACE FUNCTION mov_dw.usp_cursor_transbordos()
  RETURNS void AS
$BODY$
	DECLARE nrotarjeta1 bigint;
	DECLARE fechatrx1 timestamp without time zone;
	DECLARE idlinea1 character varying (200);
	DECLARE modohist1 varchar(100);
	DECLARE modo1 varchar(100);
	DECLARE secuencia_tarjeta_incr1 bigint;
	DECLARE nrotarjetahist bigint;
	DECLARE fechatrxhist timestamp without time zone;
	DECLARE idlineahist character varying (200);
	DECLARE nroviaje1 bigint :=0;
	DECLARE etapaviaje1 bigint :=0;
	DECLARE db_cursor CURSOR FOR SELECT nro_tarjeta,secuencia_tarjeta_incr FROM mov_dw.a2016_05 WHERE codigo_tipo_trx = 19 AND categoria IN ('BUS','BUS - AMBA','BUS - MUNI','BUS - PROV','TREN','BUS','SUBTE','PREMETRO')
	AND date_part('month',fecha_trx) = 5
	ORDER BY nro_tarjeta,secuencia_tarjeta_incr;
  BEGIN
	OPEN db_cursor;
	LOOP
	FETCH FROM db_cursor INTO nrotarjeta1, secuencia_tarjeta_incr1;

	SELECT id_linea,fecha_trx,modo INTO idlinea1,fechatrx1,modo1  FROM mov_dw.a2016_05 where nro_tarjeta=nrotarjeta1 AND secuencia_tarjeta_incr = secuencia_tarjeta_incr1;
	
    --Condiciones para empezar un nuevo viaje
    IF
     COALESCE(nrotarjetahist,NULL) <> nrotarjeta1 OR --Cambia la tarjeta
     COALESCE(idlineahist,NULL) = idlinea1 OR -- La línea es la misma
    (COALESCE(idlineahist,NULL) IN ('440','441','442','443','444','445','446') AND idlinea1 IN ('440','441','442','443','444','445','446'))
     -- Subte subte
     OR datediff('minute', COALESCE(fechatrxhist,'19000101'), fechatrx1) < 2

     -- Pagos seguidos con la misma tarjeta
     OR NOT
     (
     (COALESCE(modohist1,'') = 'TREN' AND 
datediff('minute', COALESCE(fechatrxhist,'19000101'), fechatrx1) < 120)
     --No hay integración en tren
     OR
     (COALESCE(modohist1,'') = 'BUS' AND
datediff('minute', COALESCE(fechatrxhist,'19000101'), fechatrx1) < 90)
     --Ni hay integración en bus
     OR
    (COALESCE(modohist1,'') = 'SUBTE' AND
datediff('minute', COALESCE(fechatrxhist,'19000101'), fechatrx1) < 60))
     --Ni hay integración en subte
    THEN
        --Empieza un nuevo viaje
        fechatrxhist := fechatrx1;
        nroviaje1 := nroviaje1 + 1;
        etapaviaje1 := 1;
    
   ELSE
  
        --No empieza un nuevo viaje   
        etapaviaje1 := etapaviaje1 + 1;
END IF;    
    --Asigno el viaje que tenía indicado
  UPDATE mov_dw.a2016_05 set nro_viaje= nroviaje1, etapa_viaje= etapaviaje1
        WHERE nro_tarjeta = nrotarjeta1 AND secuencia_tarjeta_incr = secuencia_tarjeta_incr1 ;
    
    nrotarjetahist := nrotarjeta1;
    fechatrxhist := fechatrx1;
    idlineahist := idlinea1;
    modohist1 := modo1;
	EXIT WHEN NOT FOUND;
	END LOOP;
	CLOSE db_cursor;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION mov_dw.usp_cursor_transbordos()
  OWNER TO postgres;
