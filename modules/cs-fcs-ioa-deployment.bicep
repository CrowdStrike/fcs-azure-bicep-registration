targetScope = 'subscription'

/*
  This Bicep template deploys infrastructure to enable CrowdStrike 
  Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('The location for the resources deployed in this solution.')
param location string = deployment().location

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs-fcs-ioa'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()

@description('The name of the resource group.')
param resourceGroupName string = 'cs-ioa-group' // DO NOT CHANGE - used for registration validation

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'cstag-product': 'fcs'
  'cstag-purpose': 'fcs'
}

@description('The CID for the Falcon API.')
param falconCID string

@description('The client ID for the Falcon API.')
param falconClientId string

@description('The client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('The Falcon cloud region.')
@allowed([
  'US-1'
  'US-2'
  'EU-1'
])
param falconCloudRegion string = 'US-1'

@description('Enable Application Insights for additional logging of Function Apps.')
#disable-next-line no-unused-params
param enableAppInsights bool = false

@description('Enable Activity Log diagnostic settings deployment for current subscription.')
param deployActivityLogDiagnosticSettings bool = true

@description('Enable Entra ID Log diagnostic settings deployment. Requires at least Security Administrator permissions')
param deployEntraLogDiagnosticSettings bool = true

param randomSuffix string = uniqueString(resourceGroupName, defaultSubscriptionId)

param defaultSubscriptionId string // DO NOT CHANGE - used for registration validation

param subscriptionId string = subscription().subscriptionId

/* ParameterBag for CS Logs */
param csLogSettings object = {
  storageAccountName: substring('cshorizonlogs${randomSuffix}', 0, 24)
  storageAccountIdentityName: substring('cshorizonlogs${randomSuffix}', 0, 24)
  storagePrivateEndpointName: 'log-storage-private-endpoint'
  storagePrivateEndpointConnectionName: 'cs-log-storage-private-endpoint'
}

/* ParameterBag for Activity Logs */
param activityLogSettings object = {
  hostingPlanName: 'cs-activity-service-plan'
  functionAppName: 'cs-activity-func-${defaultSubscriptionId}' // DO NOT CHANGE - used for registration validation
  functionAppIdentityName: 'cs-activity-func-${defaultSubscriptionId}' // DO NOT CHANGE - used for registration validation
  functionAppDiagnosticSettingName: 'cs-activity-func-to-storage'
  ioaPackageURL: 'https://cs-prod-cloudconnect-templates.s3-us-west-1.amazonaws.com/azure/4.x/ioa.zip'
  storageAccountName: substring('cshorizonact${randomSuffix}', 0, 24)
  storageAccountIdentityName: substring('cshorizonact${randomSuffix}', 0, 24)
  storagePrivateEndpointName: 'activity-storage-private-endpoint'
  storagePrivateEndpointConnectionName: 'cs-activity-storage-private-endpoint'
  eventHubName: 'cs-eventhub-monitor-activity-logs' // DO NOT CHANGE - used for registration validation
  diagnosticSetttingsName: 'cs-monitor-activity-to-eventhub' // DO NOT CHANGE - used for registration validation
}

/* ParameterBag for EntraId Logs */
param entraLogSettings object = {
  hostingPlanName: 'cs-aad-service-plan'
  functionAppName: 'cs-aad-func-${defaultSubscriptionId}' // DO NOT CHANGE - used for registration validation
  functionAppIdentityName: 'cs-aad-func-${defaultSubscriptionId}' // DO NOT CHANGE - used for registration validation
  functionAppDiagnosticSettingName: 'cs-aad-func-to-storage'
  ioaPackageURL: 'https://cs-prod-cloudconnect-templates.s3-us-west-1.amazonaws.com/azure/4.x/ioa.zip'
  storageAccountName: substring('cshorizonaad${randomSuffix}', 0, 24)
  storageAccountIdentityName: substring('cshorizonaad${randomSuffix}', 0, 24)
  storagePrivateEndpointName: 'aad-storage-private-endpoint'
  storagePrivateEndpointConnectionName: 'cs-aad-storage-private-endpoint'
  eventHubName: 'cs-eventhub-monitor-aad-logs' // DO NOT CHANGE - used for registration validation
  diagnosticSetttingsName: 'cs-aad-to-eventhub' // DO NOT CHANGE - used for registration validation
}

