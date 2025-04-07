Azure: Deploying Azure Firewall Rules Using Terraform and Python.

Introduction
In this article, we'll walk through how to deploy Azure Firewall rules using Terraform in combination with Python scripting for rule processing.

Problem Statement
While working on a migration project, I explored options to migrate Azure Firewall rules from a Non-Prod to a Prod environment using a CI/CD approach. Instead of manually creating firewall rules (which is time-consuming and error-prone), I wanted a fully automated, scalable, and reusable solution.
Solution Overview
During my research, I came across an insightful article titled "Azure Firewall Policy Rules to CSV" by Pantelis Apostolidis, which helped lay the foundation. Building upon that, I extended the approach to handle both Application and Network rules, ensuring flexibility and clarity without compromising the integrity of the deployment.
In Azure Firewall, Rule Collection Groups are containers that hold Rule Collections. These are processed in order of priority. Azure provides three built-in rule collection groups with preset priorities, but custom rule collections can be added based on specific needs.

This article focuses on deploying two types of firewall rules:
Rule Types in Azure Firewall

1. Network Rules
Controls traffic at the network layer (L3) and transport layer (L4).
Filters traffic based on:
IP Addresses
Ports
Protocols (TCP/UDP)

Fields used in CSV:
Name
priority
protocols
source_addresses
destination_addresses
destination_ports

2. Application Rules
Controls traffic at the application layer (L7).
Filters based on:
FQDNs
URLs
HTTP/HTTPS traffic

Fields used in CSV:
Name
protocols
source_addresses
destination_fqdns
priority

Steps to Deploy Application Rule Collection
Step 1: Create the CSV
Create an Application-Rules.csv file with the following headers:
Name | protocols | source_addresses | destination_fqdns | priority
Save this file inside your code repository (e.g., Application-Rules.csv).
Step 2: Python Script for Parsing
Write a Python script named application_csv.py, This script does 3 major functionalities
Reads the CSV file using csv.DictReader.
Groups rules based on their priority.
Converts protocol strings like Http:80;Https:443 into a structured list of dictionaries.

Here is the full Application rule creation Python script.
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
Output of this script looks something like this (mentioned below) as I did some comparision using ARM template extract.
[
  {"protocolType": "Http", "port": 80},
  {"protocolType": "Https", "port": 443}
]

Step 3: Terraform for Application Rules
Create a terraform.tf file with:
external data source to run the Python script
Terraform logic to parse and deploy the application rules into the firewall policy
Dynamic blocks to loop over rules and protocols
Rule collection names are dynamically based on their priority

provider "azurerm" {
  features {}

  subscription_id = "xxxx-xxxx-xxxx-xxxx-xxxx"
}

data "external" "csv_rules" {
  program = ["python3", "${path.module}/application_csv.py", "${path.module}/Application-Rules.csv"]
}

resource "azurerm_firewall_policy_rule_collection_group" "example" {
  name               = "prademo-rcg"
  firewall_policy_id = "/subscriptions/xxxx-xxxx-xxxx-xxxx-xxxx/resourceGroups/ResourceGroupName/providers/Microsoft.Network/firewallPolicies/ne-p-connectivity-azfirewall-01"
  priority           = 14000

  dynamic "application_rule_collection" {
    for_each = [for i in range(0, length(keys(data.external.csv_rules.result)) / 2) : {
      priority = tonumber(data.external.csv_rules.result["collection_${i}_priority"])
      rules    = jsondecode(data.external.csv_rules.result["collection_${i}_rules"])
    }]
    content {
      name     = "AllowInternet-${application_rule_collection.value.priority}"  # Name based on priority
      action   = "Allow"
      priority = application_rule_collection.value.priority

      dynamic "rule" {
        for_each = application_rule_collection.value.rules
        content {
          name             = rule.value.name
          source_addresses = rule.value.source_addresses
          destination_fqdns = rule.value.destination_fqdns

          dynamic "protocols" {
            for_each = rule.value.protocols
            content {
              type = protocols.value.protocolType
              port = protocols.value.port
            }
          }
        }
      }
    }
  }
}
Steps to Deploy Network Rule Collection
Step 4: Create Network CSV

File: Network-Rules.csv
Name,priority,protocols,source_addresses,destination_addresses,destination_ports

Step 5: Python Script for Network Rules
Script name: network_csv.py
Function:
Parses each network rule row
Converts protocols and port values appropriately
Groups rules by priority or other criteria as needed
Outputs a structured JSON for Terraform

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

