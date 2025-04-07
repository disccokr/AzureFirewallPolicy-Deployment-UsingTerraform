provider "azurerm" {
  features {}

  subscription_id = "xxxxxxxxxxxxxxxxxxx"
}

data "external" "csv_rules" {
  program = ["python3", "${path.module}/application_csv.py", "${path.module}/Application-Rules.csv"]
}

resource "azurerm_firewall_policy_rule_collection_group" "example" {
  name               = "prademo-zabbix-rcg1"
  firewall_policy_id = "/subscriptions/xxxxxxxxxxxxxxxxxxx/resourceGroups/ResourceGroupName/providers/Microsoft.Network/firewallPolicies/ne-p-connectivity-azfirewall-01"
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
