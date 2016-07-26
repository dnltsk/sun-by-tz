#!/usr/bin/env Rscript

setwd("/Users/danielt/projects/sun-by-tz/")
args <- commandArgs(trailingOnly=TRUE)

#
# load required packages
#
requiredPackages <- c(
  "rgdal",       #read, update and write Shapefile
  "raster",      #shift()
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

