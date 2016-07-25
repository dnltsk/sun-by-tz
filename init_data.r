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
  "jsonlite")    #fromJSON()
lapply(requiredPackages, function(p){
  if (!is.element(p, installed.packages()[,1]))
    install.packages(p, dep = TRUE)
  require(p, character.only = TRUE)
})

#
# get wunderground.key
#
config <- read.properties("config.properties")
wunderground.key = NULL
if(length(config$wunderground.key) > 0){
  message("using ", config$wunderground.key, " as wunderground.key")
  wunderground.key <- config$wunderground.key
}else{
  warning("no wunderground.key property in config.properties found")
}
if(length(args) > 0){
  message("using ", args[1], " as wunderground.key")
  wunderground.key <- args[1]
}else{
  warning("no wunderground.key set via argumenet")
}
if(is.null(wunderground.key)){
  stop("weatherunderground key is not set.\nPlease register for a free key at\nhttps://www.wunderground.com/member/registration?mode=api_signup")   
}

#
# load TZ streight forward infos from Wikipedia and append them to Shapefile
#
wiki <- read_html("https://en.wikipedia.org/wiki/List_of_tz_database_time_zones")
zoneInfos <- wiki %>% html_nodes("table") %>% .[[1]]  %>% html_table(fill=TRUE)

#
# download, extract and read shapefile
#
download.file("http://efele.net/maps/tz/world/tz_world_mp.zip", "data/tz_world_mp.zip")
unzip("data/tz_world_mp.zip", exdir = "data")
shp <- readOGR("data/world/tz_world_mp.shp", layer="tz_world_mp")
str(data.frame(shp))

#
# append timezone offsets into base shapefile
#
shpWithOffsets <- merge(shp, zoneInfos[,c("TZ*", "UTC offset", "UTC DST offset")], by.x="TZID", by.y="TZ*", all=T)
str(data.frame(shpWithOffsets))

#
# append sunrise and sunset attributes from weatherunderground API into shpWithOffsets
#
sunData <- data.frame(TZID=c(), sunrise=c(), sunset=c())
for(i in 1:nrow(shpWithOffsets)) { 
  tzid <- shpWithOffsets[i,]$TZID
  centroid <- gCentroid(shpWithOffsets[i,], byid = TRUE)
  dayOfYear <- as.numeric(strftime(Sys.time(), format = "%j"))
  sun <- daylength(lat = centroid$y, long = centroid$y, dayOfYear, 0)
  sunrise <- paste(floor(sun[1,"sunrise"]), round((sun[1,"sunrise"]-floor(sun[1,"sunrise"]))*60), sep=":")
  sunset <- paste(floor(sun[1,"sunset"]), round((sun[1,"sunset"]-floor(sun[1,"sunset"]))*60), sep=":")
  sunData <- rbind(sunData,data.frame(TZID=tzid, sunrise=sunrise, sunset=sunset))
}
shpWithOffsetsAndSun <- merge(shpWithOffsets, sunData, by.x="TZID", by.y="TZID", all=T)


data.frame(shpWithOffsetsAndSun)
