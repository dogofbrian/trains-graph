# Description
This is a couple of simple scripts to transform Railway Delivery Group timetable and station link files into CSVs for consumption by a Cypher script that imports the data into a simple railway model. Relies on a few hand crafted files that supplement missing data and links. Oh and there are Operator and Location files as well.

# Quickstart
## Get the Rail Delivery Group timetable data sets
Register at https://opendata.nationalrail.co.uk

After logging in with new account, get a token:
```sh
curl --location \
     --request POST \
     'https://opendata.nationalrail.co.uk/authenticate' \
     --header 'Content-Type: application/x-www-form-urlencoded' \
     --data-urlencode 'username=<username>' \
     --data-urlencode 'password=<password>'
```
These are the APIs for the two dataset zips you need to download:

- https://opendata.nationalrail.co.uk/api/staticfeeds/2.0/routeing
- https://opendata.nationalrail.co.uk/api/staticfeeds/3.0/timetable

Run the following curl command to download them:

```sh
    curl -O --header User-Agent: \
    --header "Content-Type: application/json" \
    --header "X-Auth-Token: <username>:<token>" <URL>
```

Unzip each one. Then copy the following two files to the `data` directory:

- RJRGnnnn.RGD
- RJTTnnnn.MCA

## Generate the CSV files from the railway data sets

Then run the command `./generateCsv.sh <import directory> <as at date>` to generate the CSV files that will be imported. For example:

```sh
./generateCsv.sh ~/neo4j/neo4j-enterprise-5.7.0/import/ 230117
```

## Import the data to Neo4j
Then run the script `importTrains.cypher` against the target database.