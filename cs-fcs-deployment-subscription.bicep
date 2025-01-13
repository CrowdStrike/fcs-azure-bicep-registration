targetScope = 'subscription'

/*
  This Bicep template deploys CrowdStrike Falcon Cloud Security integration for
  Indicator of Misconfiguration (IOM) and Indicator of Attack (IOA) assessment.

  Copyright (c) 2024 CrowdStrike, Inc.
*/

/* Parameters */
@description('Targetscope of the Falcon Cloud Security integration.')
@allowed([
  'ManagementGroup'
  'Subscription'
])
param targetScope string = 'Subscription'

@description('The prefix to be added to the deployment name.')
param deploymentNamePrefix string = 'cs-fcs'

@description('The suffix to be added to the deployment name.')
param deploymentNameSuffix string = utcNow()

@description('Name of the resource group.')
param resourceGroupName string = 'cs-iom-group' // DO NOT CHANGE

@description('CID for the Falcon API.')
param falconCID string

@description('Client ID for the Falcon API.')
param falconClientId string

@description('Client secret for the Falcon API.')
@secure()
param falconClientSecret string

@description('Subscription Id of the default Azure Subscription.')
param defaultSubscriptionId string

@description('Falcon cloud region. Defaults to US-1, allowed values are US-1, US-2 or EU-1.')
@allowed([
  'US-1'
  'US-2'
  'EU-1'
])
param falconCloudRegion string = 'US-1'

@description('Use an existing Application Registration. Defaults to false.')
param useExistingAppRegistration bool = false

@description('Grant admin consent for Application Registration. Defaults to true.')
param grantAppRegistrationAdminConsent bool = true

@description('Application Id of an existing Application Registration in Entra ID. Only used with parameter useExistingAppRegistration.')
param azureClientId string = ''

@description('Application Secret of an existing Application Registration in Entra ID. Only used with parameter useExistingAppRegistration.')
@secure()
param azureClientSecret string = ''

@description('Principal Id of the Application Registration in Entra ID. Only used with parameter useExistingAppRegistration.')
param azurePrincipalId string = ''

@description('Type of the Azure account to integrate.')
@allowed([
  'commercial'
])
param azureAccountType string = 'commercial'

@description('Location for the resources deployed in this solution.')
param location string = deployment().location

@description('Tags to be applied to all resources.')
param tags object = {
  'cstag-vendor': 'crowdstrike'
  'cstag-product': 'fcs'
}

/* IOM-specific parameter */
@description('Deploy Indicator of Misconfiguration (IOM) integration. Defaults to true.')
param deployIOM bool = true

@description('Assign required permissions on Azure Default Subscription automatically. Defaults to true.')
param assignAzureSubscriptionPermissions bool = true

/* IOA-specific parameter */
@description('Deploy Indicator of Attack (IOA) integration. Defaults to true.')
param deployIOA bool = true

@description('Enable Application Insights for additional logging of Function Apps. Defaults to false.')
#disable-next-line no-unused-params
param enableAppInsights bool = false

@description('Deploy Activity Log Diagnostic Settings. Defaults to true.')
param deployActivityLogDiagnosticSettings bool = true

@description('Deploy Entra Log Diagnostic Settings. Defaults to true.')
param deployEntraLogDiagnosticSettings bool = true

/* Resources */
module iomAzureSubscription 'modules/iom/azureSubscription.bicep' = if (deployIOM && targetScope == 'Subscription') {
  name: '${deploymentNamePrefix}-iom-azureSubscription-${deploymentNameSuffix}'
  scope: subscription()
  params: {
    targetScope: targetScope
    resourceGroupName: resourceGroupName
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    falconCloudRegion: falconCloudRegion
    useExistingAppRegistration: useExistingAppRegistration
    grantAppRegistrationAdminConsent: grantAppRegistrationAdminConsent
    azureClientId: useExistingAppRegistration ? '' : azureClientId
    azureClientSecret: useExistingAppRegistration ? '' : azureClientSecret
    azurePrincipalId: useExistingAppRegistration ? '' : azurePrincipalId
    azureAccountType: azureAccountType
    assignAzureSubscriptionPermissions: assignAzureSubscriptionPermissions
    location: location
    tags: tags
  }
}

module ioaAzureSubscription 'modules/cs-fcs-ioa-deployment.bicep' = if (deployIOA && targetScope == 'Subscription') {
  name: '${deploymentNamePrefix}-ioa-azureSubscription-${deploymentNameSuffix}'
  scope: subscription(defaultSubscriptionId)
  params:{
    falconCID: falconCID
    falconClientId: falconClientId
    falconClientSecret: falconClientSecret
    defaultSubscriptionId: defaultSubscriptionId
    subscriptionId: subscription().subscriptionId
    falconCloudRegion: falconCloudRegion
    enableAppInsights: enableAppInsights
    deployActivityLogDiagnosticSettings: deployActivityLogDiagnosticSettings
    deployEntraLogDiagnosticSettings: deployEntraLogDiagnosticSettings
    location: location
    tags: tags
  }
}
