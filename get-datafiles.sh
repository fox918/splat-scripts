#!/bin/sh

# get the SRTM data files and convert them for splat use

# License: Public domain / CC-0

# Takes one parameter: the continent to retrieve.  Valid values:
#
# Africa
# Australia
# Eurasia
# Islands
# North_America
# South_America

# path to topgraphy datafiles
TOPOFILEDIR=splat-datafiles/sdf/
# local hgt file archive
HGTFILEDIR=splat-datafiles/hgtzip/

# TODO remove ./ for prod
SRTM2SDF_HD=./srtm2sdf-hd
SRTM2SDF=./srtm2sdf

SRTM3URL="http://dds.cr.usgs.gov/srtm/version2_1/SRTM3/"
SRTM1URL="http://e4ftl01.cr.usgs.gov/SRTM/SRTMGL1.003/2000.02.11/" 


SRTM2SDF_CMD=$SRTM2SDF

#wether or not hgt files shall be directly extracted (saves diskspace)
USE_HIGHRES=false
DIRECT_CONVERSION=false
CONTINENT=unknown

function helptext {
cat <<EOF
Usage: $0 -c CONTINENT [-d] [-r]

-h      display this helptext

-c      specify the continent to download 
        Valid options are:
        North_America, South_America, Africa,
        Eurasia, Australia, Islands

-r      Download High Resolution SRTM data for use
        with splat-hd.
        The whole world will be downloaded, no
        separation between continents!

-d      Direct mode, do not store downloaded files,
        this greatly reduces diskspace.
        This continously convert the downloaded .hgt.zip files
        to sdf files and delete all files exept the 
        resulting sdf file.
        No resume possible if download process interrupted!
        
        
        
EOF
}


while getopts ":dc:rh" opt; do
  case $opt in
    h)
      helptext
      exit 1
      ;;
      
    d)
      echo "DIRECT MODE: Directly converting *.hgt files, deleting zips"
      DIRECT_CONVERSION=true
      ;;
    c)
      CONTINENT=$OPTARG
      echo "Continent set to $CONTINENT"
      ;;
    r)
      SRTM2SDF_CMD=$SRTM2SDF_HD
      USE_HIGHRES=true
      echo "HIGH RESOLUTION: Using $SRTM2SDF_CMD instead of srtm2sdf"
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


case $CONTINENT in
	North_America|South_America|Africa|Eurasia|Australia|Islands)
		echo $CONTINENT
		;;
	*)
		echo "Invalid continent: $CONTINENT"
		exit 1
		;;
esac

#set url to download tiles from:
if [ "$USE_HIGHRES" = true ]
then
    INDEXURL=$SRTM1URL
else
    INDEXURL=${SRTM3URL}${CONTINENT}/
fi

INDEXFILE=`mktemp`
FILELIST=`mktemp`

if [ ! -x `which $SRTM2SDF` ]; then
	echo "error: not found in path: srtm2sdf splat conversion utility"
	exit 1
fi

if [ ! -x `which readlink` ]; then
	echo "error: not found in path: readlink"
	exit 1
fi

if [ ! -x `which wget` ]; then
	echo "error: not found in path: wget"
	exit 1
fi

if [ ! -x `which unzip` ]; then
	echo "error: not found in path: unzip"
	exit 1
fi

if [ ! -x `which bzip2` ]; then
	echo "error: not found in path: bzip2"
	exit 1
fi

echo "getting index.. from $INDEXURL"
wget -q -O - $INDEXURL > $INDEXFILE
	
if [ "$USE_HIGHRES" = true ]
then  
   #random magic stolen from the internet
   grep -F '.hgt.zip<' $INDEXFILE | sed -e 's@.*href="@@g' -e 's/">.*//g' > $FILELIST
else
    wget -q -O - $INDEXURL | \
	sed -r -e '/hgt.zip/!d; s/.* ([NSWE0-9]+\.?hgt\.zip).*$/\1/;' \
	> $FILELIST
fi

mkdir -p $HGTFILEDIR
mkdir -p $TOPOFILEDIR

echo "retrieving files.."
#cd $HGTFILEDIR
#head $INDEXFILE

#convert to absolute path because srtm2sdf need cd
HGTREALPATH=`readlink -f $HGTFILEDIR`
TOPOREALPATH=`readlink -f $TOPOFILEDIR`

PWD=`pwd`

# TODO delete for prod:
SRTM2SDF_CMD=$PWD/$SRTM2SDF_CMD

for FILE in $(cat $FILELIST);
do
    echo $FILE
    if [ "$USE_HIGHRES" = true ]
    then
        HGTFILE=${FILE%SRTMGL1.hgt.zip}hgt
    else
        HGTFILE=${FILE%.zip}
    fi
    
    
    wget -P $HGTFILEDIR -nv -N $INDEXURL$FILE
    
    #in direct conversion mode, directly make an sdf and delete all downloaded files
    if [ "$DIRECT_CONVERSION" = true ] ;
    then
        echo "Unzip $FILE and then delete zip"
        nice unzip -o $HGTFILEDIR/$FILE -d $TOPOFILEDIR
        rm $HGTFILEDIR/$FILE
        
	
	
        #only execute if file exists:
	if [ -r $TOPOFILEDIR/$HGTFILE ]; 
	then
                echo "Convert $HGTFILE to SDF"
		cd $TOPOFILEDIR
		nice $SRTM2SDF_CMD -d /dev/null $HGTFILE
		cd -
		echo "compressing.."
		#sadly i am too lazy to figure out srtm2sdf naming schemes
		for SDF in $TOPOFILEDIR/*.sdf
		do   
                    if test -f "$SDF" 
                    then
                        echo "Compress $SDF"
                        nice bzip2 -f -- $SDF
                    fi
                done
		echo "deleting hgt file $TOPOFILEDIR/$HGTFILE"
		rm $TOPOFILEDIR/$HGTFILE
	fi
    fi
done

# TODO
rm $INDEXFILE
rm $FILELIST


#nothing to do in direct conversion mode
if [ "$DIRECT_CONVERSION" = true ] ;
then
    exit 0;
fi


# to minimize disk space required, run srtm2sdf on each file as it is unzipped.

echo "unpacking hgt files.."
cd $HGTFILEDIR
for e in *.zip ; do 
	echo $e
	nice unzip -o $e
	HGTFILE=`echo $e | sed -r -e 's/\.?hgt.zip/.hgt/'`
	if [ -r $HGTFILE ]; then
		cd $TOPOREALPATH
		nice $SRTM2SDF_CMD -d /dev/null $HGTREALPATH/$HGTFILE
		echo "compressing.."
		nice bzip2 -f -- *.sdf
		echo "deleting hgt file.."
		cd $HGTREALPATH
		rm $HGTFILE
	fi
done

cd $PWD

echo "Complete.  The files in $HGTFILEDIR may be removed."


