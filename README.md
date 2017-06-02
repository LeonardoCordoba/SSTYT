# SSTYT - Subsecretaría de Tránsito y Transporte - Gobierno de la Ciudad de Buenos Aires

## Introducción
En este repositorio pueden accederse los principales scripts utilizados por el equipo de explotación de datos de la Subsecretaría de Tránsito y Transporte. Los lenguajes utilizados son, mayormente, R, aunque también SQL y Python.
Los integrantes del equipo son:
- María Gaska
- Juan Manuel Barriola
- Fernando González
- Leonardo Ignacio Córdoba

Los trabajos fueron mayormente realizados con la base de datos de SUBE (Sistema Único de Boleto Electrónico), que cuenta con información transaccional y todos los colectivos, subterráneos y trenes del Área Metropolitana de Buenos Aires, y con datos GPS de colectivos. Además, se trabajó con información de Nokia Here para posicionamiento y velocidades de vehículos privados.

## Organización
El repositorio está organizado de la siguiente manera:
- Boleto Estudiantil: scripts relacionados a la liquidación del BE, es decir, al pago del monto correspondiente al programa a cada empresa de colectivos y a SBASE (Subterráneos), y a la generación de informes de seguimiento.
- Cálculo de servicios: scripts que permiten el cálculo de servicios de colectivos, esto es, cuántas veces sale un colectivo de una cabecera a otra, de cierta línea. El proceso se dividió en dos: primero se asignan ramales, y luego se cuentan servicios.
- Estimación de paradas de colectivos: a partir de la geolocalización de transacciones se generó un algoritmo que emplea DBSCAN para encontrar paradas de colectivos en el AMBA.
- Informes - Centros de Transbordos: distintos archivos de RMarkdown para generar informes que toman como input un área geográfica y produce una serie de indicadores en la misma. Se presentan informes de centros de transbordos con perfiles horarios, cantidad de transbordos, de transacciones, qué combinaciones entre medios de transporte se realizan, etc.
- Matriz Origen-Destino: se generó una matriz OD de colectivos, trenes y subtes. La matriz está calculada en términos de viajes y en términos de etapas de viajes. Además, se generan informes al respecto.
- Otros SUBE: diferentes scripts relacionados con SUBE, como joinear transacciones y posiciones GPS, calcular transbordos, etc.
- Otros: scripts no relacionados a SUBE ni a Nokia Here.
- Velocidad: estimación de velocidades por corredor para las distintas horas del día con SUBE (transporte público) y con Nokia Here (vehículos particulares).
