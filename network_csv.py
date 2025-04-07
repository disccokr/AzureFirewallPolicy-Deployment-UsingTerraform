import csv
import json
import sys

def parse_csv(file_path):
    rules = []
    with open(file_path, mode='r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            
            row['protocols'] = [protocol.strip() for protocol in row['protocols'].split(',')]
            
            row['destination_ports'] = [port.strip() for port in row['destination_ports'].split(',')]
            
            row['priority'] = int(row['priority'].strip())
            rules.append(row)
    return rules

if __name__ == "__main__":
    file_path = sys.argv[1]
    rules = parse_csv(file_path)
    
    print(json.dumps({"rules": json.dumps(rules)}))