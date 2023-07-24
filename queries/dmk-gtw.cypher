// Q1: what is the shortest route from Denmark Hill to Gatwick Airport?
MATCH (dmk:Station {name: 'Denmark Hill'}),
      (gtw:Station {name: 'Gatwick Airport'})
MATCH p = (dmk)-[link:LINK]-+(gtw)
RETURN reduce(acc = 0, l IN link | acc + l.distance) AS totalDistance,
       [n in nodes(p) | n.name] AS stations     
ORDER BY totalDistance LIMIT 1
;
// RESULT: runs out of memory

// Q2: give me an example of one of these random routes
MATCH (dmk:Station {name: 'Denmark Hill'})
MATCH (gtw:Station {name: 'Gatwick Airport'})
MATCH p = (dmk)-[:LINK]-+(gtw)
RETURN [n in nodes(p) | n.name] AS stations
LIMIT 1;
// RESULT: random route that meanders
["Denmark Hill", "Clapham High Street", "Wandsworth Road", "Battersea Park", "London Victoria", "Brixton", "Kensington (Olympia)", 
 "Acton Main Line", "Ealing Broadway", "West Ealing", "Hanwell", "Southall", "Hayes & Harlington", "West Drayton", "Iver", "Langley", 
 "Slough", "Burnham", "Taplow", "Maidenhead", "Twyford", "Reading", "Earley", "Winnersh Triangle", "Winnersh", "Wokingham", "Crowthorne", 
 "Sandhurst", "Blackwater", "Farnborough North", "North Camp", "Ash", "Aldershot", "Ash Vale", "Frimley", "Camberley", "Bagshot", 
 "Ascot", "Sunningdale", "Longcross", "Virginia Water", "Egham", "Staines", "Ashford (Middlesex)", "Feltham", "Whitton", "Twickenham", 
 "Strawberry Hill", "Fulwell", "Teddington", "Hampton Wick", "Kingston", "Norbiton", "New Malden", "Raynes Park", "Motspur Park", 
 "Worcester Park", "Stoneleigh", "Ewell West", "Epsom", "Ashtead", "Leatherhead", "Box Hill & Westhumble", "Dorking", "Holmwood", 
 "Ockley", "Warnham", "Horsham", "Littlehaven", "Faygate", "Ifield", "Crawley", "Three Bridges", "Gatwick Airport"]

// Q3: OK how fast do the number of routes grow with how bad is it?
MATCH (dmk:Station {name: 'Denmark Hill'}),
      (gtw:Station {name: 'Gatwick Airport'})
MATCH p = (dmk)-[:LINK]-{,25}(gtw)
RETURN size(relationships(p)) AS numStations, count(*) AS numRoutes
ORDER BY numStations ASC;
// RESULT: exponential growth in the number of routes, which is typical of a real-world graph like a transport network 
+-------------------------+
| numStations | numRoutes |
+-------------------------+
| 16          | 1         |
| 17          | 4         |
| 18          | 6         |
| 19          | 16        |
| 20          | 38        |
| 21          | 71        |
| 22          | 131       |
| 23          | 218       |
| 24          | 358       |
| 25          | 583       |
| 26          | 937       |
+-------------------------+

// Q4: we want an optimal graph? We don't just want the fewest number of hops, we want to know the physically shortest?
MATCH (dmk:Station {name: 'Denmark Hill'}),
      (gtw:Station {name: 'Gatwick Airport'})
MATCH p = (dmk) ((l)-[links:LINK]-(r) WHERE point.distance(r.location,gtw.location) < (point.distance(l.location, gtw.location) + 1000))+ (gtw)            
RETURN [n in nodes(p) | n.name] AS stations, 
       reduce(acc = 0.0, link IN links | round(acc + link.distance, 2)) AS distance 
ORDER BY distance LIMIT 1
+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| stations                                                                                                                                                                                                                                                                                      | numStops | distance           |
+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| ["Denmark Hill", "Brixton", "Herne Hill", "Tulse Hill", "West Norwood", "Gipsy Hill", "Crystal Palace", "Norwood Junction", "East Croydon", "South Croydon", "Purley Oaks", "Purley", "Coulsdon South", "Merstham", "Redhill", "Earlswood (Surrey)", "Salfords", "Horley", "Gatwick Airport"] | 19       | 24.410000000000004 |
+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
// for Bloom
MATCH (dmk:Station {name: 'Denmark Hill'})
MATCH (gtw:Station {name: 'Gatwick Airport'})
MATCH p = (dmk) ((l)-[links:LINK]-(r) WHERE point.distance(r.location,gtw.location) < (point.distance(l.location, gtw.location) + 1000))+ (gtw)            
WITH p, reduce(acc = 0, link IN links | acc + link.distance) AS distance ORDER BY distance LIMIT 1
RETURN p;

