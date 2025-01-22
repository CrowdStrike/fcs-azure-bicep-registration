param functionAppIdentityName string
param principalType string = 'ServicePrincipal'
param keyVaultName string
param storageAccountName string
param eventHubNamespaceName string
param location string = resourceGroup().location
param tags object = {}

#disable-next-line secure-secrets-in-params
param KeyVaultSecretsOfficerRoleId string = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer
param StorageBlobDataOwnerRoleId string = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner
param AzureEventHubsDataReceiverRoleId string = 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde' // Azure Event Hubs Data Receiver

resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' existing = {
  name: eventHubNamespaceName
}

resource functionIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: functionAppIdentityName
  location: location
  tags: tags
}

resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(functionIdentity.id, KeyVaultSecretsOfficerRoleId, keyVault.id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', KeyVaultSecretsOfficerRoleId)
    principalId: functionIdentity.properties.principalId
    principalType: principalType
  }
}

resource storageAccountRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(functionIdentity.id, StorageBlobDataOwnerRoleId, storageAccount.id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', StorageBlobDataOwnerRoleId)
    principalId: functionIdentity.properties.principalId
    principalType: principalType
  }
}

resource eventHubNamespaceRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: eventHubNamespace
  name: guid(functionIdentity.id, AzureEventHubsDataReceiverRoleId, eventHubNamespace.id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', AzureEventHubsDataReceiverRoleId)
    principalId: functionIdentity.properties.principalId
    principalType: principalType
  }
}

output functionIdentityId string = functionIdentity.id
output functionIdentityName string = functionIdentity.name
output functionIdentityClientId string = functionIdentity.properties.clientId
output functionIdentityPrincipalId string = functionIdentity.properties.principalId
