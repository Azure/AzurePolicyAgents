metadata itemDisplayName = 'Test Template for Private Endpoints (for AMPLS)'
metadata description = 'This template deploys the testing resource for Azure Private Endpoint.'
metadata summary = 'Deploys test Azure Private Endpoint resource that should violate some policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var tags = globalConfig.tags
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'pe1'
var defaultNsgName = 'nsg-${namePrefix}-${serviceShort}-02'
var virtualNetworkName = 'vnet-${namePrefix}-${serviceShort}-01'
var routeTableName = 'rt-${namePrefix}-${serviceShort}-01'
var addressPrefix = '10.1.0.0/16'
var amplsName = 'ampls-${namePrefix}-${serviceShort}-01'
var peName = 'pe-${amplsName}'
var nicName = 'nic-${peName}'
resource defaultNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: defaultNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPSInbound'
        properties: {
          access: 'Allow'
          description: 'Allow HTTPS Inbound on TCP port 443'
          protocol: 'Tcp'
          sourceAddressPrefix: 'virtualNetwork'
          destinationAddressPrefix: '*'
          sourcePortRange: '*'
          destinationPortRange: '443'
          direction: 'Inbound'
          priority: 200
        }
      }
    ]
  }
}
resource routeTable 'Microsoft.Network/routeTables@2024-01-01' = {
  name: routeTableName
  tags: tags
  location: location
  properties: {
    routes: []
  }
}
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'defaultSubnet'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 0)
          networkSecurityGroup: {
            id: defaultNsg.id
          }
          routeTable: {
            id: routeTable.id
          }
        }
      }
    ]
  }
}

resource ampls 'Microsoft.Insights/privateLinkScopes@2021-07-01-preview' = {
  name: amplsName
  location: 'global'
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'Open'
    }
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: peName
  location: location
  properties: {
    subnet: {
      id: virtualNetwork.properties.subnets[0].id
    }
    customNetworkInterfaceName: nicName
    privateLinkServiceConnections: [
      {
        name: '${last(split(ampls.id, '/'))}-1'
        properties: {
          privateLinkServiceId: ampls.id
          groupIds: [
            'azuremonitor' // should violate policy P-PE-02: azuremonitor PE is not allowed
          ]
        }
      }
    ]
  }
}
@description('The resource ID of private endpoint.')
output privateEndpointId string = pe.id

output name string = ampls.name
output resourceId string = ampls.id
output location string = ampls.location
