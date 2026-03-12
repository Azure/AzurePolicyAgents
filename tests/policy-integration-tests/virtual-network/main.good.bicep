metadata itemDisplayName = 'Test Template for Virtual Network'
metadata description = 'This template deploys the testing resource for Virtual Network.'
metadata summary = 'Deploys test virtual network resource that should be compliant with all policy assignments.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'vnet2'

var vnetName = 'vnet-${namePrefix}-${serviceShort}-01'
var nsgName = 'nsg-${namePrefix}-${serviceShort}-01'

module nsg 'br/public:avm/res/network/network-security-group:0.3.1' = {
  name: '${uniqueString(deployment().name, location)}-test-nsg-${serviceShort}'
  params: {
    name: nsgName
    location: location
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
module vnet 'br/public:avm/res/network/virtual-network:0.1.8' = {
  name: '${uniqueString(deployment().name, location)}-test-vnet-${serviceShort}'
  params: {
    name: vnetName
    location: location
    addressPrefixes: ['10.100.0.0/16']
    subnets: [
      {
        name: 'subnet1'
        addressPrefix: '10.100.1.0/24'
        networkSecurityGroupResourceId: nsg.outputs.resourceId //this should comply with the policy VNET-002: Subnets should be associated with a Network Security Group
      }
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.100.250.0/24'
        //networkSecurityGroupResourceId: nsg.id //this comply with the policy VNET-001: Gateway Subnet should not have Network Security Group associated
      }
    ]
  }
}

output name string = vnet.outputs.name
output resourceId string = vnet.outputs.resourceId
output subnetResourceIds array = vnet.outputs.subnetResourceIds
output nsgResourceId string = nsg.outputs.resourceId
output nsgName string = nsg.outputs.name
output location string = location
