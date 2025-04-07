provider "azurerm" {
  features {}

  subscription_id = "xxxxxxxxxxxxxxxxxxx"
}

data "external" "csv_rules" {
  program = ["python3", "${path.module}/network_csv.py", "${path.module}/Network-Rules.csv"]
}

resource "azurerm_firewall_policy_rule_collection_group" "example" {
  name               = "Prademo-demo-rcg1"
  firewall_policy_id = "/subscriptions/xxxxxxxxxxxxxxxxxxx/resourceGroups/ResourceGroupName/providers/Microsoft.Network/firewallPolicies/ne-p-connectivity-azfirewall-01"
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
}