provider "azurerm" {
  features {}

  subscription_id = "xxxxxxxxxxxxxxxxxxx"
}

# External data source for Network Rules
data "external" "network_csv_rules" {
  program = ["python3", "${path.module}/network_csv.py", "${path.module}/Network-Rules.csv"]
}

# External data source for Application Rules
data "external" "application_csv_rules" {
  program = ["python3", "${path.module}/application_csv.py", "${path.module}/Application-Rules.csv"]
}

resource "azurerm_firewall_policy_rule_collection_group" "network_rule_group" {
  name               = "demo-network-rcg2"
  firewall_policy_id = "/subscriptions/xxxxxxxxxxxxxxxxxxx/resourceGroups/ResourceGroupName/providers/Microsoft.Network/firewallPolicies/ne-p-connectivity-azfirewall-01"
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