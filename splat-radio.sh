#!/bin/bash
#
# Generate Splat map and HAAT calculation

# License: Public domain / CC-0

# dependencies:
# - splat 1.4.0
# - ImageMagick "convert"
# - OptiPNG

# Configuration:

# path to topgraphy datafiles
TOPOFILEDIR=splat-datafiles/sdf/
# file for state/county borders
BORDERFILE=splat-datafiles/borders/co99_d00.dat

#commands:
SPLAT=splat
SPLAT_HD=splat-hd

#default options:
USE_HIGHRES=false
USE_BGWHITE=false
SPLAT_CMD=$SPLAT
SPLAT_OPTIONS=("")
OPTIONS_RADIUS="100" #radius to render in [km]
OPTIONS_AGL="2"     #above ground level for receiving antenna [m]
OPTIONS_MR="1.333"  #Earth radius multiplier
OPTIONS_DB="160" #max attenuation to plot if no ERP given

if [ ! -x `which splat` ]; then
        #we assume that splat-hd is installed too
	echo "error: not found in path: splat"
	exit 1
fi

if [ ! -x `which convert` ]; then
	echo "error: not found in path: convert"
	exit 1
fi

if [ ! -x `which optipng` ]; then
	echo "error: not found in path: optipng"
	exit 1
fi


function helptext {
cat <<EOF

Usage: $0 -c CONFIGFILE [-b]

-c CONFIGFILE
        The file with your configuration, see README.md
        
-R RADIUS
        Render only up to a radius from QTH-File in [km]
        
-b      Render Topograpy Background in white, used to generate
        transparent overlays
        
-r      Use splat-hd to render high-res images, implies
        sdf-hd datafiles.
        
-h      Display this help message

EOF
}

#Extract commandline options, see helptext for explanation
while getopts ":c:brhR:" opt; do
  case $opt in
    b)
      USE_BGWHITE=true
      SPLAT_OPTIONS+=("-ngs")
      echo "Rendering Background in white, -b option set"
      ;;
    r)
      USE_HIGHRES=true
      SPLAT_CMD=$SPLAT_HD
      echo "Rendering high-res with splat-hd, -r option set"
      ;;
    R)
      OPTIONS_RADIUS=$OPTARG
      echo "Setting rendering radius to ${OPTARG}km"
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

# no more variables to edit below here
CLEANCALL=`echo $CALL | sed -e 's|/|-|g;'`
QTHFILE=$NAME.qth
LRPFILE=$NAME.lrp
LCFFILE=$NAME.lcf
SCFFILE=$NAME.scf
MAPPPMFILE=$NAME-map.ppm
MAPPNGFILE=$NAME-map.png
MAPJPGTHMBFILE=$NAME-map-thumb.jpg
REPFILE=$CLEANCALL-site_report.txt
HAATFILE=$NAME-haat.txt


# invert the longitude, because splat is backwards
REVLON=`echo "$LON * -1" | bc`

NICE="nice -20"

rm -f $QTHFILE $LRPFILE $LCFFILE $SCFFILE $MAPPPMFILE

echo $CLEANCALL > $QTHFILE
echo $LAT >> $QTHFILE
echo $REVLON >> $QTHFILE
echo $HTAGL >> $QTHFILE

# assume default propogation characteristics
echo "15.000  ; Earth Dielectric Constant (Relative permittivity)" > $LRPFILE
echo "0.005   ; Earth Conductivity (Siemens per meter)" >> $LRPFILE
echo "301.000 ; Atmospheric Bending Constant (N-units)" >> $LRPFILE
echo "$FREQMHZ ; Frequency in MHz (20 MHz to 20 GHz)" >> $LRPFILE
echo "5       ; Radio Climate (5 = Continental Temperate)" >> $LRPFILE
echo "1       ; Polarization (0 = Horizontal, 1 = Vertical)" >> $LRPFILE
echo "0.50    ; Fraction of situations (50% of locations)" >> $LRPFILE
echo "0.90    ; Fraction of time (90% of the time)" >> $LRPFILE
echo "$ERP ; ERP in Watts (optional)" >> $LRPFILE

