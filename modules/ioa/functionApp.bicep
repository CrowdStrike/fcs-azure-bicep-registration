param hostingPlanName string
param functionAppName string
param functionAppIdentityName string
param packageURL string
param storageAccountName string
param eventHubNamespaceName string
param eventHubName string
param virtualNetworkName string
param virtualNetworkSubnetId string
param falconCID string
param falconClientIdUri string
param falconClientSecretUri string
param diagnosticSettingName string
param location string = resourceGroup().location
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource functionIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: functionAppIdentityName
}

resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: hostingPlanName
  location: location
  tags: tags
  sku: {
    name: 'P0V3'
    tier: 'Premium'
  }
  kind: 'Linux'
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${functionIdentity.id}': {}
    }
  }
  properties: {
    clientCertEnabled: true
    enabled: true
    httpsOnly: true
    keyVaultReferenceIdentity: functionIdentity.id
    serverFarmId: hostingPlan.id
    siteConfig: {
      alwaysOn: true
      appSettings: [
        {
          name: 'PYTHON_THREADPOOL_THREAD_COUNT'
          value: '4'
        }
        {
          name: 'FUNCTIONS_WORKER_PROCESS_COUNT'
          value: '1'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '3.9'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: packageURL
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: '${storageAccount.name}.blob.${environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'AzureEventHubConnectionString__fullyQualifiedNamespace'
          value: '${eventHubNamespaceName}.servicebus.windows.net'
        }
        {
          name: 'AzureStorageAccount'
          value: storageAccount.name
        }
        {
          name: 'EventHubName'
          value: eventHubName
        }
        {
          name: 'CS_CLIENT_ID'
          value: '@Microsoft.KeyVault(SecretUri=${falconClientIdUri})'
        }
        {
          name: 'CS_CLIENT_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=${falconClientSecretUri})'
        }
        {
          name: 'CS_AUTH_MODE'
          value: 'direct_auth'
        }
        {
          name: 'CS_CID'
          value: falconCID
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
        { name: 'AZURE_CLIENT_ID', value: functionIdentity.properties.clientId }
      ]
      ftpsState: 'Disabled'
      http20Enabled: true
      ipSecurityRestrictions: [
        {
          action: 'Deny'
          ipAddress: '0.0.0.0/0'
          name: 'Deny all'
          priority: 0
        }
      ]
      linuxFxVersion: 'PYTHON|3.9'
      minTlsVersion: '1.2'
      pythonVersion: '3.9'
      scmIpSecurityRestrictionsUseMain: true
      use32BitWorkerProcess: false
      vnetName: virtualNetworkName
    }
    storageAccountRequired: false
    virtualNetworkSubnetId: virtualNetworkSubnetId
  }
}

resource autoscaleSetting 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: hostingPlan.name
  location: location
  tags: tags
  properties: {
    enabled: true
    profiles: [
      {
        name: hostingPlan.name
        capacity: {
          default: '1'
          maximum: '4'
          minimum: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: hostingPlan.id
              operator: 'GreaterThan'
              statistic: 'Average'
              threshold: 60
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT5M'
            }
            scaleAction: {
              cooldown: 'PT5M'
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: hostingPlan.id
              operator: 'LessThan'
              statistic: 'Average'
              threshold: 25
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT5M'
            }
            scaleAction: {
              cooldown: 'PT5M'
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
            }
          }
        ]
      }
    ]
    targetResourceUri: hostingPlan.id
  }
}

resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagnosticSettingName
  scope: functionApp
  properties: {
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    storageAccountId: storageAccount.id
  }
}
