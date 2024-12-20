param virtualNetworkName string
param networkSecurityGroupName string
param subnetNames array = [
  'cs-subnet-1'
  'cs-subnet-2'
  'cs-subnet-3'
]
param location string = resourceGroup().location
param tags object = {}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-03-01' = {
  name: networkSecurityGroupName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetNames[0]
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          serviceEndpoints: [
            { service: 'Microsoft.KeyVault' }
            { service: 'Microsoft.Storage' }
            { service: 'Microsoft.EventHub' }
          ]
        }
      }
      {
        name: subnetNames[1]
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          serviceEndpoints: [
            { service: 'Microsoft.KeyVault' }
            { service: 'Microsoft.Storage' }
            { service: 'Microsoft.EventHub' }
          ]
        }
      }
      {
        name: subnetNames[2]
        properties: {
          addressPrefix: '10.0.3.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          serviceEndpoints: [
            { service: 'Microsoft.KeyVault' }
            { service: 'Microsoft.Storage' }
            { service: 'Microsoft.EventHub' }
          ]
        }
      }
    ]
  }

  resource csSubnet1 'subnets' existing = {
    name: subnetNames[0]
  }

  resource csSubnet2 'subnets' existing = {
    name: subnetNames[1]
  }

  resource csSubnet3 'subnets' existing = {
    name: subnetNames[2]
  }
}

output virtualNetworkName string = virtualNetwork.name
output virtualNetworkId string = virtualNetwork.id
output csSubnet1Id string = virtualNetwork::csSubnet1.id
output csSubnet2Id string = virtualNetwork::csSubnet2.id
output csSubnet3Id string = virtualNetwork::csSubnet3.id
