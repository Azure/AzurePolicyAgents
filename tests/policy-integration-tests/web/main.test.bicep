metadata itemDisplayName = 'Test Template for App Service and Function Apps'
metadata description = 'This template deploys the testing resource for App Service and Function Apps.'
metadata summary = 'Deploys test App Service and Function Apps resources'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'web1'
var functionAppName = 'fa-${namePrefix}-${serviceShort}-01'
var functionAppServerFarmName = 'sf-fa-${namePrefix}-${serviceShort}-01'
var webAppServerFarmName = 'sf-web-${namePrefix}-${serviceShort}-01'
var webAppName = 'web-${namePrefix}-${serviceShort}-01'

var appSlotName = 'slot1'
var webAppSlotPeName = 'pe-${webAppName}-${appSlotName}'
var nsgName = 'nsg-${namePrefix}-${serviceShort}-01'
var virtualNetworkName = 'vnet-${namePrefix}-${serviceShort}-01'

var functionAppPeName = 'pe-${functionAppName}'
var webAppPeName = 'pe-${webAppName}'

var addressPrefix = '10.0.0.0/16'

//Cross sub PE
var crossSubPeSubName = localConfig.additionalResourceGroups.crossSubPe.subscription
var crossSubPeSubId = globalConfig.subscriptions[crossSubPeSubName].id
var crossSubPeVnetResourceGroup = globalConfig.subscriptions[crossSubPeSubName].networkResourceGroup
var crossSubPeResourceGroup = localConfig.additionalResourceGroups.crossSubPe.resourceGroup
var crossSubPeVnetName = globalConfig.subscriptions[crossSubPeSubName].vNet
var crossSubPeSubnetName = globalConfig.subscriptions[crossSubPeSubName].peSubnet
var crossSubPeWebAppServerFarmName = 'sf-web-${namePrefix}-${serviceShort}-02'
var crossSubPeWebAppName = 'web-${namePrefix}-${serviceShort}-02'
var crossSubPeWebAppPeName = 'pe-${crossSubPeWebAppName}'

resource crossSubPeRg 'Microsoft.Resources/resourceGroups@2024-11-01' existing = {
  name: crossSubPeResourceGroup
  scope: subscription(crossSubPeSubId)
}

resource crossSubPeVNetRg 'Microsoft.Resources/resourceGroups@2024-11-01' existing = {
  name: crossSubPeVnetResourceGroup
  scope: subscription(crossSubPeSubId)
}

resource crossSubPeVNet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: crossSubPeVnetName
  scope: crossSubPeVNetRg
  resource peSubnet 'subnets' existing = { name: crossSubPeSubnetName }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: nsgName
  location: location
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

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: virtualNetworkName
  location: location

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
            id: nsg.id
          }
        }
      }
      {
        name: 'functionAppSubnet'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 1)
          networkSecurityGroup: {
            id: nsg.id
          }
          delegations: [
            {
              name: 'Microsoft.Web.serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'webAppSubnet1'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 2)
          networkSecurityGroup: {
            id: nsg.id
          }

          delegations: [
            {
              name: 'Microsoft.Web.serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'webAppSubnet2'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 3)
          networkSecurityGroup: {
            id: nsg.id
          }
          delegations: [
            {
              name: 'Microsoft.Web.serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

resource functionAppServerFarm 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: functionAppServerFarmName
  location: location
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    family: 'Pv3'
    capacity: 3
    size: 'P1v3'
  }
  properties: {}
}

resource webAppServerFarm 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: webAppServerFarmName
  location: location
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    family: 'Pv3'
    capacity: 3
    size: 'P1v3'
  }
  properties: {}
}

resource crossSubPeWebAppServerFarm 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: crossSubPeWebAppServerFarmName
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
    family: 'S'
    capacity: 1
    size: 'S1'
  }
  properties: {}
}

module functionApp 'br/public:avm/res/web/site:0.8.0' = {
  name: '${uniqueString(deployment().name, location)}-test-func-${serviceShort}'
  params: {
    name: functionAppName
    location: location
    enableTelemetry: false
    kind: 'functionapp,linux'
    serverFarmResourceId: functionAppServerFarm.id
    virtualNetworkSubnetId: virtualNetwork.properties.subnets[1].id
    clientCertEnabled: true
    privateEndpoints: [
      {
        name: functionAppPeName
        subnetResourceId: virtualNetwork.properties.subnets[0].id
        service: 'sites'
      }
    ]
    appSettingsKeyValuePairs: {
      AzureFunctionsJobHost__logging__logLevel__default: 'Trace'
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'powershell'
      WEBSITE_RUN_FROM_PACKAGE: '0'
      WEBSITE_ENABLE_SYNC_UPDATE_SITE: 'true'
    }
    siteConfig: {
      use32BitWorkerProcess: false
      powerShellVersion: '7.4'
      alwaysOn: true
    }
    managedIdentities: {
      systemAssigned: true
    }
  }
}