// Q4.0.1 - vanilla inlinable query
MATCH (dmk:Station {name: 'Denmark Hill'}),
      (gtw:Station {name: 'Gatwick Airport'})
MATCH p = (dmk)-[links:LINK*]-(gtw)
WHERE all(l IN links WHERE 51.47 > l.location.latitude > 51.15)
RETURN [n in nodes(p) | n.name] AS stations,
       reduce(acc = 0.0, link IN links | round(acc + link.distance, 2)) AS distance 
ORDER BY distance LIMIT 1;

// Q4.0.2 - vanilla inlinable query
MATCH p=(a:Station {name: 'Brixton'})-[link:LINK*1..]->(:Station {name: 'Loughborough Jn'})
WHERE all(l IN link WHERE endNode(l).name <> 'Herne Hill')
RETURN size(nodes(p));

// Q4.1 - what does this look like in var-length rel?
MATCH (dmk:Station {name: 'Denmark Hill'})
MATCH (gtw:Station {name: 'Gatwick Airport'})
MATCH p = (dmk)-[links:LINK*]-(gtw)
WHERE all(r IN relationships(p) WHERE ...)  // we can't use endNode or startNode as we need an undirected relationship pattern!

// Q4.2 - but maybe all is not lost. what if we iterate over the nodes?
MATCH (dmk:Station {name: 'Denmark Hill'}),
      (gtw:Station {name: 'Gatwick Airport'})
MATCH p = (dmk)-[links:LINK*..19]-(gtw)
WHERE all(i IN range(0, size(nodes(p)) - 2) WHERE point.distance(nodes(p)[i+1].location, gtw.location)
        < (point.distance(nodes(p)[i].location, gtw.location) + 1000))
RETURN [n in nodes(p) | n.name] AS stations,
       reduce(acc = 0.0, link IN links | round(acc + link.distance, 2)) AS distance 
ORDER BY distance LIMIT 1;
// alas the planner can't inline this
// we could change the model to have each direction of track represented by a separate relationship
// Cypher only enforces uniqueness in relationships in a match, we would need to add a predicate to check whether
// a node had been revisited or not. 

// Q5: train tracks aren't roads, and travellers can't flow freely from station to station. 
// we need to plan our journey based on the routes taken by actual trains over the tracks. so what train takes me from Denmark Hill to Gatwick Airport?
MATCH (:Station {name: 'Denmark Hill'})<-[:CALLS_AT]-(r:CallingPoint) 
        (()-[:NEXT]->())+ (:CallingPoint)-[:CALLS_AT]->
        (:Station {name: 'Gatwick Airport'})
RETURN r.routeName AS route
// RESULTS: uh oh!
+-----------+
| routeName |
+-----------+
+-----------+

// Q6: OK what about if I change trains
MATCH (dmk:Station {name: 'Denmark Hill'})<-[:CALLS_AT]-(l1:CallingPoint)
        (()-[:NEXT]->())+
        (:CallingPoint)-[:CALLS_AT]->(x:Station)<-[:CALLS_AT]-(l2:CallingPoint) 
        (()-[:NEXT]->())+
        (:CallingPoint)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
RETURN l1.routeName AS leg1, x.name AS changeAt, l2.routeName AS leg2;
// RESULTS: we get answers, but they're a bit slow, and we get too many answers

// Q7: we want to leave in the next 30 minutes
MATCH (dmk:Station {name: 'Denmark Hill'})<-[:CALLS_AT]-(l1a:CallingPoint)-[:NEXT]->+
        (l1b)-[:CALLS_AT]->(x:Station)<-[:CALLS_AT]-(l2a:CallingPoint)-[:NEXT]->+
        (l2b)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
MATCH (l1a)-[:HAS]->(s1:Stop)-[:NEXT]->+(s2)<-[:HAS]-(l1b)
        WHERE time('09:30') < s1.departs < time('10:00')
MATCH (l2a)-[:HAS]->(s3:Stop)-[:NEXT]->+(s4)<-[:HAS]-(l2b)
        WHERE s2.arrives < s3.departs < s2.arrives + duration('PT20M')
RETURN s1.departs AS leg1Departs, s2.arrives AS leg1Arrives, x.name AS changeAt,
        s3.departs AS leg2Departs, s4.arrives AS leg2Arrive,
        duration.between(s1.departs, s4.arrives).minutes AS journeyTime
ORDER BY leg2Arrive LIMIT 5;

