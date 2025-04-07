import csv
import json
import sys
from collections import defaultdict

def parse_csv(file_path):
    collections = defaultdict(list)  
    with open(file_path, mode='r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            
            row['protocols'] = [
                {
                    "protocolType": protocol.split(":")[0].strip(),
                    "port": int(protocol.split(":")[1].strip())
                }
                for protocol in row['protocols'].split(";")
            ]
            
            row['destination_fqdns'] = [fqdn.strip() for fqdn in row['destination_fqdns'].split(",")]
            
            row['priority'] = int(row['priority'].strip())
            
            collections[row['priority']].append({
                "name": row["Name"].strip(),
                "protocols": row["protocols"],
                "source_addresses": [row["source_addresses"].strip()],
                "destination_fqdns": row["destination_fqdns"]
            })
    
    
    output = {}
    for i, (priority, rules) in enumerate(collections.items()):
        output[f"collection_{i}_priority"] = str(priority)  
        output[f"collection_{i}_rules"] = json.dumps(rules)  

    print(json.dumps(output))

if __name__ == "__main__":
    file_path = sys.argv[1]
    parse_csv(file_path)