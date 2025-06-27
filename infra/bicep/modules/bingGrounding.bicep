targetScope = 'resourceGroup'
param resourceName string = 'bingGrounding'

resource bingGrounding 'Microsoft.Bing/accounts@2020-06-10' = {
  name: resourceName
  location: 'global'
  kind: 'Bing.Grounding'
  sku: {
    name: 'G1'
  }
}

// Retrieving the API Key for the Bing Grounding to be added as API key for connected services to the AI hubs
#disable-next-line BCP037
output bingKeys string = listKeys(bingGrounding.id, '2020-06-10').key1
output bingResourceId string = bingGrounding.id