/* Variables */
var eventHubNamespaceName = 'cs-horizon-ns-${defaultSubscriptionId}' // DO NOT CHANGE - used for registration validation
var keyVaultName = 'cs-kv-${uniqueString(defaultSubscriptionId)}'
var virtualNetworkName = 'cs-vnet'
var networkSecurityGroupName = 'cs-nsg'
var scope = az.resourceGroup(resourceGroup.name)

/* Resource Deployment */
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Create Virtual Network for secure communication of services
module virtualNetwork 'ioa/virtualNetwork.bicep' = {
  name: '${deploymentNamePrefix}-virtualNetwork-${deploymentNameSuffix}'
  scope: scope
  params: {
    virtualNetworkName: virtualNetworkName
    networkSecurityGroupName: networkSecurityGroupName
    tags: tags
  }
}

// Create EventHub Namespace and Eventhubs used by CrowdStrike
module eventHub 'ioa/eventHub.bicep' = {
  name: '${deploymentNamePrefix}-eventHubs-${deploymentNameSuffix}'
  scope: scope
  params: {
    eventHubNamespaceName: eventHubNamespaceName
    activityLogEventHubName: activityLogSettings.eventHubName
    entraLogEventHubName: entraLogSettings.eventHubName
    virtualNetworkName: virtualNetwork.outputs.virtualNetworkName
    tags: tags
  }
}

// Create KeyVault and secrets
module keyVault 'ioa/keyVault.bicep' = {
  name: '${deploymentNamePrefix}-keyVault-${deploymentNameSuffix}'
  scope: scope
  params: {
    keyVaultName: keyVaultName
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    virtualNetworkName: virtualNetwork.outputs.virtualNetworkName
    tags: tags
  }
}

/* Create CrowdStrike Log Storage Account */
module csLogStorage 'ioa/storageAccount.bicep' = {
  scope: scope
  name: '${deploymentNamePrefix}-csLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: csLogSettings.storageAccountIdentityName
    storageAccountName: csLogSettings.storageAccountName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountSubnetId: virtualNetwork.outputs.csSubnet1Id
    storagePrivateEndpointName: csLogSettings.storagePrivateEndpointName
    storagePrivateEndpointConnectionName: csLogSettings.storagePrivateEndpointConnectionName
    storagePrivateEndpointSubnetId: virtualNetwork.outputs.csSubnet3Id
    tags: tags
  }
}

/* Enable CrowdStrike Log Storage Account Encryption */
module csLogStorageEncryption 'ioa/enableEncryption.bicep' = {
  name: '${deploymentNamePrefix}-csLogStorageEncryption-${deploymentNameSuffix}'
  scope: scope
  params: {
    userAssignedIdentity: csLogStorage.outputs.userAssignedIdentityId
    storageAccountName: csLogStorage.outputs.storageAccountName
    keyName: keyVault.outputs.csLogStorageKeyName
    keyVaultUri: keyVault.outputs.keyVaultUri
  }
}

/* Create KeyVault Diagnostic Setting to CrowdStrike Log Storage Account */
module keyVaultDiagnosticSetting 'ioa/keyVaultDiagnosticSetting.bicep' = {
  name: '${deploymentNamePrefix}-keyVaultDiagnosticSetting-${deploymentNameSuffix}'
  scope: scope
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountName: csLogStorage.outputs.storageAccountName
  }
  dependsOn: [
    csLogStorage
    csLogStorageEncryption
  ]
}

