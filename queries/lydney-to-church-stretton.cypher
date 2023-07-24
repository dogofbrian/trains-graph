// Need to show the Path model item
// PART 3 finding a journey with changes
MATCH (:Station {name: "DENMARK HILL"})<-[:CALLS_AT]-(a:Stop)<-[:HAS]-(path:Path)-[:HAS]->
    (b:Stop)-[:CALLS_AT]->(:Station {name: "CLAPHAM JUNCTION"})
WHERE time('09:15') < a.departs < time('09:30') AND a.stopNumber < b.stopNumber           
RETURN a.departs, path.name, b.arrives
ORDER BY a.departs;

// then find the onward journey
MATCH (:Station {name: "CLAPHAM JUNCTION"})<-[:CALLS_AT]-(a:Stop)<-[:HAS]-(path:Path)-[:HAS]->
    (b:Stop)-[:CALLS_AT]->(:Station {name: "WOKING"})
WHERE time('09:34') < a.departs < time('10:04') AND a.stopNumber < b.stopNumber              
RETURN a.departs, path.name, b.arrives
ORDER BY a.departs;

// can we combine them?
MATCH (:Station {name: "DENMARK HILL"})<-[:CALLS_AT]-(a:Stop)<-[:HAS]-(p1:Path)-[:HAS]->
    (b:Stop)-[:CALLS_AT]->(:Station {name: "CLAPHAM JUNCTION"})
    <-[:CALLS_AT]-(c:Stop)<-[:HAS]-(p2:Path)-[:HAS]->(d:Stop)-[:CALLS_AT]->(:Station {name: "WOKING"})
WHERE time('09:10') < a.departs < time('09:30') AND a.stopNumber < b.stopNumber
  AND b.arrives < c.departs < b.arrives + duration({minutes: 30}) AND c.stopNumber < d.stopNumber
RETURN a.departs, p1.name, c.departs, p2.name
ORDER BY a.departs;

// what if we need a 2nd change?s
MATCH (:Station {name: "DENMARK HILL"})<-[:CALLS_AT]-(a:Stop)<-[:HAS]-(p1:Path)-[:HAS]->
    (b:Stop)-[:CALLS_AT]->(:Station {name: "CLAPHAM JUNCTION"})
    <-[:CALLS_AT]-(c:Stop)<-[:HAS]-(p2:Path)-[:HAS]->(d:Stop)-[:CALLS_AT]->(:Station {name: "WOKING"})
    <-[:CALLS_AT]-(e:Stop)<-[:HAS]-(p3:Path)-[:HAS]->(f:Stop)-[:CALLS_AT]->(:Station {name: "BROCKENHURST"})
WHERE time('09:10') < a.departs < time('09:30') AND a.stopNumber < b.stopNumber
  AND b.arrives < c.departs < b.arrives + duration({minutes: 30}) AND c.stopNumber < d.stopNumber
  AND d.arrives < e.departs < d.arrives + duration({minutes: 30}) AND e.stopNumber < f.stopNumber
RETURN a.departs, p1.name, c.departs, p2.name, e.departs, p3.name
ORDER BY a.departs;

// can we be more concise? can we avoid knowing the number of changes?
MATCH (:Station {name: "DENMARK HILL"})
  (()<-[:CALLS_AT]-(a:Stop)<-[:HAS]-(p1:Path)-[:HAS]->(b:Stop)-[:CALLS_AT]->() WHERE a.stopNumber < b.stopNumber){3}
  (:Station {name: "BROCKENHURST"})
WHERE all(i in range(0, size(a)-2) WHERE b[i].arrives < a[i+1].departs)
RETURN a.departs, p1.name, c.departs, p2.name, e.departs, p3.name
ORDER BY a.departs;


MATCH (:Station {name: "DENMARK HILL"})<-[:CALLS_AT]-(a:Stop)
    ((x)<-[:HAS]-(p:Path)-[:HAS])

  (()<-[:CALLS_AT]-(a:Stop)<-[:HAS]-(p1:Path)-[:HAS]->(b:Stop)-[:CALLS_AT]->() WHERE a.stopNumber < b.stopNumber){3}
  (:Station {name: "BROCKENHURST"})
