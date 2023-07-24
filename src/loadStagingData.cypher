MATCH (n) DETACH DELETE n;

LOAD CSV WITH HEADERS FROM "file:///staging_stations.csv" AS row
CREATE (n:Station)
SET n = row;

CREATE INDEX station_tiplocCode IF NOT EXISTS FOR (s:Station) ON (s.tiplocCode);
CREATE INDEX station_crsCode IF NOT EXISTS FOR (s:Station) ON (s.crsCode);
CREATE INDEX station_name IF NOT EXISTS FOR (s:Station) ON (s.name);

LOAD CSV WITH HEADERS FROM "file:///staging_distances.csv" AS row
CALL {
    WITH row
    MATCH (origin:Station), (destination:Station)
    WHERE origin.crsCode = row.origin AND destination.crsCode = row.destination
    AND NOT EXISTS { (origin)-[:LINK]-(destination) } 
    CREATE (origin)-[:LINK {distance: toFloat(row.distanceMiles)}]->(destination)
} IN TRANSACTIONS OF 1000 ROWS;

LOAD CSV WITH HEADERS FROM "file:///staging_locations.csv" AS row
CALL {
    WITH row
    MATCH (s:Station) WHERE s.tiplocCode = row.tiplocCode
    SET s.location = point({longitude: toFloat(row.longitude), latitude: toFloat(row.latitude)})
} IN TRANSACTIONS OF 1000 ROWS;

LOAD CSV WITH HEADERS FROM "file:///staging_routes.csv" AS row
CALL {
    WITH row
    CREATE (n:CallingPoint)
    SET n.routeId = toInteger(row.routeId),
        n.routeName = row.routeName,
        n.id = toInteger(row.id),
        n.stopNumber = toInteger(row.stopNumber),
        n.tiplocCode = row.tiplocCode
} IN TRANSACTIONS OF 1000 ROWS;

MATCH (c:CallingPoint), (s:Station) 
WHERE c.tiplocCode = s.tiplocCode
CALL {
    WITH c, s
    CREATE (c)-[:CALLS_AT]->(s)
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM "file:///staging_stops.csv" AS row
CALL {
    WITH row
    CREATE (n:Stop)
    SET n.callingPointId = toInteger(row.callingPointId),
        n.serviceId = toInteger(row.serviceId),
        n.stopNumber = toInteger(row.stopNumber)
    WITH row, n
    CALL {
        WITH row, n
        WITH row, n WHERE row.arrives <> ''
        SET n.arrives = time(row.arrives)
    }
    CALL {
        WITH row, n
        WITH row, n WHERE row.departs <> ''
        SET n.departs = time(row.departs)
    }
} IN TRANSACTIONS OF 500 ROWS;

MATCH (s:Stop), (c:CallingPoint)
WHERE c.id = s.callingPointId
CREATE (c)-[:HAS]->(s)
REMOVE s.callingPointId;

MATCH (c1:CallingPoint), (c2:CallingPoint) 
WHERE c1.routeId = c2.routeId AND c2.stopNumber = c1.stopNumber + 1
CALL {
    WITH c1, c2
    CREATE (c1)-[:NEXT]->(c2)
} IN TRANSACTIONS OF 100000 ROWS;

MATCH (c:CallingPoint)
REMOVE c.routeId, c.id, c.tiplocCode;

MATCH (s1:Stop), (s2:Stop) 
WHERE s1.serviceId = s2.serviceId AND s2.stopNumber = s1.stopNumber + 1
CALL {
    WITH s1, s2
    CREATE (s1)-[:NEXT]->(s2)
} IN TRANSACTIONS OF 100000 ROWS;

MATCH (s:Stop)
REMOVE s.serviceId;

// Merge stations without CRS or once of the Z that are very close
// to stations that have CRS
// Reconnect Service-{Origin,Destination}
// Reconnect <-[:CALLS_AT]-(:Stop)
MATCH (s:Station), (t:Station)
WHERE s <> t
  AND point.distance(s.location, t.location) < 150
  AND NOT EXISTS {(s)-[:LINK]-()} 
  AND EXISTS {(s)<-[:CALLS_AT]-()} 
  AND EXISTS {(t)-[:LINK]-()}
  AND (s.crsCode is NUll or left(s.crsCode,1) = 'Z')
CALL {
    WITH s, t
    MATCH (a:CallingPoint)-[c:CALLS_AT]->(s)
    CREATE (a)-[:CALLS_AT]->(t)
    DELETE c
};

LOAD CSV WITH HEADERS FROM "file:///staging_stationGroups.csv" AS row
MATCH (s:Station)
WHERE s.crsCode = row.crsCode
SET s.groupCode = row.groupCode;

LOAD CSV WITH HEADERS FROM "file:///staging_groups.csv" AS row
MATCH (s:Station)
WHERE s.groupCode = row.groupCode
SET s.groupName = row.groupName;

