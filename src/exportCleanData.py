"""
    ! I had to run pip install pandas to get package "six"

    We want to export a clean set of nodes and relationships
    that can be imported with very simple Cypher scripts
    leaving all the hacky stuff in this repository.
    
    Node types:

        - Station({crsCode: STRING, name: STRING, tiplocCode: STRING, location: POINT})
        - CallingPoint({stopNumber: INT, routeName: STRING})
        - Stop({stopNumber: INT, arrives: TIME,departs: TIME})

    Relationship types:

        - (:Station)-[:LINK {distance: FLOAT}]->(:Station)
        - (:CallingPoint)-[:CALLS_AT]->(:Station)
        - (:CallingPoint)-[:NEXT]->(:CallingPoint)
        - (:CallingPoint)-[:HAS]->(:Stop)
        - (:Stop)-[:NEXT]->(:Stop)

"""
import sys
import os
import warnings
from neo4j import GraphDatabase, Result

outputDir = sys.argv[1]
uri = sys.argv[2]
user = sys.argv[3]
password = sys.argv[4]
if len(sys.argv) > 5:
    database = sys.argv[5]
else:
    database = None

def export(query, fileName):
    with GraphDatabase.driver(uri, auth=(user, password), database=database) as driver, warnings.catch_warnings():
        warnings.simplefilter("ignore")
        df = driver.execute_query(query, result_transformer_=Result.to_df)
        targetFile = os.path.join(outputDir, fileName)
        df.to_csv(targetFile, index=False)

export(
    query="""
        MATCH (s:Station)
        RETURN id(s) AS id, s.crsCode AS crsCode, s.name AS name, s.tiplocCode AS tiplocCode,
        s.location.latitude AS latitude, s.location.longitude AS longitude 
    """,
    fileName="stations.csv"
)

export(
    query="""
        MATCH (s:CallingPoint)
        RETURN id(s) AS id, s.stopNumber AS stopNumber, s.routeName AS routeName
    """,
    fileName="calling_points.csv"
)

export(
    query="""
        MATCH (s:Stop)
        RETURN id(s) AS id, s.stopNumber AS stopNumber, toString(s.arrives) AS arrives,
            toString(s.departs) AS departs
    """,
    fileName="stops.csv"
)

export(
    query="""
        MATCH (s1:Station)-[l:LINK]->(s2:Station)
        RETURN id(s1) AS source, l.distance AS distance, id(s2) AS target
    """,
    fileName="links.csv"
)

export(
    query="""
        MATCH (c:CallingPoint)-[:CALLS_AT]->(s:Station)
        RETURN id(c) AS source, id(s) AS target
    """,
    fileName="calls_at.csv"
)

export(
    query="""
        MATCH (c1:CallingPoint)-[:NEXT]->(c2:CallingPoint)
        RETURN id(c1) AS source, id(c2) AS target
    """,
    fileName="calling_point_seq.csv"
)

export(
    query="""
        MATCH (c:CallingPoint)-[:HAS]->(s:Stop)
        RETURN id(c) AS source, id(s) AS target
    """,
    fileName="calling_point_stops.csv"
)

export(
    query="""
        MATCH (s1:Stop)-[:NEXT]->(s2:Stop)
        RETURN id(s1) AS source, id(s2) AS target
    """,
    fileName="stop_seq.csv"
)