# coloration for path-loss
cat > $LCFFILE << EOF
; SPLAT! Auto-generated  Path-Loss  Color  Definition  ("wnjt-dt.lcf") File
;
; Format for the parameters held in this file is as follows:
;
;    dB: red, green, blue
;
; ...where "dB" is the path loss (in dB) and
; "red", "green", and "blue" are the corresponding RGB color
; definitions ranging from 0 to 255 for the region specified.
;
; The following parameters may be edited and/or expanded
; for future runs of SPLAT!  A total of 32 contour regions
; may be defined in this file.
;
;
 80: 255,   0,   0
 90: 255, 128,   0
100: 255, 165,   0
110: 255, 206,   0
120: 255, 255,   0
130: 184, 255,   0
140:   0, 255,   0
150:   0, 208,   0
160:   0, 196, 196
170:   0, 148, 255
180:  80,  80, 255
190:   0,  38, 255
200: 142,  63, 255
210: 196,  54, 255
220: 255,   0, 255
230: 255, 194, 204
EOF

# coloration for signal level color
cat > $SCFFILE << EOF
; SPLAT! Auto-generated Signal Color Definition ("wnjt-dt.scf") File
;
; Format for the parameters held in this file is as follows:
;
;    dBuV/m: red, green, blue
;
; ...where "dBuV/m" is the signal strength (in dBuV/m) and
; "red", "green", and "blue" are the corresponding RGB color
; definitions ranging from 0 to 255 for the region specified.
;
; The following parameters may be edited and/or expanded
; for future runs of SPLAT!  A total of 32 contour regions
; may be defined in this file.
;
;
128: 255,   0,   0
118: 255, 165,   0
108: 255, 206,   0
 98: 255, 255,   0
 88: 184, 255,   0
 78:   0, 255,   0
 68:   0, 208,   0
 58:   0, 196, 196
 48:   0, 148, 255
 38:  80,  80, 255
 28:   0,  38, 255
 18: 142,  63, 255
EOF

# -R 100 = 100 miles max
# -L 6 = 6 ft AGL for RX
# -m 1.333 = earth radius multiplier
# -db 160 = max attenuation contour
# -erp = ERP override
# -d = path to elevation data files
# -o = output file
# -olditm = old ITM analysis, seems more accurate
# -ngs = display topograpy as white

#add all needed options:
#danger may not be compatible with spaces in filenames
SPLAT_OPTIONS+=("-olditm")
SPLAT_OPTIONS+=("-metric")
SPLAT_OPTIONS+=("-t ${QTHFILE}")
SPLAT_OPTIONS+=("-R ${OPTIONS_RADIUS}")
SPLAT_OPTIONS+=("-L ${OPTIONS_AGL}")
SPLAT_OPTIONS+=("-m ${OPTIONS_MR}")
SPLAT_OPTIONS+=("-o ${MAPPPMFILE}")
SPLAT_OPTIONS+=("-erp ${ERP}")
SPLAT_OPTIONS+=("-d ${TOPOFILEDIR}")

if [ -r $BORDERFILE ];then
    SPLAT_OPTIONS+="-b ${BORDERFILE}"
else
    echo "No Borderfile found, skipping"
fi

if [ $ERP -eq 0 ] ; then
    echo "ERP is null, plot to max attenuation of ${OPTIONS_DB}db"
    SPLAT_OPTIONS+="-db ${OPTIONS_DB} "
fi

echo "Running $SPLAT_CMD to generate images:"
echo "Options: ${SPLAT_OPTIONS[@]}"
#echo $SPLAT_CMD ${SPLAT_OPTIONS[@]}
time $NICE $SPLAT_CMD ${SPLAT_OPTIONS[@]} 


rm -f $MAPPNGFILE $MAPJPGTHMBFILE

echo "converting PPM to PNG"
$NICE convert $MAPPPMFILE $MAPPNGFILE
echo "converting PNG to JPG"
$NICE convert $MAPPNGFILE -scale 800x810 $MAPJPGTHMBFILE
echo "optipng"
$NICE optipng -q $MAPPNGFILE

# in feet
HAATFT=`grep "Antenna height above average terrain" $REPFILE | \
	sed -r -e "s/^.*: ([-0-9.]+) .*$/\1/;"`

rm -f $QTHFILE $LRPFILE $LCFFILE $SCFFILE $MAPPPMFILE $REPFILE $HAATFILE

echo $HAATFT > $HAATFILE

ls -l $HAATFILE $MAPPNGFILE $MAPJPGTHMBFILE

