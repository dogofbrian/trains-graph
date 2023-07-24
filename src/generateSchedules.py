import sys
from re import sub
from stations import parseStations
from schedules import parseSchedules
from csvFile import writeLine

stationsInfile = sys.argv[1]
schedulesFile = sys.argv[2]
hasLinkFile = sys.argv[3]
basicSchedulesFile = sys.argv[4]
outdir = sys.argv[5]
asAtDateStr = sys.argv[6]

routesOutFile = f'{outdir}/staging_routes.csv'
stopsOutFile = f'{outdir}/staging_stops.csv'
stationsOutFile = f'{outdir}/staging_stations.csv'

stationStopWords = ["DC", "ELL", "HL", "LL", "LT", "LUL", "NLL", "PW"]

def normaliseStationName(name: str):
    return sub(r"[A-Za-z]+('[A-Za-z]+)?",
            lambda mo: mo.group(0).capitalize() if mo.group(0) not in stationStopWords else mo.group(0),
            name)

callingPoints, stops, hasStop = parseSchedules(schedulesFile, basicSchedulesFile, asAtDateStr)
stations, tiplocToName = parseStations(stationsInfile, hasLinkFile, hasStop)

with open(stationsOutFile, 'w') as outfile:
    outfile.write('tiplocCode,crsCode,name\n')
    for stationName, station in stations.items():
        writeLine(outfile, [station['tiplocCode'], station.get('crsCode', ''), f'"{normaliseStationName(stationName)}"'])

# services are composed of stops that belong to calling points
with open(stopsOutFile, 'w') as outfile:
    outfile.write('callingPointId,serviceId,stopNumber,arrives,departs\n')
    for stop in stops:
        callingPointId = str(hash(stop['callingPointId']))
        serviceId = str(hash(stop['serviceId']))
        writeLine(outfile, [callingPointId, serviceId, str(stop['stopNumber']), stop['arrives'], stop['departs']])

# routes are composed of calling points
with open(routesOutFile, 'w') as outfile:
    outfile.write('routeId,routeName,id,stopNumber,tiplocCode\n')
    for point in callingPoints:
        toName = tiplocToName[point['tiplocCode']]
        stationName = toName['name']
        resolvedTiplocCode = stations[stationName]['tiplocCode']
        routeId = str(hash(point['routeId']))
        id = str(hash(point['id']))
        writeLine(outfile, [routeId, point['routeName'], id, str(point['stopNumber']), resolvedTiplocCode])