WHERE all(i in range(0, size(a)-2) WHERE b[i].arrives < a[i+1].departs)
RETURN a.departs, p1.name, c.departs, p2.name, e.departs, p3.name
ORDER BY a.departs;


MATCH (wat:Station {name: "DENMARK HILL"}), (wok:Station {name: "BROCKENHURST"})

(:Station {name: "DENMARK HILL"})<-[:CALLS_AT]-(a:Stop)
  ()<-[:HAS]-(p1:Path)-[:HAS]->(b:Stop)-[:CALLS_AT]->(:Station)<-[:CALLS_AT]-(c:Stop)
  ()<-[:HAS]-(p2:Path)-[:HAS]->(d:Stop)-[:CALLS_AT]->(:Station)<-[:CALLS_AT]-(e:Stop)
  ()<-[:HAS]-(p3:Path)-[:HAS]->(f:Stop)-[:CALLS_AT]->(:Station {name: "BROCKENHURST"})

MATCH (dmk:Station {name: "DENMARK HILL"}), (bcu:Station {name: "BROCKENHURST"})
MATCH (dmk)<-[:CALLS_AT]-(a:Stop WHERE time('09:10') < a.departs < time('09:30'))
  ((x)<-[:HAS]-(:Path)-[:HAS]->(y:Stop)-[:CALLS_AT]->(s:Station)<-[:CALLS_AT]-(z:Stop) WHERE x.stopNumber < y.stopNumber AND y.arrives < z.departs < y.arrives + duration({minutes: 30})){1,3}
  (b)<-[:HAS]-(:Path)-[:HAS]->(c:Stop WHERE b.stopNumber < c.stopNumber)
  -[:CALLS_AT]->(:Station {name: "BROCKENHURST"})
RETURN [i in s | i.name]
  

// hard break 120
MATCH path = ({p: 123})((:Stop)-->(:Stop))+({q: 'CLJ'})
RETURN path

MATCH path = (a:Station WHERE a.c IN ['X', 'Y', 'X'])(()-[:LINK]->()<-[:LINK]-()){1,5}(b:Station {q: 'CLJ'})
      (()-[:LINK]->()<-[:LINK]-()){1,5}
RETURN path

MATCH (dmk)<-[:CALLS_AT]-(a:Stop)
      ((x)<-[:HAS]-(:Path)-[:HAS]->(y:Stop)-[:CALLS_AT]->(s:Station)<-[:CALLS_AT]-(z:Stop) 
        WHERE x.stopNumber < y.stopNumber AND y.arrives < z.departs < y.arrives + duration({minutes: 30})){1,3} 
      (b)<-[:HAS]-(:Path)-[:HAS]->(c:Stop WHERE b.stopNumber < c.stopNumber)-[:CALLS_AT]->
        (:Station {name: 'BROCKENHURST'})
WHERE time('09:10') < a.departs < time('09:30')
RETURN [i IN s | i.name]

// hard break 80
MATCH path = ({p: 123})((:Stop)-->(:Stop))+({q: 'CLJ'})
RETURN path

MATCH path = (a:Station WHERE a.c IN ['X', 'Y', 'X'])
      (()-[:LINK]->()<-[:LINK]-()){1,5}(b:Station {q: 'CLJ'})
      (()-[:LINK]->()<-[:LINK]-()){1,5}
RETURN path

MATCH (dmk)<-[:CALLS_AT]-(a:Stop)
      ((x)<-[:HAS]-(:Path)-[:HAS]->(y:Stop)-[:CALLS_AT]->
        (s:Station)<-[:CALLS_AT]-(z:Stop) WHERE x.stopNumber < y.stopNumber AND
        y.arrives < z.departs < y.arrives + duration({minutes: 30})){1,3}
      (b)<-[:HAS]-(:Path)-[:HAS]->
        (c:Stop WHERE b.stopNumber < c.stopNumber)-[:CALLS_AT]->
        (:Station {name: 'BROCKENHURST'})
WHERE time('09:10') < a.departs < time('09:30')
RETURN [i IN s | i.name]