/* Create Activity Log Diagnostic Storage Account */
module activityLogStorage 'ioa/storageAccount.bicep' = {
  scope: scope
  name: '${deploymentNamePrefix}-activityLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: activityLogSettings.storageAccountIdentityName
    storageAccountName: activityLogSettings.storageAccountName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountSubnetId: virtualNetwork.outputs.csSubnet1Id
    storagePrivateEndpointName: activityLogSettings.storagePrivateEndpointName
    storagePrivateEndpointConnectionName: activityLogSettings.storagePrivateEndpointConnectionName
    storagePrivateEndpointSubnetId: virtualNetwork.outputs.csSubnet3Id
    tags: tags
  }
}

/* Enable Activity Log Diagnostic Storage Account Encryption */
module activityLogStorageEncryption 'ioa/enableEncryption.bicep' = {
  name: '${deploymentNamePrefix}-activityLogStorageEncryption-${deploymentNameSuffix}'
  scope: scope
  params: {
    userAssignedIdentity: activityLogStorage.outputs.userAssignedIdentityId
    storageAccountName: activityLogStorage.outputs.storageAccountName
    keyName: keyVault.outputs.activityLogStorageKeyName
    keyVaultUri: keyVault.outputs.keyVaultUri
    tags: tags
  }
}

/* Create Entra ID Log Diagnostic Storage Account */
module entraLogStorage 'ioa/storageAccount.bicep' = {
  scope: scope
  name: '${deploymentNamePrefix}-entraLogStorage-${deploymentNameSuffix}'
  params: {
    userAssignedIdentityName: entraLogSettings.storageAccountIdentityName
    storageAccountName: entraLogSettings.storageAccountName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountSubnetId: virtualNetwork.outputs.csSubnet2Id
    storagePrivateEndpointName: entraLogSettings.storagePrivateEndpointName
    storagePrivateEndpointConnectionName: entraLogSettings.storagePrivateEndpointConnectionName
    storagePrivateEndpointSubnetId: virtualNetwork.outputs.csSubnet3Id
    tags: tags
  }
}

/* Enable Entra ID Log Diagnostic Storage Account Encryption */
module entraLogStorageEncryption 'ioa/enableEncryption.bicep' = {
  name: '${deploymentNamePrefix}-entraLogStorageEncryption-${deploymentNameSuffix}'
  scope: scope
  params: {
    userAssignedIdentity: entraLogStorage.outputs.userAssignedIdentityId
    storageAccountName: entraLogStorage.outputs.storageAccountName
    keyName: keyVault.outputs.activityLogStorageKeyName
    keyVaultUri: keyVault.outputs.keyVaultUri
    tags: tags
  }
}

/* Create User-Assigned Managed Identity for Activity Log Diagnostic Function */
module activityLogFunctionIdentity 'ioa/functionIdentity.bicep' = {
  name: '${deploymentNamePrefix}-activityLogFunctionIdentity-${deploymentNameSuffix}'
  scope: scope
  params: {
    functionAppIdentityName: activityLogSettings.functionAppIdentityName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountName: activityLogSettings.storageAccountName
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    tags: tags
  }
  dependsOn: [
    activityLogStorage
    activityLogStorageEncryption
  ]
}

/* Create Azure Function to forward Activity Logs to CrowdStrike */
module activityLogFunction 'ioa/functionApp.bicep' = {
  name: '${deploymentNamePrefix}-activityLogFunction-${deploymentNameSuffix}'
  scope: scope
  params: {
    hostingPlanName: activityLogSettings.hostingPlanName
    functionAppName: activityLogSettings.functionAppName
    functionAppIdentityName: activityLogFunctionIdentity.outputs.functionIdentityName
    packageURL: activityLogSettings.ioaPackageURL
    storageAccountName: activityLogSettings.storageAccountName
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    eventHubName: activityLogSettings.eventHubName
    virtualNetworkName: virtualNetwork.outputs.virtualNetworkName
    virtualNetworkSubnetId: virtualNetwork.outputs.csSubnet1Id
    diagnosticSettingName: activityLogSettings.functionAppDiagnosticSettingName
    falconCID: falconCID
    falconClientIdUri: keyVault.outputs.csClientIdUri
    falconClientSecretUri: keyVault.outputs.csClientSecretUri
    tags: tags
  }
  dependsOn: [
    activityLogStorage
    activityLogStorageEncryption
    activityLogFunctionIdentity
  ]
}

