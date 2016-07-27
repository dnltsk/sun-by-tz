#!/usr/bin/env Rscript

setwd("/Users/danielt/projects/sun-by-tz/")
args <- commandArgs(trailingOnly=TRUE)

#
# load required packages
#
requiredPackages <- c(
  "devtools",
  "rgdal",       #read, update and write Shapefile
  "rgeos",       #gCentroid()
  "insol",       #suncalc()
  "rvest",       #html_table()
  "lubridate",   #hm()
  "sp",
  "geojsonio",
  "rmapshaper",
  "jsonlite")    #fromJSON()
lapply(requiredPackages, function(p){
  if (!is.element(p, installed.packages()[,1]))
    install.packages(p, dep = TRUE)
  require(p, character.only = TRUE)
})

#
# download, extract and read shapefile
#
download.file("http://efele.net/maps/tz/world/tz_world_mp.zip", "data/tz_world_mp.zip")
unzip("data/tz_world_mp.zip", exdir = "data")
shp <- readOGR("data/world/tz_world_mp.shp", layer="tz_world_mp")
str(data.frame(shp))

#
# simplify
#
shpGeoJson <- geojson_json(shp, geometry = "polygon", group = "group")
shpGeoJsonSimplified <- ms_simplify(shpGeoJson)
shp <- readOGR(shpGeoJsonSimplified, "OGRGeoJSON",  verbose = F)
str(shp@data)

#
# load TZ streight forward infos from Wikipedia and append them to Shapefile
#
wiki <- read_html("https://en.wikipedia.org/wiki/List_of_tz_database_time_zones")
zoneInfos <- wiki %>% html_nodes("table") %>% .[[1]]  %>% html_table(fill=TRUE)
zoneInfos$dstOffset <- as.integer(hour(hm(zoneInfos$"UTC DST offset"))*60 + minute(hm(zoneInfos$"UTC DST offset")))

#
# append timezone offsets into base shapefile
#
shpWithOffset <- merge(shp, zoneInfos[,c("TZ*", "dstOffset")], by.x="TZID", by.y="TZ*", all=F)
str(data.frame(shpWithOffset))

#
# append sunrise and sunset attributes from weatherunderground API into shpWithOffsets
#
sunData <- data.frame(TZID=c(), sunrise=c(), sunset=c())
for(i in 1:nrow(shpWithOffset)) { 
  tzid <- shpWithOffset[i,]$TZID
  centroid <- gCentroid(shpWithOffset[i,], byid = TRUE)
  dayOfYear <- as.numeric(strftime(Sys.time(), format = "%j"))
  sun <- daylength(lat = centroid$y, long = centroid$y, dayOfYear, 0)
  sunrise <- paste(floor(sun[1,"sunrise"]), round((sun[1,"sunrise"]-floor(sun[1,"sunrise"]))*60), sep=":")
  sunset <- paste(floor(sun[1,"sunset"]), round((sun[1,"sunset"]-floor(sun[1,"sunset"]))*60), sep=":")
  sunData <- rbind(sunData,data.frame(TZID=tzid, sunrise=sunrise, sunset=sunset))
}
shpWithOffsetAndSun <- merge(shpWithOffset, sunData, by.x="TZID", by.y="TZID", all=T)
str(data.frame(shpWithOffsetAndSun))

#
# export simplified and enriched shapefile
#
writeOGR(shpWithOffsetAndSun, "data/simplifiedEnrichedZones.shp", layer="simplifiedZones", driver="ESRI Shapefile",
         overwrite_layer=T)

