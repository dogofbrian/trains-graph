import pandas as pd

# list of annoying, rogue CRS codes that aren't actually in use but appear in the schedule
crsDenyList = {'HII', 'XMR', 'RDZ', 'SPL', 'XUP'}

def removeDenyListedStation(crs):
    return '' if crs in crsDenyList else crs

# different tiplocs => normalised tiploc
stations = dict()
tiplocToName = dict()
nameToCrsCode = dict()

def parseStations(stationsInfile, hasLinkFile, hasStop):
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

    # clean up the station names
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

    return stations, tiplocToName
