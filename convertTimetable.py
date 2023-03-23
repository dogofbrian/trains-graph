import sys
import pandas as pd
from datetime import datetime

def writeCsvLine(file, data):
    file.write(','.join(data) + '\n')

def coalesce(*values):
    return next((v for v in values if v is not None), None)

def getStationCode(tiplocCode):
    return coalesce(stations[tiplocCode], tiplocCode)

def toDate(yymmdd):
    return datetime.strptime(yymmdd, '%y%m%d').date()

stationsInfile = sys.argv[1]
schedulesFile = sys.argv[2]
hasLinkFile = sys.argv[3]
basicSchedulesFile = sys.argv[4]
outdir = sys.argv[5]
asAtDateStr = sys.argv[6]

asAtDate = toDate(asAtDateStr)
asAtWeekday = asAtDate.weekday()
stopsFilePath = f'{outdir}/stops.csv'
stationsFilePath = f'{outdir}/stations.csv'
pathsFilePath = f'{outdir}/paths.csv'
servicesFilePath = f'{outdir}/services.csv'

# work out the applicable basic schedules with following logic:
# - the set of schedules that relate all have the same UID (chars 3-9)
# - eliminate all that don't have applicable date range including the asAtDate
# - eliminate all that don't apply to the weekday of the asAtDate
# - if the last record is a cancellation (last char C) then the schedule doesn't apply
# - else the last record is the applicable one (whether P, O, N)
def scheduleAppliesToAsDate(line):
    applicableFromDate = toDate(line[9:15])
    applicableToDate = toDate(line[15:21])
    return applicableFromDate <= asAtDate <= applicableToDate

def scheduleWeekdayApplies(line):
    weekdayMask = line[21:28]
    return bool(int(weekdayMask[asAtWeekday]))

def isPassengerTrain(line):
    return not (line[29:30] in ['B','F','S','2','4','5'])

def isApplicableSchedule(line):
    return isPassengerTrain(line) and scheduleAppliesToAsDate(line) and scheduleWeekdayApplies(line)

applicableSchedulesByUid = dict()
with open(basicSchedulesFile) as infile:
    for line in infile:
        if isApplicableSchedule(line):
            uid = line[3:9]
            applicableSchedulesByUid[uid] = line

applicableSchedules = set(applicableSchedulesByUid.values())

# list of annoying, rogue CRS codes that aren't actually in use but appear in the schedule
crsDenyList = {'HII', 'XMR', 'RDZ', 'SPL', 'XUP'}

hasStop = set()
stops = []
def addStop(tiplocCode, stopNumber, pathId, arrives, departs):
    hasStop.add(tiplocCode)
    stops.append({'stopNumber': str(stopNumber), 'pathId': pathId, 'tiplocCode': tiplocCode, 'arrives': arrives, 'departs': departs})

paths = []
services = dict()
with open(schedulesFile) as infile:
    skip = False
    for line in infile:
        recordType = line[:2]
        match recordType:
            # BS = basic schedule
            case 'BS':
                if line in applicableSchedules:
                    if line[79:80] in ['C']:
                        skip = True
                    else:
                        skip = False
                        path = {'id': line[3:9]}
                else:
                    skip = True
            # BX = basic schedule extra details
            case 'BX':
                if not skip:
                    retailServiceId = line[14:22].strip()
                    path['retailServiceId'] = retailServiceId
                    service = {}
                    service['retailServiceId'] = retailServiceId
                    service['atocCode'] = line[11:13].strip()
            # LO = origin location
            case 'LO':
                if not skip:
                    stopNumber = 0
                    tiplocCode = line[2:9].strip()
                    path['origin'] = tiplocCode
                    path['departs'] = line[15:19]
                    service['origin'] = tiplocCode
                    addStop(
                        tiplocCode=tiplocCode, 
                        stopNumber=stopNumber,
                        pathId=path['id'],
                        arrives='',
                        departs=line[15:17] + ':' + line[17:19])
            # LI = intermediate location
            case 'LI':
                if not skip:
                    # activity code T indicates passengers can alight / aboard at this inter
                    # code R means it optionally stops
                    if line[42:44] in ['T ', 'R ']:
                        stopNumber += 1 
                        addStop(
                            tiplocCode=line[2:9].strip(), 
                            stopNumber=stopNumber,
                            pathId=path['id'],
                            arrives=line[25:27] + ':' + line[27:29],
                            departs=line[29:31] + ':' + line[31:33])
            # LT = terminating location
            case 'LT':
                if not skip:
                    stopNumber += 1
                    tiplocCode = line[2:9].strip()
                    path['destination'] = tiplocCode
                    paths.append(path)
                    service['destination'] = tiplocCode
                    # We want to make unique by retailServiceId
                    services[service['retailServiceId']] = service 
                    addStop(
                        tiplocCode=line[2:9].strip(), 
                        stopNumber=stopNumber,
                        pathId=path['id'],
                        arrives=line[15:17] + ':' + line[17:19],
                        departs='')

