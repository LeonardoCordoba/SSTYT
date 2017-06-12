# Cálculo de servicios

## Introducción

Con estos scripts se pueden estimar los servicios de la mayoría de las líneas de colectivos, a partir de sus rutas y los puntos GPS de SUBE. Consideramos un servicio como un determinado colectivo (interno) de cierta línea que realiza el recorrido correspondiente a cierto ramal desde una cabecera hasta la otra. 

El procedimiento esta escrito considerando las siguientes restricciones:
- Cada línea pueden tener mas de un ramal, con un recorrido de 'ida' y otro de 'vuelta'
- Los GPS tienen una frecuencia de uno cada 4 minutos, aproximadamente.
- No se puede confiar en el ramal que los choferes asignan en la SUBE.

## Algoritmo

El procedimiento se divide en dos etapas, una primera etapa en la que se asigna un servicio y una segunda etapa en la que se asigna un ramal.

### Asginación de servicios

Para asignar un servicio se comienza generando una serie de 'cabeceroides', esto es, un conjunto de cabeceras de "ida" y un conjunto de cabeceras de "vuelta". Es decir, se agrupan, de un lado, las cabeceras de "ida" y, de otro lado, las cabeceras de "vuelta", según están caracterizadas en las rutas mantenidas por USIG (quienes mantienen Mapa Interactivo de Buenos Aires).
Una vez realizado esto, se procede a tomar los datos GPS de cierta linea e interno y ordenándolos por fecha, asignar un id de servicio cada vez que el GPS entra en un cabeceroide distinto. En otras palabras, tomando sólo los GPS que están dentro de un cabeceroide se contrasta si éste es igual al anterior, de no ser así cambia el id de servicio. Se hace un procedimiento adicional que es asignar a la mitad de los GPS dentro de un cabeceroide el valor del id de servicio de "ida" y a la otra mitad del de "vuelta".

### Asignación de ramal

Posteriormente, es necesario asignar el ramal. Para ello se procede de la siguiente manera:
- Se toman los puntos GPS de cierta línea y servicio, con su sentido asociado, y las rutas de los ramales de "ida" o de "vuelta", según corresponda (rutas candidatas).
- Se siguen los puntos GPS hasta encontrar algunos que unívocamente referencien a un ramal y no a otro. Si esto no se logra, por falta de puntos GPS, se estima la distancia promedio a la ruta y se toma la ruta con la menor distancia promedio entre los puntos GPS y las rutas candidatas.

## Resultado
Finalmente se obtiene la misma tabla con los datos de GPS pero con columnas que identifican cada servicio, si pertenecen o no a un cabeceroide y el sentido del recorrido.
