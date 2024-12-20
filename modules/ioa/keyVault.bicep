param keyVaultName string
param virtualNetworkName string
param falconClientId string
@secure()
param falconClientSecret string
param location string = resourceGroup().location
param tags object = {}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: virtualNetworkName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: [
        {
          id: virtualNetwork.properties.subnets[0].id
          ignoreMissingVnetServiceEndpoint: true
        }
        {
          id: virtualNetwork.properties.subnets[1].id
          ignoreMissingVnetServiceEndpoint: true
        }
      ]
    }
    publicNetworkAccess: 'Enabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
}

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'kv-private-endpoint'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'cs-kv-private-endpoint'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    subnet: {
      id: virtualNetwork.properties.subnets[2].id
    }
  }
}

resource csLogStorageKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  name: 'cs-log-storage-key'
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exportable: false
    }
    keyOps: [
      'decrypt'
      'encrypt'
      'sign'
      'unwrapKey'
      'verify'
      'wrapKey'
    ]
    keySize: 4096
    kty: 'RSA'
  }
}

resource activityLogStorageKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  name: 'cs-activity-storage-key'
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exportable: false
    }
    keyOps: [
      'decrypt'
      'encrypt'
      'sign'
      'unwrapKey'
      'verify'
      'wrapKey'
    ]
    keySize: 4096
    kty: 'RSA'
  }
}

resource entraLogStorageKey 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  name: 'cs-aad-storage-key'
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
      exportable: false
    }
    keyOps: [
      'decrypt'
      'encrypt'
      'sign'
      'unwrapKey'
      'verify'
      'wrapKey'
    ]
    keySize: 4096
    kty: 'RSA'
  }
}

resource csClientId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'cs-client-id'
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: falconClientId
  }
}

resource csClientSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'cs-client-secret'
  tags: tags
  parent: keyVault
  properties: {
    attributes: {
      enabled: true
    }
    value: falconClientSecret
  }
}

output keyVaultName string = keyVault.name
output csLogStorageKeyName string = csLogStorageKey.name
output activityLogStorageKeyName string = activityLogStorageKey.name
output entraLogStorageKeyName string = entraLogStorageKey.name
output keyVaultUri string = keyVault.properties.vaultUri
output csClientIdUri string = csClientId.properties.secretUri
output csClientSecretUri string = csClientSecret.properties.secretUri
