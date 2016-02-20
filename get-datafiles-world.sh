#!/bin/sh

# License: Public domain / CC-0

./get-datafiles-northamerica.sh
./get-datafiles.sh -c "South_America"
./get-datafiles.sh -c "Africa"
./get-datafiles.sh -c "Eurasia"
./get-datafiles.sh -c "Australia"
./get-datafiles.sh -c "Islands"


