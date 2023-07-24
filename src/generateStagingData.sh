#!/bin/bash

scriptDir="$(dirname "$0")"

importDir=${1:-"$HOME/neo4j/neo4j-enterprise-5.11.0/import/"}
asAtDate=${2:-230117}

dataDir=$scriptDir/../data
stagingDir=$scriptDir/../staging
tempDir=$scriptDir/../temp
sourceSchedulesFile=$dataDir/RJTT*.MCA
sourceDistancesFile=$dataDir/RJRG*.RGD
stationGroupsFile=$dataDir/RJRG*.RGS
groupsFile=$dataDir/RJRG*.RGG

locationsSourceFile=$dataDir/locations.csv
locationsExtraSourceFile=$dataDir/locations_extra.csv
operatorsSourceFile=$dataDir/operators.csv

stationsFile=$tempDir/stations
schedulesFile=$tempDir/schedules
basicSchedulesFile=$tempDir/basicSchedules
hasLinkFile=$tempDir/hasLink

operatorsStagingFile=$stagingDir/staging_opertors.csv
distancesStagingFile=$stagingDir/staging_distances.csv
locationsFile=$stagingDir/staging_locations.csv
stationsGroupFile=$stagingDir/staging_stationGroups.csv

rm -rf $stagingDir/*
rm -rf $tempDir/*

# NO PYTHON
# Data = Distances
echo 'origin,destination,distanceMiles' > $distancesStagingFile
grep -E '^[[:upper:]]+,[[:upper:]]+,[[:digit:]\.]' $sourceDistancesFile >> $distancesStagingFile

# Data = Operators
cp $operatorsSourceFile $operatorsStagingFile

# Data = Locations
# remove unwanted columns and remove obvious inapplicable locations
echo 'tiplocCode,name,longitude,latitude' > $locationsFile
grep -E '^9100[[:alpha:]]' $locationsSourceFile | cut -c 5- | cut -d, -f1,5,30,31 | grep -v -E ',,$' \
    >> $locationsFile
cat $locationsExtraSourceFile >> $locationsFile

# Data = StationGroups
echo 'crsCode,routePoint1,routePoint1,routePoint1,routePoint1,groupCode' > $stationsGroupFile
sed 's/\r//g' $stationGroupsFile | grep -v ,$ | grep -v ^/ >> $stationsGroupFile

# PYTHON NEEDED
# build the hasLink file, so we add Stations that are physically on the network but currently don't 
# have any stop scheduled
((tail -n +2 $distancesStagingFile | tee >(cut -d, -f1 >&3) >(cut -d, -f2 >&4) 1>/dev/null) 3>&1 4>&1) | \
    sort | uniq > $hasLinkFile

# for processing speed, let's have a list of all the basic schedules, from which we
# can (in python) work out the list of applicable schedules
grep -E '^BS' $sourceSchedulesFile > $basicSchedulesFile

# split files into TI vs BS|BX|LO|LI|LT
grep '^TI' $sourceSchedulesFile > $stationsFile
grep -E '^(BS|BX|LO|LI|LT)' $sourceSchedulesFile > $schedulesFile

# Data = Routes, Stops, Stations
python $scriptDir/generateSchedules.py $stationsFile $schedulesFile $hasLinkFile $basicSchedulesFile $stagingDir $asAtDate

# Data = Groups
python $scriptDir/generateGroups.py $groupsFile $stagingDir

# Copy all the generated CSV files over to the directory for import into Neo4j
cp $stagingDir/* "$importDir"
