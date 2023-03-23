    LOAD CSV WITH HEADERS FROM "file:///operators.csv" AS row
    CREATE (n:Operator)
    SET n = row;

    LOAD CSV WITH HEADERS FROM "file:///paths.csv" AS row
    CREATE (n:Path)
    SET n = row;

    LOAD CSV WITH HEADERS FROM "file:///stations.csv" AS row
    CREATE (n:Station)
    SET n = row;

    LOAD CSV WITH HEADERS FROM "file:///services.csv" AS row
    CALL {
        WITH row
        CREATE (n:Service)
        SET n = row
    } IN TRANSACTIONS OF 500 ROWS;

    LOAD CSV WITH HEADERS FROM "file:///stops.csv" AS row
    CALL {
        WITH row
        CREATE (n:Stop)
        SET n.pathId = row.pathId,
            n.tiplocCode = row.tiplocCode,
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

    LOAD CSV WITH HEADERS FROM "file:///distances.csv" AS row
    CALL {
        WITH row
        MATCH (origin:Station), (destination:Station)
        WHERE origin.crsCode = row.origin AND destination.crsCode = row.destination
        AND NOT EXISTS { (origin)-[:LINK]-(destination) } 
        CREATE (origin)-[:LINK {distance: toFloat(row.distanceMiles)}]->(destination)
    } IN TRANSACTIONS OF 1000 ROWS;

    LOAD CSV WITH HEADERS FROM "file:///locations.csv" AS row
    CALL {
        WITH row
        MATCH (s:Station) WHERE s.tiplocCode = row.tiplocCode
        SET s.location = point({longitude: toFloat(row.longitude), latitude: toFloat(row.latitude)})
    } IN TRANSACTIONS OF 1000 ROWS;

    CREATE INDEX operator_atocCode IF NOT EXISTS FOR (o:Operator) ON (o.atocCode);
    CREATE INDEX station_tiplocCode IF NOT EXISTS FOR (s:Station) ON (s.tiplocCode);
    CREATE INDEX station_crsCode IF NOT EXISTS FOR (s:Station) ON (s.crsCode);
    CREATE INDEX service_retailServiceId IF NOT EXISTS FOR (s:Service) ON (s.retailServiceId);
    CREATE INDEX path_id IF NOT EXISTS FOR (p:Path) ON (p.id);

    MATCH (s:Service), (o:Operator) 
    WHERE s.atocCode = o.atocCode
    CREATE (o)-[:OPERATES]->(s)
    REMOVE s.atocCode;

    MATCH (s:Service), (t:Station)
    WHERE s.origin = t.tiplocCode
    CREATE (s)-[:ORIGIN]->(t)
    REMOVE s.origin;

    MATCH (s:Service), (t:Station)
    WHERE s.destination = t.tiplocCode
    CREATE (s)-[:DESTINATION]->(t)
    REMOVE s.destination;

    MATCH (p:Path), (s:Service)
    WHERE p.retailServiceId = s.retailServiceId
    CREATE (s)-[:HAS]->(p)
    REMOVE p.retailServiceId;

    MATCH (s1:Stop), (s2:Stop) 
    WHERE s1.pathId = s2.pathId AND s2.stopNumber = s1.stopNumber + 1
    CALL {
        WITH s1, s2
        CREATE (s1)-[:NEXT]->(s2)
    } IN TRANSACTIONS OF 100000 ROWS;

    MATCH (s:Stop), (p:Path) 
    WHERE s.pathId = p.id
    CALL {
        WITH p, s
        CREATE (p)-[:HAS]->(s)
    } IN TRANSACTIONS OF 100000 ROWS;

    MATCH (s:Stop), (t:Station) 
    WHERE s.tiplocCode = t.tiplocCode
    CALL {
        WITH s, t
        CREATE (s)-[:CALLS_AT]->(t)
    } IN TRANSACTIONS OF 10000 ROWS;

    MATCH (s:Stop)
    CALL {
        WITH s
        REMOVE s.pathId, s.tiplocCode
    } IN TRANSACTIONS OF 100000 ROWS;
