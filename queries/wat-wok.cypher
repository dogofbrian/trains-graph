// PART 2 - different juxtapositions
MATCH (wat:Station {name: "LONDON WATERLOO"}), 
      (wok:Station {name: "WOKING"})
MATCH (wat)<-[:CALLS_AT]-(a)((:Stop)-[:NEXT]->(:Stop))+(b)-[:CALLS_AT]->(wok)
WHERE time('09:10') < a.departs < time('09:40') 
RETURN a.departs AS departureTime,
duration.between(a.departs, b.arrives).minutes AS journeyTime
ORDER BY a.departs;
// +----------------------------------------+
// | departureTime | journeyTime | numStops |
// +----------------------------------------+
// | 09:20Z        | 25          | 1        |
// | 09:20Z        | 48          | 12       |
// | 09:24Z        | 35          | 3        |
// | 09:30Z        | 24          | 1        |
// | 09:35Z        | 23          | 1        |
// +----------------------------------------+

MATCH (wat:Station {name: "LONDON WATERLOO"}), 
      (wok:Station {name: "WOKING"})
MATCH p = (wat)<-[:CALLS_AT]-(a)((:Stop)-[:NEXT]->(:Stop))+(b)-[:CALLS_AT]->(wok)
WHERE time('09:10') < a.departs < time('09:40') 
RETURN a.departs AS departureTime,
duration.between(a.departs, b.arrives).minutes AS journeyTime,
size([r in relationships(p) WHERE r:NEXT | r]) AS numStops 
ORDER BY a.departs;

MATCH (wat:Station {name: "LONDON WATERLOO"}), (wok:Station {name: "WOKING"})
MATCH (wat)<-[:CALLS_AT]-(a)-[r:NEXT]->+(b)-[:CALLS_AT]->(wok)
WHERE time('09:10') < a.departs < time('09:40') 
RETURN a.departs AS departureTime,
duration.between(a.departs, b.arrives).minutes AS journeyTime,
size(r) AS numStops
ORDER BY a.departs;

// +----------------------------------------+
// | departureTime | journeyTime | numStops |
// +----------------------------------------+
// | 09:20Z        | 25          | 1        |
// | 09:20Z        | 48          | 12       |
// | 09:24Z        | 35          | 3        |
// | 09:30Z        | 24          | 1        |
// | 09:35Z        | 23          | 1        |
// +----------------------------------------+

MATCH (wat:Station {name: "LONDON WATERLOO"}), (wok:Station {name: "WOKING"})
MATCH p = (wat)<-[:CALLS_AT]-(a)((:Stop)-[:NEXT]->(right:Stop))+(b)-[:CALLS_AT]->(wok)
WHERE a.departs = time('09:20')
UNWIND right AS stop
MATCH (stop)-[:CALLS_AT]->(c)
RETURN collect(c.name) AS callingPoints;
// +----------------------------------------+
// | callingPoints                          |
// +----------------------------------------+
// | ["SURBITON", "WEST BYFLEET", "WOKING"] |
// +----------------------------------------+

MATCH (wat:Station {name: "LONDON WATERLOO"}), (wok:Station {name: "WOKING"})
MATCH p = (wat)<-[:CALLS_AT]-(a)((:Stop)-[:NEXT]->(right:Stop))+(b)-[:CALLS_AT]->(wok)
WHERE a.departs = time('09:20') AND size(right) > 1
UNWIND right AS stop
MATCH (stop)-[:CALLS_AT]->(c)
RETURN c.name AS callingPoints;

MATCH (wat:Station {name: "LONDON WATERLOO"}), (wok:Station {name: "WOKING"})
MATCH p = (wat)<-[:CALLS_AT]-(a)((left:Stop)-[:NEXT]->(right:Stop))+(b)-[:CALLS_AT]->(wok)
WHERE a.departs = time('09:24')
UNWIND [n in nodes(p) WHERE n:Stop | n] AS pStop MATCH (pStop)-[:CALLS_AT]->(c) WITH left, right, collect(c.name) AS pStations
UNWIND right AS stop MATCH (stop)-[:CALLS_AT]->(c) WITH left, collect(c.name) AS rightStations, pStations
UNWIND left AS stop MATCH (stop)-[:CALLS_AT]->(c) WITH collect(c.name) AS leftStations, rightStations, pStations
RETURN pStations, leftStations, rightStations;
// +------------------------------------------------------------------------------------------------------------------------------------------------------+
// | pStations                                                 | leftStations                                    | rightStations                          |
// +------------------------------------------------------------------------------------------------------------------------------------------------------+
// | ["LONDON WATERLOO", "SURBITON", "WEST BYFLEET", "WOKING"] | ["LONDON WATERLOO", "SURBITON", "WEST BYFLEET"] | ["SURBITON", "WEST BYFLEET", "WOKING"] |
// +------------------------------------------------------------------------------------------------------------------------------------------------------+

MATCH (wat:Station {name: "LONDON WATERLOO"}), (wok:Station {name: "WOKING"})
MATCH p = (wat)<-[:CALLS_AT]-(a)((l:Stop)-[:NEXT]->(r:Stop))+(b)-[:CALLS_AT]->(wok)
WHERE a.departs = time('09:24')
UNWIND r AS s MATCH (s)-[:CALLS_AT]->(c) WITH l, collect(c.name) AS rs, p
UNWIND l AS s MATCH (s)-[:CALLS_AT]->(c) WITH collect(c.name) AS ls, rs, p
UNWIND [n in nodes(p) WHERE n:Stop | n] AS pStop MATCH (pStop)-[:CALLS_AT]->(ps) 
RETURN ps.name, ps.name in ls AS `LHS?`, ps.name in rs AS `RHS?`;
// +------------------------------------------+
// | pStation.name     | p    | left  | right |
// +------------------------------------------+
// | "LONDON WATERLOO" | TRUE | TRUE  | FALSE |
// | "SURBITON"        | TRUE | TRUE  | TRUE  |
// | "WEST BYFLEET"    | TRUE | TRUE  | TRUE  |
// | "WOKING"          | TRUE | FALSE | TRUE  |
// +------------------------------------------+
