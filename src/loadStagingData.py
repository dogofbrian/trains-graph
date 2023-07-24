import sys
import warnings
import os
from neo4j import GraphDatabase

dirname = os.path.dirname(__file__)

uri = sys.argv[1]
user = sys.argv[2]
password = sys.argv[3]
if len(sys.argv) > 4:
    database = sys.argv[4]
else:
    database = None

with GraphDatabase.driver(uri, auth=(user, password), database=database) as driver, warnings.catch_warnings():
    warnings.simplefilter("ignore")
    with open(os.path.join(dirname, "loadStagingData.cypher")) as file:
        cmds = file.read().split(";")
        for cmd in cmds:
            if cmd.strip() != "":
                if " IN TRANSACTIONS OF " in cmd:
                    with driver.session() as session:
                        session.run(cmd)
                else:
                    driver.execute_query(cmd)



