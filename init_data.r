#!/usr/bin/env Rscript

setwd("/Users/danielt/projects/sun-by-tz/")
args <- commandArgs(trailingOnly=TRUE)

#
# load required packages
#
requiredPackages <- c(
  "properties", 
  "rgdal",       #read, update and write Shapefile
  "rgeos",       #gCentroid()
  "insol",       #suncalc()
  "rvest",       #html_table()
  "raster",      #html_table()
  "lubridate",   #hm()
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
# load TZ streight forward infos from Wikipedia and append them to Shapefile
#
wiki <- read_html("https://en.wikipedia.org/wiki/List_of_tz_database_time_zones")
zoneInfos <- wiki %>% html_nodes("table") %>% .[[1]]  %>% html_table(fill=TRUE)
zoneInfos$dstOffset <- hour(hm(zoneInfos$"UTC DST offset"))*60 + minute(hm(zoneInfos$"UTC DST offset")) 

#
# append timezone offsets into base shapefile
#

shpWithOffset <- merge(shp, zoneInfos[,c("TZ*", "dstOffset")], by.x="TZID", by.y="TZ*", all=T)
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

#
# export new shapefile
#
writeOGR(shpWithOffsetAndSun, "data/enrichedTimezones.shp", layer="enrichedTimezones", driver="ESRI Shapefile")

