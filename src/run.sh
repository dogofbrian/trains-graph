#!/bin/bash
# Requires at python 3.10+
# This takes the externally source railway data files and:
# 
#   1. transforms them into the csv files to be loaded into the staging database
#   2. loads them into the staging database, with manipulations
#   3. exports the now lovely data as csv files into the data/ directory of the shareable repo
#   4. copies those clean csv files to the import directory of the running neo4j instance
#   5. runs the import Cypher script in the shareable repo to load those clean csv files
# 
# Doing this end-to-end both satisfies my laziness and proves it will work for the end user
# of the shareable repo
scriptDir="$(dirname "$0")"

neoRoot="$HOME"/neo4j/neo4j-enterprise-5.11.0
importDir="$neoRoot"/import/
targetProject="$HOME"/Projects/ukrailway
outputDir="$targetProject"/data/
importScript="$targetProject"/import.cypher
url="neo4j://localhost:7687"
user=neo4j
password=password
stagingDatabase=staging
targetDatabase=trains
asAtDate=230117

./generateStagingData.sh $importDir $asAtDate
python ./loadStagingData.py $url $user $password $stagingDatabase
rm -rf "$outputDir"/data/*
python ./exportCleanData.py "$outputDir" $url $user $password $stagingDatabase 

cp "$outputDir"/* "$neoRoot"/import/
"$neoRoot"/bin/cypher-shell -d $targetDatabase -u $user -p $password -f "$importScript"