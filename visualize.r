#!/usr/bin/env Rscript

setwd("/Users/danielt/projects/sun-by-tz/")

#
# load required packages
#
requiredPackages <- c(
  "rgdal",       #read, update and write Shapefile
  "raster",      #shift()
  "lubridate",   #hm()
  "maptools",
  "ggplot2",     # fortify(), ggplot()
  "plyr"
  )
lapply(requiredPackages, function(p){
  if (!is.element(p, installed.packages()[,1]))
    install.packages(p, dep = TRUE)
  require(p, character.only = TRUE)
})

#
# load prepared dara
#
shp <- readOGR("data/enrichedTimezones.shp", layer="enrichedTimezones")

#
# prepare for use in ggplot
# https://github.com/hadley/ggplot2/wiki/plotting-polygon-shapefiles
# http://stackoverflow.com/questions/32278513/r-fatal-error-crash-when-using-fortify
#
shp@data$id = rownames(shp@data)
shp.points = fortify(shp)
shp.df = join(shp.points, shp@data, by="id")

#
# plot
#
ggplot(shp.df) + 
  aes(long,lat,group=group,fill=TZID) + 
  geom_polygon() +
  geom_path(color="white") +
  coord_equal() +
  theme(legend.position="none")
