from datetime import datetime
from hashlib import sha256

# work out the applicable basic schedules with following logic:
# - the set of schedules that relate all have the same UID (chars 3-9)
# - eliminate all that don't have applicable date range including the asAtDate
# - eliminate all that don't apply to the weekday of the asAtDate
# - if the last record is a cancellation (last char C) then the schedule doesn't apply
# - else the last record is the applicable one (whether P, O, N)
def toDate(yymmdd):
    return datetime.strptime(yymmdd, '%y%m%d').date()

def isPassengerTrain(line):
    return not (line[29:30] in ['B','F','S','2','4','5'])

def parseApplicableSchdules(basicSchedulesFile, asAtDateStr):
    asAtDate = toDate(asAtDateStr)
    asAtWeekday = asAtDate.weekday()

    def scheduleAppliesToAsDate(line):
        applicableFromDate = toDate(line[9:15])
        applicableToDate = toDate(line[15:21])
        return applicableFromDate <= asAtDate <= applicableToDate

    def scheduleWeekdayApplies(line):
        weekdayMask = line[21:28]
        return bool(int(weekdayMask[asAtWeekday]))

    def isApplicableSchedule(line):
        return isPassengerTrain(line) and scheduleAppliesToAsDate(line) and scheduleWeekdayApplies(line)

    applicableSchedulesByUid = dict()
    with open(basicSchedulesFile) as infile:
        for line in infile:
            if isApplicableSchedule(line):
                uid = line[3:9]
                applicableSchedulesByUid[uid] = line

    return set(applicableSchedulesByUid.values())

def generateRouteName(routeTiplocCodes):
    origin = routeTiplocCodes[0]
    destination = routeTiplocCodes[-1]
    hash = sha256(str(routeTiplocCodes).encode('utf-8')).hexdigest()[:6].upper()
    return origin + '-' + destination + '-' + hash

def parseSchedules(schedulesFile, basicSchedulesFile, asAtDateStr):
    hasStop = set()
    hasRoute = set()
    callingPoints = []
    stops = []
    
    applicableSchedules = parseApplicableSchdules(basicSchedulesFile, asAtDateStr)

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

                            # NEW
                            # tiplocs = []
                            routeCallingPoints = []
                            routeStops = []
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
                        arrives = ''
                        departs = line[15:17] + ':' + line[17:19]
                        serviceStart = departs
                        
                        # NEW
                        hasStop.add(tiplocCode)
                        routeTiplocCodes = [tiplocCode]
                        routeCallingPoints.append({
                            'stopNumber': str(stopNumber),
                            'tiplocCode': tiplocCode
                            })
                        routeStops.append({
                            'stopNumber': str(stopNumber),
                            'arrives': arrives,
                            'departs': departs
                            })

                # LI = intermediate location
                case 'LI':
                    if not skip:
                        # activity code T indicates passengers can alight / aboard at this inter
                        # code R means it optionally stops
                        if line[42:44] in ['T ', 'R ']:
                            stopNumber += 1
                            tiplocCode=line[2:9].strip()
                            arrives=line[25:27] + ':' + line[27:29]
                            departs=line[29:31] + ':' + line[31:33]
                            
                            hasStop.add(tiplocCode)
                            routeTiplocCodes.append(tiplocCode)
                            routeCallingPoints.append({
                                'stopNumber': str(stopNumber),
                                'tiplocCode': tiplocCode
                            })
                            routeStops.append({
                                'stopNumber': str(stopNumber), 
                                'arrives': arrives, 
                                'departs': departs
                            })
                            
                # LT = terminating location
                case 'LT':
                    if not skip:
                        stopNumber += 1
                        tiplocCode = line[2:9].strip()
                        arrives=line[15:17] + ':' + line[17:19]

                        routeTiplocCodes.append(tiplocCode)
                        routeCallingPoints.append({
                            'stopNumber': str(stopNumber),
                            'tiplocCode': tiplocCode
                            })
                        routeStops.append({
                            'stopNumber': str(stopNumber), 
                            'arrives': arrives, 
                            'departs': departs
                            })
                        
                        routeId = tuple(routeTiplocCodes)
                        routeName = generateRouteName(routeTiplocCodes)
                        serviceId = routeId + tuple([serviceStart])

                        hasStop.add(tiplocCode)
                        
                        if routeId not in hasRoute:
                            hasRoute.add(routeId)
                            for callingPoint in routeCallingPoints:
                                stopNumber = callingPoint['stopNumber']
                                id = routeId + tuple([stopNumber])
                                callingPoints.append({
                                    'routeId': routeId,
                                    'routeName': routeName,
                                    'id': id,
                                    'stopNumber': stopNumber,
                                    'tiplocCode': callingPoint['tiplocCode']
                                })

                        for stop in routeStops:
                            stopNumber = stop['stopNumber']
                            callingPointId = routeId + tuple([stopNumber])
                            stops.append({
                                'callingPointId': callingPointId,
                                'serviceId': serviceId,
                                'stopNumber': stopNumber,
                                'arrives': stop['arrives'],
                                'departs': stop['departs']
                            })

    return callingPoints, stops, hasStop
