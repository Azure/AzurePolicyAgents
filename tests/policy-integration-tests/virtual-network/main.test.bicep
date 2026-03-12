metadata itemDisplayName = 'Test Template for Virtual Network'
metadata description = 'This template deploys the testing resource for Virtual Network.'
metadata summary = 'Deploys test virtual network resource.'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var location2 = localConfig.location2
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'vnet1'
var aeVnetName = 'vnet-${namePrefix}-${serviceShort}-01'
var aeNsgName = 'nsg-${namePrefix}-${serviceShort}-01'

var aseVnetName = 'vnet-${namePrefix}-${serviceShort}-02'
var aseNsgName = 'nsg-${namePrefix}-${serviceShort}-02'

module aeNsg 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${uniqueString(deployment().name, location)}-test-ae-nsg-${serviceShort}'
  params: {
    name: aeNsgName
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

module aeVnet 'br/public:avm/res/network/virtual-network:0.6.1' = {
  name: '${uniqueString(deployment().name, location)}-test-ae-vnet-${serviceShort}'
  params: {
    name: aeVnetName
    location: location
    addressPrefixes: ['10.0.0.0/16']
    subnets: [
      {
        name: 'subnet1'
        addressPrefix: '10.0.1.0/24'
        networkSecurityGroupResourceId: aeNsg.outputs.resourceId
      }
    ]
  }
}

module aseNsg 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${uniqueString(deployment().name, location2)}-test-ase-nsg-${serviceShort}'
  params: {
    name: aseNsgName
    location: location2
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

module aseVnet 'br/public:avm/res/network/virtual-network:0.6.1' = {
  name: '${uniqueString(deployment().name, location2)}-test-ase-vnet-${serviceShort}'
  params: {
    name: aseVnetName
    location: location2
    addressPrefixes: ['10.1.0.0/16']
    subnets: [
      {
        name: 'subnet1'
        addressPrefix: '10.1.1.0/24'
        networkSecurityGroupResourceId: aseNsg.outputs.resourceId
      }
    ]
  }
}

output name string = aeVnet.outputs.name
output resourceId string = aeVnet.outputs.resourceId
output subnetResourceIds array = aeVnet.outputs.subnetResourceIds
output location string = location
output aseVNetName string = aseVnet.outputs.name
output aseVNetResourceId string = aseVnet.outputs.resourceId
output aseSubnetResourceIds array = aseVnet.outputs.subnetResourceIds
output location2 string = location2