/* Create User-Assigned Managed Identity for Entra ID Log Diagnostic Function */
module entraLogFunctionIdentity 'ioa/functionIdentity.bicep' = {
  name: '${deploymentNamePrefix}-entraLogFunctionIdentity-${deploymentNameSuffix}'
  scope: scope
  params: {
    functionAppIdentityName: entraLogSettings.functionAppIdentityName
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountName: entraLogSettings.storageAccountName
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    tags: tags
  }
  dependsOn: [
    entraLogStorage
    entraLogStorageEncryption
  ]
}

/* Create Azure Function to forward Entra ID Logs to CrowdStrike */
module entraLogFunction 'ioa/functionApp.bicep' = {
  name: '${deploymentNamePrefix}-entraLogFunction-${deploymentNameSuffix}'
  scope: scope
  params: {
    hostingPlanName: entraLogSettings.hostingPlanName
    functionAppName: entraLogSettings.functionAppName
    functionAppIdentityName: entraLogFunctionIdentity.outputs.functionIdentityName
    packageURL: entraLogSettings.ioaPackageURL
    storageAccountName: entraLogSettings.storageAccountName
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
    eventHubName: entraLogSettings.eventHubName
    virtualNetworkName: virtualNetwork.outputs.virtualNetworkName
    virtualNetworkSubnetId: virtualNetwork.outputs.csSubnet2Id
    diagnosticSettingName: entraLogSettings.functionAppDiagnosticSettingName
    falconCID: falconCID
    falconClientIdUri: keyVault.outputs.csClientIdUri
    falconClientSecretUri: keyVault.outputs.csClientSecretUri
    tags: tags
  }
  dependsOn: [
    entraLogStorage
    entraLogStorageEncryption
    entraLogFunctionIdentity
  ]
}

module activityDiagnosticSettings 'ioa/activityLog.bicep' = if (deployActivityLogDiagnosticSettings) {
  name:  '${deploymentNamePrefix}-activityLog-${deploymentNameSuffix}'
  scope: subscription(subscriptionId)
  params: {
      diagnosticSettingsName: activityLogSettings.diagnosticSetttingsName
      eventHubAuthorizationRuleId: eventHub.outputs.eventHubAuthorizationRuleId
      eventHubName: eventHub.outputs.activityLogEventHubName
  }
}

module entraDiagnosticSetttings 'ioa/entraLog.bicep' = if (deployEntraLogDiagnosticSettings) {
  name: '${deploymentNamePrefix}-entraDiagnosticSetttings-${deploymentNameSuffix}'
  params: {
    diagnosticSetttingsName: entraLogSettings.diagnosticSetttingsName
    eventHubName: eventHub.outputs.entraLogEventHubName
    eventHubAuthorizationRuleId: eventHub.outputs.eventHubAuthorizationRuleId
  }
}

/* Set CrowdStrike Falcon Cloud Security Default Azure Subscription */
module setAzureDefaultSubscription 'ioa/defaultSubscription.bicep' = {
  scope: scope
  name: '${deploymentNamePrefix}-defaultSubscription-${deploymentNameSuffix}'
  params: {
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    falconCloudRegion: falconCloudRegion
    tags: tags
  }
}

/* Deployment outputs required for follow-up activities */
output eventHubAuthorizationRuleId string = eventHub.outputs.eventHubAuthorizationRuleId
output activityLogEventHubName string = eventHub.outputs.activityLogEventHubName
output entraLogEventHubName string = eventHub.outputs.entraLogEventHubName