def removeDenyListedStation(crs):
    return '' if crs in crsDenyList else crs

# different tiplocs => normalised tiploc
stations = dict()
tiplocToName = dict()
nameToCrsCode = dict()

with open(stationsInfile) as infile:
    for line in infile:
        name1 = line[18:44].strip()
        name2 = line[56:72].strip()
        tiplocCode = line[2:9].strip()
        crsCode = removeDenyListedStation(line[53:56].strip())
        
        # we have a clash and need to find two different names to map
        if crsCode != '' and name1 in nameToCrsCode.keys():
            # we need to fix the existing entry and use a different tiploc => name mapping, so they resolve to different stations
            for otherTiplocCode, value in tiplocToName.items():
                if value['name'] == name1:
                    curOtherStationName = value['name']
                    newOtherStationName = value.get('name2')
                    if newOtherStationName is None:
                        raise RuntimeError(f'Problem trying to swap name {curOtherStationName} due to tiplocToName clash, no backup name available')
                    tiplocToName[otherTiplocCode] = { 'name': newOtherStationName, 'isPrimary': True }
                    otherCrsCode = nameToCrsCode.pop(curOtherStationName)
                    nameToCrsCode[newOtherStationName] = otherCrsCode
                    break
            tiplocToName[tiplocCode] = { 'name': name2, 'isPrimary': True }
            nameToCrsCode[name2] = crsCode
        elif crsCode != '':
            tiplocToName[tiplocCode] = { 'name': name1, 'name2': name2, 'isPrimary': True }
            nameToCrsCode[name1] = crsCode
        else:
            tiplocToName[tiplocCode] = { 'name': name1, 'name2': name2, 'isPrimary': False }

hasLinkDf = pd.read_csv(hasLinkFile, header=None)
def hasLink(crs):
    return crs is not None and crs in hasLinkDf[0].values

for tiplocCode, toName in tiplocToName.items():
    name = toName['name']
    crsCode = nameToCrsCode.get(name)

    # only handle stations that have a CRS code or have a train calling at them 
    # (for those stations that don't have a CRS code)
    if hasLink(crsCode) or tiplocCode in hasStop:
        station = stations.get(name)
        if station is None:
            station = { 'tiplocCode': tiplocCode }
            if crsCode is not None:
                station['crsCode'] = crsCode
            stations[name] = station
        elif crsCode is not None:
            if station['crsCode'] is None:
                station['crsCode'] = crsCode
            if toName['isPrimary']:
                station['tiplocCode'] = tiplocCode

with open(stationsFilePath, 'w') as outfile:
    outfile.write('tiplocCode,crsCode,name\n')
    for stationName, station in stations.items():
        writeCsvLine(outfile, [station['tiplocCode'], station.get('crsCode', ''), f'"{stationName}"'])

with open(pathsFilePath, 'w') as outfile:
    outfile.write('id,name,retailServiceId\n')
    for path in paths:
        pathName = f'{path["origin"]}-{path["destination"]}-{path["departs"]}'
        writeCsvLine(outfile, [path['id'], pathName, path['retailServiceId']])

with open(stopsFilePath, 'w') as outfile:
    outfile.write('stopNumber,pathId,tiplocCode,arrives,departs\n')
    for stop in stops:
        toName = tiplocToName[stop['tiplocCode']]
        stationName = toName['name']
        resolvedTiplocCode = stations[stationName]['tiplocCode']
        writeCsvLine(outfile, [stop['stopNumber'], stop['pathId'], resolvedTiplocCode, stop['arrives'], stop['departs']])

with open(servicesFilePath, 'w') as outfile:
    outfile.write('retailServiceId,atocCode,origin,destination\n')
    for s in services.values():
        writeCsvLine(outfile, [s['retailServiceId'], s['atocCode'], s['origin'], s['destination']])
