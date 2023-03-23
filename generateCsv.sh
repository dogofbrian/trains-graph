#!/bin/bash
# Uses python 3
importDir=~/neo4j/neo4j-enterprise-5.6.0/import/
outputDir=output
tempDir=temp
asAtDate=230117
sourceSchedulesFile=data/RJTTF622.MCA
sourceDistancesFile=data/RJRG0731.RGD
locationsSourceFile=data/locations.csv
locationsExtraSourceFile=data/locations_extra.csv
stationsFile=$tempDir/stations
schedulesFile=$tempDir/schedules
basicSchedulesFile=$tempDir/basicSchedules
hasLinkFile=$tempDir/hasLink
distancesFile=$outputDir/distances.csv

rm -rf $outputDir/*
rm -rf $tempDir/*

# build the distances file - doesn't need python
echo 'origin,destination,distanceMiles' > $distancesFile
grep -E '^[[:upper:]]+,[[:upper:]]+,[[:digit:]\.]' $sourceDistancesFile >> $distancesFile

# build the hasLink file, so we add Stations that are physically on the network but currently don't 
# have any stop scheduled
((tail -n +2 $distancesFile | tee >(cut -d, -f1 >&3) >(cut -d, -f2 >&4) 1>/dev/null) 3>&1 4>&1) | \
    sort | uniq > $hasLinkFile

# for processing speed, let's have a list of all the basic schedules, from which we
# can (in python) work out the list of applicable schedules
grep -E '^BS' $sourceSchedulesFile > $basicSchedulesFile

# split files into TI vs BS|BX|LO|LI|LT
grep '^TI' $sourceSchedulesFile > $stationsFile
grep -E '^(BS|BX|LO|LI|LT)' $sourceSchedulesFile > $schedulesFile
python convertTimetable.py $stationsFile $schedulesFile $hasLinkFile $basicSchedulesFile $outputDir $asAtDate

cp data/operators.csv $outputDir/

# remove unwanted columns and remove obvious inapplicable locations
echo 'tiplocCode,name,longitude,latitude' > $outputDir/locations.csv
grep -E '^9100[[:alpha:]]' $locationsSourceFile | cut -c 5- | cut -d, -f1,5,30,31 | grep -v -E ',,$' \
    >> $outputDir/locations.csv
cat $locationsExtraSourceFile >> $outputDir/locations.csv

cp $outputDir/* "$importDir"
