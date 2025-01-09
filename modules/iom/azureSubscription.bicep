targetScope = 'subscription'

extension microsoftGraphV1

/*
  This Bicep template deploys infrastructure to enable CrowdStrike
  Indicator of Misconfiguration (IOM)
  Copyright (c) 2024 CrowdStrike, Inc.
*/

@description('Targetscope of the IOM integration.')
@allowed([
  'ManagementGroup'
  'Subscription'
])
param targetScope string

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs-fcs-iom'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()

@description('Name of the resource group.')
param resourceGroupName string = 'cs-iom-group' // DO NOT CHANGE

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('Falcon cloud region.')
@allowed([
  'US-1'
  'US-2'
  'EU-1'
])
param falconCloudRegion string = 'US-1'

@description('Use existing Application Registration. Defaults to false.')
param useExistingAppRegistration bool = false

@description('Grant admin consent for Application Registration. Defaults to true.')
param grantAppRegistrationAdminConsent bool = true

@description('Application Id of an existing Application Registration in Entra ID.')
param azureClientId string = ''

@description('Application Secret of an existing Application Registration in Entra ID.')
@secure()
param azureClientSecret string = ''

@description('Principal Id of the Application Registration in Entra ID.')
param azurePrincipalId string = ''

@description('Type of the Principal, defaults to ServicePrincipal.')
param azurePrincipalType string = 'ServicePrincipal'

@description('Type of the Azure account to integrate.')
param azureAccountType string = 'commercial'

@description('Assign required permissions automatically.')
param assignAzureSubscriptionPermissions bool = true

@description('Location for the resources deployed in this solution.')
param location string = deployment().location

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'cstag-product': 'fcs'
  'cstag-purpose': 'fcs'
}

/* Create Azure Resource Group for IOM resources */
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

/* Create Application Registration */
module azureAppRegistration 'azureAppRegistration.bicep' = if (!useExistingAppRegistration) {
  name: '${deploymentNamePrefix}-azureAppRegistration-${deploymentNameSuffix}'
  params: {
    grantAdminConsent: grantAppRegistrationAdminConsent
  }
}

/* Integrate Azure account into Falcon */
module azureAccount 'azureAccount.bicep' = {
  name: '${deploymentNamePrefix}-azureAccount-${deploymentNameSuffix}'
  scope: resourceGroup
  params: {
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    falconCloudRegion: falconCloudRegion
    useExistingAppRegistration: useExistingAppRegistration
    azureClientId: useExistingAppRegistration ? azureClientId : azureAppRegistration.outputs.applicationId
    azureClientSecret: useExistingAppRegistration ? azureClientSecret : ''
    azureAccountType: azureAccountType
    targetScope: targetScope
  }
  dependsOn: [
    azureAppRegistration
  ]
}

/* Update Application Registration with Falcon provided certificate */
module azureAppRegistrationUpdate 'azureAppRegistration.bicep' = if (!useExistingAppRegistration) {
  name: '${deploymentNamePrefix}-azureAppRegistrationUpdate-${deploymentNameSuffix}'
  params: {
    publicCertificate: azureAccount.outputs.azurePublicCertificate
    grantAdminConsent: grantAppRegistrationAdminConsent
  }
  dependsOn: [
    azureAccount
  ]
}

/* Assign required permissions on Azure Subscription */
module azureSubscriptionRoleAssignment 'azureSubscriptionRoleAssignment.bicep' = if (assignAzureSubscriptionPermissions) {
  name: '${deploymentNamePrefix}-azureSubscriptionRoleAssignment-${deploymentNameSuffix}'
  params: {
    azurePrincipalType: azurePrincipalType
    azurePrincipalId: useExistingAppRegistration ? azurePrincipalId : azureAppRegistration.outputs.servicePrincipalId
  }
}

/* Outputs */
output azureClientId string = useExistingAppRegistration ? azureClientId : azureAppRegistration.outputs.applicationId
output azurePrincipalId string = useExistingAppRegistration
  ? azurePrincipalId
  : azureAppRegistration.outputs.servicePrincipalId
output azurePublicCertificate string = azureAccount.outputs.azurePublicCertificate
