/*
  This Bicep template registers the Azure account(s) into the targeted Falcon environment

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('Targetscope of the Falcon Cloud Security integration.')
@allowed([
  'ManagementGroup'
  'Subscription'
])
param targetScope string

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('Falcon cloud region. Defaults to US-1, allowed values are US-1, US-2 or EU-1.')
@allowed([
  'US-1'
  'US-2'
  'EU-1'
])
param falconCloudRegion string = 'US-1'

@description('Use an existing Application Registration. Defaults to false.')
param useExistingAppRegistration bool = false

@description('Application Id of an existing Application Registration in Entra ID.')
param azureClientId string

@description('Application Secret of an existing Application Registration in Entra ID.')
@secure()
param azureClientSecret string = ''

@description('Type of the Azure account to integrate.')
@allowed([
  'commercial'
])
param azureAccountType string = 'commercial'

@description('Location for the resources deployed in this solution.')
param location string = resourceGroup().location

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'cstag-product': 'fcs'
  'cstag-purpose': 'fcs'
}

/* Resources */
/* Register Azure account(s) in Falcon Falcon Cloud Security */
resource fcsAzureAccount 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'cs-fcs-iom-${subscription().subscriptionId}'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '12.3'
    environmentVariables: [
      {
        name: 'FALCON_CLOUD_REGION'
        value: falconCloudRegion
      }
      {
        name: 'FALCON_CLIENT_ID'
        value: falconClientId
      }
      {
        name: 'FALCON_CLIENT_SECRET'
        secureValue: falconClientSecret
      }
      {
        name: 'AZURE_CLIENT_ID'
        value: azureClientId
      }
      {
        name: 'AZURE_CLIENT_SECRET'
        secureValue: azureClientSecret
      }
    ]
    arguments: '-AzureAccountType ${azureAccountType} -AzureTenantId ${tenant().tenantId} -AzureSubscriptionId ${subscription().subscriptionId} -TargetScope ${targetScope} -UseExistingAppRegistration ${useExistingAppRegistration}'
    scriptContent: loadTextContent('../../scripts/New-FalconFcsAzureAccount.ps1')
    retentionInterval: 'PT1H'
    cleanupPreference: 'OnSuccess'
  }
}

/* Outputs */
output azurePublicCertificate string = fcsAzureAccount.properties.outputs.public_certificate