Step 6: Terraform for Network Rules
Use external block to read the output from network_csv.py and dynamically deploy Network Rule Collections using a network_rule_collection block.
provider "azurerm" {
  features {}

  subscription_id = "xxxx-xxxx-xxxx-xxxx-xxxx"
}

data "external" "csv_rules" {
  program = ["python3", "${path.module}/network_csv.py", "${path.module}/Network-Rules.csv"]
}

resource "azurerm_firewall_policy_rule_collection_group" "example" {
  name               = "prademo-rcg"
  firewall_policy_id = "/subscriptions/xxxx-xxxx-xxxx-xxxx-xxxx/resourceGroups/ResourceGroupName/providers/Microsoft.Network/firewallPolicies/ne-p-connectivity-azfirewall-01"
  priority           = 14000

  # Network Rule Collection
  dynamic "network_rule_collection" {
    for_each = jsondecode(data.external.csv_rules.result.rules)
    content {
      name     = network_rule_collection.value.Name
      action   = "Allow"
     priority = network_rule_collection.value.priority 

      rule {
        name                  = network_rule_collection.value.Name
        protocols             = network_rule_collection.value.protocols
        source_addresses      = [network_rule_collection.value.source_addresses]
        destination_addresses = [network_rule_collection.value.destination_addresses]
        destination_ports     = network_rule_collection.value.destination_ports
      }
    }
  }

Consolidated (Application and Network) Deployment.
If you want to create both Application and Network rule collections under one Rule collection group then you can use this Terraform Script rest Application and Network Python scripts will remains same.

provider "azurerm" {
  features {}

  subscription_id = "xxxx-xxxx-xxxx-xxxx-xxxx"
}

# External data source for Network Rules
data "external" "network_csv_rules" {
  program = ["python3", "${path.module}/parse_csv.py", "${path.module}/Network-Rules.csv"]
}

# External data source for Application Rules
data "external" "application_csv_rules" {
  program = ["python3", "${path.module}/parse_application_csv.py", "${path.module}/Application-Rules.csv"]
}

resource "azurerm_firewall_policy_rule_collection_group" "network_rule_group" {
  name               = "demo-network-rcg2"
  firewall_policy_id = "/subscriptions/xxxx-xxxx-xxxx-xxxx-xxxx/resourceGroups/ResourceGroupName/providers/Microsoft.Network/firewallPolicies/ne-p-connectivity-azfirewall-01"
  priority           = 15000

  # Network Rule Collection
  network_rule_collection {
    name     = "prademo-network-rc"
    action   = "Allow"
    priority = 200

    dynamic "rule" {
      for_each = jsondecode(data.external.network_csv_rules.result.rules)
      content {
        name                  = rule.value.Name
        protocols             = rule.value.protocols
        source_addresses      = [rule.value.source_addresses]
        destination_addresses = [rule.value.destination_addresses]
        destination_ports     = rule.value.destination_ports
      }
    }
  }

  # Application Rule Collection
  application_rule_collection {
    name     = "prademo-application-rc"
    action   = "Allow"
    priority = 300

    dynamic "rule" {
      for_each = jsondecode(data.external.application_csv_rules.result["collection_0_rules"])
      content {
        name             = rule.value.name
        source_addresses = rule.value.source_addresses
        destination_fqdns = rule.value.destination_fqdns

        dynamic "protocols" {
          for_each = rule.value.protocols
          content {
            type = protocols.value.protocolType
            port = protocols.value.port
          }
        }
      }
    }
  }
}
Final Notes & Recommendations
Ensure unique priorities across all rule collections within a single rule_collection_group. This is crucial; otherwise, Azure will reject the request.
You can use two separate rule collection groups (e.g., demo-application-rcg, demo-network-rcg) to avoid priority clashes.
Use CI/CD pipelines (e.g., GitHub Actions or Azure DevOps) to automate deployments between environments.
Consider adding unit tests for Python CSV parsing logic for future-proofing.

Reference Links:
Terraform Registry
Edit descriptionregistry.terraform.io
Quickstart: Create an Azure Firewall and a firewall policy - Terraform
In this quickstart, you deploy an Azure Firewall and a firewall policy using Terraform.learn.microsoft.com
Azure Firewall Policy Rules to CSV - Apostolidis Cloud Corner