// Q8: we don't want to go via London
MATCH (dmk:Station {name: 'Denmark Hill'})<-[:CALLS_AT]-(l1a:CallingPoint)
        (()-[:NEXT]->(n) 
          WHERE NOT EXISTS { (n)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) })+
        (l1b)-[:CALLS_AT]->(x:Station)<-[:CALLS_AT]-(l2a:CallingPoint)
        (()-[:NEXT]->(m)
          WHERE NOT EXISTS { (m)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) })+
        (l2b)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
MATCH (l1a)-[:HAS]->(s1:Stop)-[:NEXT]->+(s2)<-[:HAS]-(l1b)
        WHERE time('09:30') < s1.departs < time('10:00')
MATCH (l2a)-[:HAS]->(s3:Stop)-[:NEXT]->+(s4)<-[:HAS]-(l2b)
        WHERE s2.arrives < s3.departs < s2.arrives + duration('PT60M')
RETURN s1.departs AS leg1Departs, s2.arrives AS leg1Arrives, x.name AS changeAt,
        s3.departs AS leg2Departs, s4.arrives AS leg2Arrive,
        duration.between(s1.departs, s4.arrives).minutes AS journeyTime
ORDER BY leg2Arrive LIMIT 5;

//////////////////////////////////////////////////

// Q8: we want to leave in the next 30 minutes
MATCH (dmk:Station {name: 'Denmark Hill'})<-[:CALLS_AT]-(p1:CallingPoint)
        (()-[:NEXT]->(n WHERE NOT EXISTS { (n)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        (p2:CallingPoint)-[:CALLS_AT]->
                                       (x:Station)
                                                  <-[:CALLS_AT]-(q1:CallingPoint)
        (()-[:NEXT]->(m WHERE NOT EXISTS { (m)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        (q2:CallingPoint)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
MATCH (p1)-[:HAS]->(ps1:Stop WHERE time('09:19') < ps1.departs < time('9:40'))-[:NEXT]->+(ps2)<-[:HAS]-(p2)
MATCH (q1)-[:HAS]->(qs1:Stop WHERE ps2.arrives < qs1.departs)-[:NEXT]->+(qs2)<-[:HAS]-(q2)
RETURN ps1.departs, ps2.arrives, x.name, qs1.departs, qs2.arrives
ORDER BY qs2.arrives LIMIT 1;

// Q9


MATCH (dmk:Station {name: 'Denmark Hill'})<-[:CALLS_AT]-(r1:CallingPoint)
        (()-[:NEXT]->(n WHERE NOT EXISTS { (n)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        ()-[:CALLS_AT]->(x:Station)<-[:CALLS_AT]-(r2:CallingPoint)
        (()-[:NEXT]->(m WHERE NOT EXISTS { (m)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        ()-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
RETURN r1.routeName AS route1, x.name AS changeAt, r2.routeName AS route2;


MATCH (dmk:Station {name: 'Denmark Hill'})<-[:CALLS_AT]-(p1:CallingPoint)
        (()-[:NEXT]->(n WHERE NOT EXISTS { (n)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        (p2:CallingPoint)-[:CALLS_AT]->
                                        (x:Station)
                                                <-[:CALLS_AT]-(q1:CallingPoint)
        (()-[:NEXT]->(m WHERE NOT EXISTS { (m)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        (q2:CallingPoint)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
MATCH leg1 = (p1)-[:HAS]->(ps1:Stop WHERE time('09:19') < ps1.departs < time('9:40'))-[:NEXT]->+(ps2)<-[:HAS]-(p2)
MATCH leg2 = (q1)-[:HAS]->(qs1:Stop WHERE ps2.arrives < qs1.departs)-[:NEXT]->+(qs2)<-[:HAS]-(q2)
WITH qs1.departs AS xDeparts, [n IN nodes(leg1) WHERE n:Stop] + [m IN nodes(leg2) WHERE m:Stop] AS stops
UNWIND stops AS stop
MATCH (stop)<-[:HAS]-(:CallingPoint)-[:CALLS_AT]->(s:Station)
RETURN s.name AS station, stop.departs AS departs
ORDER BY xDeparts ASC LIMIT 1;


MATCH (dmk:Station {name: 'Denmark Hill'})<-[:CALLS_AT]-(p1:CallingPoint)
        (()-[:NEXT]->(n WHERE NOT EXISTS { (n)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        (p2:CallingPoint)-[:CALLS_AT]->
                                        (x:Station)
                                                <-[:CALLS_AT]-(q1:CallingPoint)
        (()-[:NEXT]->(m WHERE NOT EXISTS { (m)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        (q2:CallingPoint)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
MATCH leg1 = (p1)-[:HAS]->(ps1:Stop WHERE time('09:19') < ps1.departs < time('9:40'))-[:NEXT]->+(ps2)<-[:HAS]-(p2)
MATCH leg2 = (q1)-[:HAS]->(qs1:Stop WHERE ps2.arrives < qs1.departs)-[:NEXT]->+(qs2)<-[:HAS]-(q2)
WITH qs1.departs, [n IN nodes(leg1) WHERE n:Stop]+[m IN nodes(leg2) WHERE m:Stop] AS stops 
ORDER BY qs1.departs ASC LIMIT 1
UNWIND stops AS stop
MATCH (stop)<-[:HAS]-(:CallingPoint)-[:CALLS_AT]->(s:Station)
RETURN s.name AS station, stop.departs AS departs
;

MATCH (dmk:Station {name: 'Newcastle'})<-[:CALLS_AT]-(p1:CallingPoint)-[:NEXT]->+
        (p2:CallingPoint)-[:CALLS_AT]->(x:Station)<-[:CALLS_AT]-(q1:CallingPoint)-[:NEXT]->+
        (q2:CallingPoint)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
MATCH leg1 = (p1)-[:HAS]->(ps1:Stop WHERE time('09:19') < ps1.departs < time('9:40'))-[:NEXT]->+(ps2)<-[:HAS]-(p2)
MATCH leg2 = (q1)-[:HAS]->(qs1:Stop WHERE ps2.arrives < qs1.departs)-[:NEXT]->+(qs2)<-[:HAS]-(q2)
WITH [n IN nodes(leg1) WHERE n:Stop]+[m IN nodes(leg2) WHERE m:Stop] AS stops 
ORDER BY qs1.departs ASC LIMIT 1
UNWIND stops AS stop
MATCH (stop)<-[:HAS]-(:CallingPoint)-[:CALLS_AT]->(s:Station)
RETURN s.name AS station, stop.arrives AS arrives, stop.departs AS departs
;

// Q9: what does that look like with var-length?
// Actually it kind of sucks with the connection
MATCH (dmk:Station {name: 'Denmark Hill'})<-[:CALLS_AT]-(r1:CallingPoint)
        (()-[:NEXT]->(n WHERE NOT EXISTS { (n)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        (:CallingPoint)-[:CALLS_AT]->(x:Station)<-[:CALLS_AT]-(r2:CallingPoint)
        (()-[:NEXT]->(m WHERE NOT EXISTS { (m)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) }))+
        (:CallingPoint)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
RETURN r1.routeName AS route1, x.name AS changeAt, r2.routeName AS route2;

// actually we could write like this
MATCH p = (dmk:Station {name: 'Manchester Piccadilly'})<-[:CALLS_AT]-(r1:CallingPoint)-[:NEXT]->+
        (:CallingPoint)-[:CALLS_AT]->(x:Station)<-[:CALLS_AT]-(r2:CallingPoint)-[:NEXT]->+
        (:CallingPoint)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
WHERE none(n IN nodes(p) WHERE n:CallingPoint AND EXISTS { (n)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) })
RETURN r1.routeName AS route1, x.name AS changeAt, r2.routeName AS route2;

// var-length
MATCH p = (dmk:Station {name: 'Manchester Piccadilly'})<-[:CALLS_AT]-(r1:CallingPoint)-[:NEXT*]->
        (:CallingPoint)-[:CALLS_AT]->(x:Station)<-[:CALLS_AT]-(r2:CallingPoint)-[:NEXT*]->
        (:CallingPoint)-[:CALLS_AT]->(gtw:Station {name: 'Gatwick Airport'})
WHERE none(n IN nodes(p) WHERE n:CallingPoint AND EXISTS { (n)-[:CALLS_AT]->(:Station {groupName: 'LONDON GROUP'}) })
RETURN r1.routeName AS route1, x.name AS changeAt, r2.routeName AS route2;

// Bastien's plan example can also be easily rewritten 
MATCH (dmk:Station {name: 'DENMARK HILL'})
MATCH (wwr:Station {name: 'WANDSWORTH ROAD'})
MATCH (dmk)<-[:CALLS_AT]-(departure) ((from)-[next:NEXT]->(to) WHERE NOT (to)-[:CALLS_AT]->(wwr))+ (arrival)-[:CALLS_AT]->(destination)
RETURN DISTINCT destination.name AS destination_name;

MATCH (dmk:Station {name: 'DENMARK HILL'})
MATCH (wwr:Station {name: 'WANDSWORTH ROAD'})
MATCH p = (dmk)<-[:CALLS_AT]-(departure)-[:NEXT*]->(arrival)-[:CALLS_AT]->(destination)
WHERE none(n IN nodes(p) WHERE n:Stop AND (n)-[:CALLS_AT]->(wwr)) 
RETURN DISTINCT destination.name AS destination_name;

MATCH ((:Person)-[:RATED]->
        (m:Movie WHERE m.year >= 2014)<-[:RATED]-(:Person)){1,3}