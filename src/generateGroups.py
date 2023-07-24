import sys
from csvFile import writeLine

groupsFile = sys.argv[1]
outdir = sys.argv[2]

groupsOutFile = f'{outdir}/staging_groups.csv'

def parseGroupStations(groupsFile):
    groups = []
    with open(groupsFile) as infile:
        for line in infile:
            lineStart = line[:1]
            match lineStart:
                case '/':
                    if line[2] != '!':
                        groupName = line[2:].strip()
                case 'G':
                    groupCode = line[:3]
                    groups.append([groupCode, groupName])
    return groups
    

groups = parseGroupStations(groupsFile)

with open(groupsOutFile, 'w') as outfile:
    outfile.write('groupCode,groupName\n')
    for group in groups:
        writeLine(outfile, group)
