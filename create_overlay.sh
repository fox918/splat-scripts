#/bin/bash

# Creates an overlay for use with openstreetmap
# 
# 
# created in 2016 by HB3YMB
# inspired by https://github.com/molo1134/splat-scripts/

# tested on arch linux with
# GDAL 2.0.2, released 2016/01/26



#check for used software
SPLATSCRIPT="./splat-radio.sh"
CONVERT="convert"
MKDIR="mkdir"

GDAL_TRANSLATE="gdal_translate"
GDAL_TILE="gdal2tiles.py"

USE_HIGHRES=false


# Check if all prerequisites are installed
if [ ! -x `which $SPLATSCRIPT` ]; then
	echo "error: not found in path: $SPLAT"
	exit 1
fi
if [ ! -x `which $GDAL_TRANSLATE` ]; then
	echo "error: not found in path: gdal_translate"
	exit 1
fi
if [ ! -x `which $GDAL_TILE` ]; then
	echo "error: not found in path: $GDAL_TILE"
	exit 1
fi
if [ ! -x `which $CONVERT` ]; then
	echo "error: not found in path: convert"
	exit 1
fi
if [ ! -x `which $MKDIR` ]; then
	echo "error: not found in path: mkdir"
	exit 1
fi


function helptext {
cat <<EOF

Usage: $0 -c CONFIGFILE 

-c CONFIGFILE
        The file with your configuration, see README.md
        

EOF
}

#Extract commandline options, see helptext for explanation
while getopts ":c:hr" opt; do
  case $opt in
    r)
      USE_HIGHRES=true
      SPLAT_CMD=$SPLAT_HD
      echo "Rendering high-res with splat-hd, -r option set"
      ;;
    c)
      echo "Using configuration file: ${OPTARG}"
      CONFIGFILE=$OPTARG
      ;;
    h)
      helptext
      exit 1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      helptext
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      helptext
      exit 1
      ;;
  esac
done

#check for configfile, load if given
if [ ! -z "$CONFIGFILE" ] && [ -r $CONFIGFILE ]; then
    echo "read in configfile"
    source $CONFIGFILE
else
    echo "No configfile given, exiting now"
    helptext
    exit 1
fi

#vars
#PPMFILE="./$NAME-map-hd.ppm"
PNGSOLID=$NAME-map.png
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
$SPLATSCRIPT -c $CONFIGFILE -R 20 -b -r
#$SPLAT -t hol.qth -d ./maps/ -L 2 -metric -R 25 -sc  -ngs -erp $ERP -o $PPMFILE


#prepare image
#$CONVERT $PPMFILE $PNGSOLID
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
