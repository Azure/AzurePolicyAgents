metadata itemDisplayName = 'Test Template for App Services'
metadata description = 'This template deploys the testing resource for App Services.'
metadata summary = 'Deploys test App Services resource that should comply with all policy assignments'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'as2'
var functionAppName = 'fa-${namePrefix}-${serviceShort}-01'
var functionAppServerFarmName = 'sf-fa-${namePrefix}-${serviceShort}-01'
var webAppServerFarmName = 'sf-web-${namePrefix}-${serviceShort}-01'
var webAppName = 'web-${namePrefix}-${serviceShort}-01'
var appSlotName = 'slot1'

var nsgName = 'nsg-${namePrefix}-${serviceShort}-01'
var virtualNetworkName = 'vnet-${namePrefix}-${serviceShort}-01'
var routeTableName = 'rt-${namePrefix}-${serviceShort}-01'
var peName = 'pe-${functionAppName}'
var addressPrefix = '10.1.0.0/16'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
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
resource routeTable 'Microsoft.Network/routeTables@2024-01-01' = {
  name: routeTableName
  location: location
  properties: {
    routes: []
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
          routeTable: {
            id: routeTable.id
          }
        }
      }
      {
        name: 'webAppSubnet'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 1)
          networkSecurityGroup: {
            id: nsg.id
          }
          routeTable: {
            id: routeTable.id
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

resource functionAppServerFarm 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: functionAppServerFarmName
  location: location
  sku: {
    name: 'P1v3' //this should comply with policy WEB-009: App Service apps should use a SKU that supports private link
    tier: 'PremiumV3' //this should comply policy WEB-009: App Service apps should use a SKU that supports private link
    family: 'Pv3'
    capacity: 3
    size: 'P1v3'
  }
  properties: {}
}

module functionApp 'br/public:avm/res/web/site:0.8.0' = {
  name: '${uniqueString(deployment().name, location)}-test-func-${serviceShort}'
  params: {
    name: functionAppName
    location: location
    kind: 'functionapp,linux'
    serverFarmResourceId: functionAppServerFarm.id
    publicNetworkAccess: 'Disabled' //This should comply with policy WEB-010
    httpsOnly: true //This should comply with policy WEB-002
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

resource functionAppSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  name: '${functionAppName}/${appSlotName}'
  dependsOn: [
    functionApp
  ]
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: functionAppServerFarm.id
    httpsOnly: true //This should comply with policy WEB-001
    publicNetworkAccess: 'Disabled' //This should comply with policy WEB-011
  }
}

resource webAppServerFarm 'Microsoft.Web/serverfarms@2024-04-01' = {
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

module webApp 'br/public:avm/res/web/site:0.8.0' = {
  name: '${uniqueString(deployment().name, location)}-test-web-${serviceShort}'
  params: {
    name: webAppName
    location: location
    enableTelemetry: false
    kind: 'app,linux'
    serverFarmResourceId: webAppServerFarm.id
    publicNetworkAccess: 'Disabled' //This should comply with policy WEB-010
    siteConfig: {
      use32BitWorkerProcess: false
      ftpsState: 'FtpsOnly'
      alwaysOn: true
    }
    managedIdentities: {
      systemAssigned: true
    }
    apiManagementConfiguration: {}
  }
}
resource webAppSlot 'Microsoft.Web/sites/slots@2024-04-01' = {
  name: '${webAppName}/${appSlotName}'
  dependsOn: [
    webApp
  ]
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: webAppServerFarm.id
    httpsOnly: true //This should comply with policy WEB-002
    publicNetworkAccess: 'Disabled'
  }
}
resource webAppConfig 'Microsoft.Web/sites/config@2024-04-01' = {
  name: '${webAppName}/web'
  dependsOn: [
    webApp
  ]
  properties: {
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: '7c0aba23-7e7c-4dfd-95b4-c2d3fa5770d1' //dummy guid
          openIdIssuer: 'https://login.microsoftonline.com/v2.0/cd3dacc7-d202-4d5d-9b13-59eced0d34a0/' //dummy guid
        }
      }
    } //This should comply with policy WEB-003: Function apps should only use approved identity providers for authentication
  }
}
output webAppName string = webApp.outputs.name
output webAppServerFarmResourceId string = webAppServerFarm.id
output webAppResourceId string = webApp.outputs.resourceId
output functionAppName string = functionApp.outputs.name
output functionAppServerFarmResourceId string = functionAppServerFarm.id
output functionAppResourceId string = functionApp.outputs.resourceId
output location string = functionApp.outputs.location
output resourceGroupId string = resourceGroup().id
output privateEndpointName string = peName
output privateEndpoints array = functionApp.outputs.privateEndpoints
