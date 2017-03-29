#Script para llamar al web service de USIG para hacer geocodificación

#install.packages('RCurl')
library(RCurl)

#Paso vector de calles y alturas
calles <- c("CORDOBA AV.", "RODRIGUEZ PEÑA")
altura <- c(1750,1051)

x_ls <- c()
y_ls <- c()

for (i in 1:length(calles)) {
  #Cargo la URL
  query <- paste("http://ws.usig.buenosaires.gob.ar/geocoder/2.2/geocoding?cod_calle=",calles[i],"&altura=", altura[i], sep = '')
  #Encoding de la URL
  query <- URLencode(query)
  
  #Obtengo la URL
  a <- getURL(query)
  
  #Desempaco la data
  b <- unlist(strsplit(a, ","))
  x <- b[1]
  y <- b[2]
  x <- unlist(strsplit(x, ":"))[2]
  x <- unlist(strsplit(x, '"'))[2]
  y <- unlist(strsplit(y, ":"))[2]
  y <- unlist(strsplit(y, '"'))[2]
  
  #La guardo
  x_ls[[length(x_ls)+1]] <- x
  y_ls[[length(y_ls)+1]] <- y
}

#Obtengo vector de longitud y latitud
x_ls
y_ls
