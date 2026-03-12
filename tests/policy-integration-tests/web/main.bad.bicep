metadata itemDisplayName = 'Test Template for App Services'
metadata description = 'This template deploys the testing resource for App Services.'
metadata summary = 'Deploys test App Services resource that should violate some policy assignments'

// ============ //
// variables    //
// ============ //
// Load the configuration file
var globalConfig = loadJsonContent('../.shared/policy_integration_test_config.jsonc')
var localConfig = loadJsonContent('config.json')
var location = localConfig.location
var namePrefix = globalConfig.namePrefix

// define template specific variables
var serviceShort = 'web3'
var functionAppName = 'fa-${namePrefix}-${serviceShort}-01'
var functionAppServerFarmName = 'sf-fa-${namePrefix}-${serviceShort}-01'
var webAppServerFarmName = 'sf-web-${namePrefix}-${serviceShort}-01'
var webAppName = 'web-${namePrefix}-${serviceShort}-01'
var appSlotName = 'slot1'

resource functionAppServerFarm 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: functionAppServerFarmName
  location: location
  sku: {
    name: 'Y1' //this should violate policy WEB-009: App Service apps should use a SKU that supports private link
    tier: 'Dynamic' //this should violate policy WEB-009: App Service apps should use a SKU that supports private link
  }
  properties: {}
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
    vnetRouteAllEnabled: false //This should violate policy WEB-005: App Service apps should enable outbound non-RFC 1918 traffic to Azure Virtual Network
    serverFarmResourceId: webAppServerFarm.id
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
    httpsOnly: false //This should violate policy WEB-002: App Service and Function apps should only be accessible over HTTPS
    publicNetworkAccess: 'Disabled'
  }
}
resource webAppConfig 'Microsoft.Web/sites/config@2024-04-01' = {
  name: '${webAppName}/web'
  dependsOn: [
    webApp
  ]
  properties: {
    identityProviders: {} //This should violate policy WEB-003: Function apps should only use approved identity providers for authentication
  }
}
module functionApp 'br/public:avm/res/web/site:0.8.0' = {
  name: '${uniqueString(deployment().name, location)}-test-func-${serviceShort}'
  params: {
    name: functionAppName
    location: location
    kind: 'functionapp,linux'
    serverFarmResourceId: functionAppServerFarm.id
    publicNetworkAccess: 'Enabled' //This should violate policy WEB-010: Public network access should be disabled for App Services and Function Apps
    httpsOnly: false //This should violate policy WEB-002: App Service and Function apps should only be accessible over HTTPS
    vnetContentShareEnabled: false //This should violate policy WEB-006: App Service and Function apps should route configuration traffic over the virtual network
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
    publicNetworkAccess: 'Enabled' //This should violate policy WEB-011: Public network access should be disabled for App Service and Function App slots
    httpsOnly: false //This should violate policy WEB-001: App Service and function app slots should only be accessible over HTTPS
    vnetRouteAllEnabled: false //This should violate policy WEB-007: Function apps should route configuration traffic over the virtual network
    vnetContentShareEnabled: false //This should violate policy WEB-008: Function app slots should route configuration traffic over the virtual network
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
