// 1. PART 1 - from fixed to variable
// We want to know the distance between two stations
// Let's say we know the number of stations in the network
MATCH (bfr:Station {name: "LONDON BLACKFRIARS"}), 
      (btn:Station {name: "BROCKLEY"})
MATCH (bfr)-[a:LINK]-(:Station)-[b:LINK]-(:Station)-[c:LINK]-(btn)
RETURN a.distance + b.distance + c.distance AS distance
ORDER BY distance LIMIT 1;

// There is a more compact way of expressing the repetition
MATCH (bfr:Station {name: "LONDON BLACKFRIARS"}), 
      (btn:Station {name: "BROCKLEY"})
MATCH (bfr)-[r:LINK*3]-(btn)
RETURN reduce(acc = 0, l in r | acc + l.distance) AS distance
ORDER BY distance LIMIT 1;

// Here is the QPP equivalent
MATCH (bfr:Station {name: "LONDON BLACKFRIARS"}), 
      (btn:Station {name: "BROCKLEY"})
MATCH (bfr)-[r:LINK]-{3}(btn)
RETURN reduce(acc = 0, l in r | acc + l.distance) AS distance
ORDER BY distance LIMIT 1;

// What happens if we try to match longer paths. 
MATCH (bfr:Station {name: "LONDON BLACKFRIARS"}), 
      (btn:Station {name: "BRIGHTON"})
MATCH (bfr)-[link:LINK]-{,25}(btn)
RETURN reduce(acc = 0, l in link | acc + l.distance) AS distance
ORDER BY distance LIMIT 1;
// ~ 3000ms
// +-------------------+
// | distance          |
// +-------------------+
// | 53.66000000000001 |
// | 51.80000000000002 |
// | 52.41000000000002 |
// | 51.63000000000002 |
// | 52.77000000000002 |
// | 52.62000000000002 |
// +-------------------+

// But what if don't know how many stops there are?
MATCH (bfr:Station {name: "LONDON BLACKFRIARS"}), 
      (btn:Station {name: "BRIGHTON"})
MATCH p = (bfr)-[link:LINK]-+(btn)
RETURN reduce(acc = 0, l in link | acc + l.distance) AS distance
ORDER BY distance LIMIT 5;
// Never returns. Trying 30 didn't return in a reasonable amount of time.

// What if we could use the geography of the problem to help us?
MATCH (bfr:Station {name: "LONDON BLACKFRIARS"}), 
      (btn:Station {name: "BRIGHTON"})
MATCH p = (bfr)((a)-[link:LINK]-(b) WHERE b.location.latitude < a.location.latitude)+(btn)
RETURN reduce(acc = 0, l in link | acc + l.distance) AS distance
ORDER BY distance LIMIT 5;
// ~ 27ms
// +--------------------+
// | distance           |
// +--------------------+
// | 50.950000000000024 |
// +--------------------+

// Some of you may have been thinking that shortest path would give the right answer much faster
// But the shortest number of hops between stations doesn't necessarily give you the shortest distance
MATCH (bfr:Station {name: "LONDON BLACKFRIARS"}), (btn:Station {name: "BRIGHTON"})
MATCH p = allShortestPaths((bfr)-[link:LINK*]-(btn))
RETURN reduce(acc = 0, l in link | acc + l.distance) AS distance
ORDER BY distance LIMIT 1;
// ~ 5ms
// +-------------------+
// | distance          |
// +-------------------+
// | 51.08000000000002 |
// +-------------------+