resource functionAppSlot 'Microsoft.Web/sites/slots@2024-11-01' = {
  name: '${functionAppName}/${appSlotName}'
  dependsOn: [
    functionApp
  ]
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: functionAppServerFarm.id
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    clientCertEnabled: true
  }
}

module webApp 'br/public:avm/res/web/site:0.8.0' = {
  name: '${uniqueString(deployment().name, location)}-test-web-${serviceShort}'
  params: {
    name: webAppName
    location: location
    enableTelemetry: false
    kind: 'app,linux'
    serverFarmResourceId: webAppServerFarm.id
    virtualNetworkSubnetId: virtualNetwork.properties.subnets[2].id
    clientCertEnabled: true
    privateEndpoints: [
      {
        name: webAppPeName
        subnetResourceId: virtualNetwork.properties.subnets[0].id
        service: 'sites'
      }
    ]
    siteConfig: {
      use32BitWorkerProcess: false
      alwaysOn: true
    }
    managedIdentities: {
      systemAssigned: true
    }
    apiManagementConfiguration: {}
  }
}

resource webAppSlot 'Microsoft.Web/sites/slots@2024-11-01' = {
  name: '${webAppName}/${appSlotName}'
  dependsOn: [
    webApp
  ]
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: webAppServerFarm.id
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    clientCertEnabled: true
  }
}

resource webAppSlotPe 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: webAppSlotPeName
  location: location
  dependsOn: [
    webAppSlot
  ]
  properties: {
    subnet: {
      id: virtualNetwork.properties.subnets[0].id
    }
    privateLinkServiceConnections: [
      {
        name: 'sites-${appSlotName}'
        properties: {
          privateLinkServiceId: webApp.outputs.resourceId
          groupIds: [
            'sites-${appSlotName}'
          ]
        }
      }
    ]
  }
}

module crossSubPeWebApp 'br/public:avm/res/web/site:0.8.0' = {
  name: '${uniqueString(deployment().name, location)}-test-cross-sub-pe-web-${serviceShort}'
  params: {
    name: crossSubPeWebAppName
    location: location
    enableTelemetry: false
    kind: 'app,linux'
    serverFarmResourceId: crossSubPeWebAppServerFarm.id
    virtualNetworkSubnetId: virtualNetwork.properties.subnets[3].id
    clientCertEnabled: true
    publicNetworkAccess: 'Disabled'
    siteConfig: {
      use32BitWorkerProcess: false
      alwaysOn: true
    }
    managedIdentities: {
      systemAssigned: true
    }
    apiManagementConfiguration: {}
  }
}

module crossSubPeWebAppPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.10.1' = {
  name: '${uniqueString(deployment().name, location)}-cross-sub-web-pe-${serviceShort}'
  scope: crossSubPeRg
  params: {
    name: crossSubPeWebAppPeName
    subnetResourceId: crossSubPeVNet::peSubnet.id
    location: location
    enableTelemetry: false
    privateLinkServiceConnections: [
      {
        name: '${crossSubPeWebAppName}-1'
        properties: {
          groupIds: [
            'sites'
          ]
          privateLinkServiceId: crossSubPeWebApp.outputs.resourceId
        }
      }
    ]
  }
}

output name string = functionApp.outputs.name
output resourceId string = functionApp.outputs.resourceId
output webAppName string = webApp.outputs.name
output webAppResourceId string = webApp.outputs.resourceId
output webAppServerFarmResourceId string = webAppServerFarm.id
output functionAppServerFarmResourceId string = functionAppServerFarm.id
output functionAppSlotResourceId string = functionAppSlot.id
output location string = functionApp.outputs.location
output resourceGroupId string = resourceGroup().id
output functionAppPrivateEndpointName string = functionAppPeName
output functionAppPrivateEndpoints array = functionApp.outputs.privateEndpoints
output webAppPrivateEndpointName string = webAppPeName
output webAppPrivateEndpoints array = webApp.outputs.privateEndpoints
output appSlotName string = appSlotName
output webAppSlotResourceId string = webAppSlot.id
output webAppSlotPrivateEndpointName string = webAppSlotPeName
output webAppSlotPrivateEndpointResourceId string = webAppSlotPe.id
output crossSubPeWebAppResourceId string = crossSubPeWebApp.outputs.resourceId
