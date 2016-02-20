#/bin/bash

# Creates an overlay for use with openstreetmap
# 
# 
# created in 2016 by HB3YMB
# inspired by https://github.com/molo1134/splat-scripts/

# tested on arch linux with
# GDAL 2.0.2, released 2016/01/26



#check for used software
SPLAT="./splat-hd"
CONVERT="convert"
MKDIR="mkdir"

GDAL_TRANSLATE="gdal_translate"
GDAL_TILE="gdal2tiles.py"

#read in the configuration
if ! [ -f "$1" ]
then
    echo "No config file given, exit"
    exit
fi
    
. ./$1


#vars
PPMFILE="./$NAME-map-hd.ppm"
PNGSOLID="./$NAME-map-hd-solid.png"
PNGTRANS="./$NAME-map-hd-tr.png"
SCALEFILE="./$NAME-scale.png"

GEOTIFF="./$NAME-map-hd.geotiff"
GEOVRT="./$NAME-map-hd.vrt"
TILEFOLDER="./$name-geotiles"

GEODATE="EPSG:4326"
ZOOMLEVELS="7-14"

#all,google,openlayers,none
WEBVIEWER="all" 


#render the splat image with white background
# TODO change the ./splat-radio.sh to do this
$SPLAT -t hol.qth -d ./maps/ -L 2 -metric -R 25 -sc  -ngs -erp $ERP -o $PPMFILE


#prepare image
$CONVERT $PPMFILE $PNGSOLID
$CONVERT -gravity South -crop x30+0+0 $PNGSOLID $SCALEFILE
$CONVERT $PNGSOLID -transparent white $PNGTRANS
#crop scale from image
$CONVERT -crop +0-30 $PNGTRANS $PNGTRANS 

#do some oversampling to create softer images
# TODO make flag to enable oversampling 
# this is 'cheating' but creates nicer images
# $CONVERT hol.ppm -resize 400% -gaussian 10 filter.png

#create a georeferenced geotiff out of the image
# not sure if gdal-hd images are always 1 degree in height, maybe calculate out of imagesize
# not sure if gdal-hd images are always 2 degrees in width, maybe calculate out of imagesize
LATINT=${LAT%.*}
LONINT=${LON%.*}
$GDAL_TRANSLATE -of GTiff -a_ullr $LONINT $((LATINT+1)) $((LONINT+2)) $LATINT -a_srs EPSG:4326 $PNGTRANS $GEOTIFF
# $GDAL_TRANSLATE -of Gtiff -a_ullr 7 48 9 47 -a_srs EPSG:4326 hol.png test.tif

#create the maptiles out of the geotiff
$MKDIR -p $TILEFOLDER
$GDAL_TRANSLATE -a_srs $GEODATE -of vrt -expand rgba $GEOTIFF $GEOVRT

# TODO some strange bug if adding true geodate
#gdalwarp -of GTiff -s_srs EPSG:4326 -t_srs EPSG:3857 $GEOVRT temp.geotiff
$GDAL_TILE -s $GEODATE -z $ZOOMLEVELS -t "$NAME--$CALL" -w $WEBVIEWER $GEOVRT $TILEFOLDER
#echo $GDAL_TILE  -s "WGS84" -z "$ZOOMLEVELS" -t "$NAME" -w "$WEBVIEWER" $GEOVRT $TILEFOLDER
#s "$GEODATE"-z "$ZOOMLEVELS" -t "$NAME" -w "$WEBVIEWER"

#remove unused files
# TODO RELEASE rm $PPMFILE $PNGSOLID $GEOVRT

#deleting maybe useful files, (TODO make flag)
# TODO RELEASE rm $PNGTRANS $GEOTIFF 

#goodbye and thanks for all the fish :)
