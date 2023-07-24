MATCH (arrival:Stop)-[:CALLS_AT]->(:Station)<-[:CALLS_AT]-(departure:Stop)
WHERE arrival.arrives IS NOT NULL
WITH arrival, 
    departure, 
    duration.between(arrival.arrives, departure.departs) AS transfer_duration
WHERE 0 < transfer_duration.minutes <= 30
CALL {
  WITH arrival, departure, transfer_duration
  CREATE (arrival)-[:CONNECTS_TO { transfer_duration: transfer_duration }]->(departure)
} IN TRANSACTIONS;


MATCH (:Station {name: "LYDNEY"})<-[:CALLS_AT]-(d:Stop)<-[:HAS]-(p1:Path)-[:HAS]->(x:Stop)
      ((:Stop)-[:CONNECTS_TO]->(y:Stop)<-[:HAS]-(pn:Path)-[:HAS]->(z:Stop) 
        WHERE z.stopNumber > y.stopNumber){0,2}
      (a:Stop)-[:CALLS_AT]->(:Station {name: "CHURCH STRETTON"})
WHERE x.stopNumber > d.stopNumber
RETURN [p1] + pn AS paths, duration.between(d.departs, a.arrives) AS total_duration ORDER BY total_duration ASC
LIMIT 10;