targetScope = 'resourceGroup'
param resourceName string = ''

@description('SKU name for Bing Grounding service')
@allowed([
  'F1'  // Free tier (if available)
  'S1'  // Standard tier 
  'G1'  // Global tier (original)
])
param skuName string = 'F1'

#disable-next-line BCP081
resource bingGrounding 'Microsoft.Bing/accounts@2020-06-10' = {
  name: resourceName
  location: 'global'
  kind: 'Bing.Grounding'
  sku: {
    name: skuName
  }
}

// Retrieving the API Key for the Bing Grounding to be added as API key for connected services to the AI hubs
@secure()
output bingKeys string = resourceName == '' ? '' : bingGrounding.listKeys().key1
output bingResourceId string = resourceName == '' ? '' : bingGrounding.id
