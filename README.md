![CrowdStrike Falcon](https://raw.githubusercontent.com/CrowdStrike/falconpy/main/docs/asset/cs-logo.png)

# Falcon Cloud Security Registration with Azure Bicep

The Azure Bicep templates in this repository allow for an easy and seamless integration of Azure environments into CrowdStrike Falcon Cloud Security.

## Deployment using Azure CLI

### Register an Azure management group

The command below registers an Azure management group, including all Azure subscriptions, into Falcon Cloud Security by performing the following actions:

- Creates an app registration in Microsoft Entra ID, including Microsoft Graph API permissions and administrative consent
- Assigns the following Azure RBAC permissions to the created app registration on the Azure management group:
  - Reader
  - Security Reader
  - Key Vault Reader
  - Azure Kubernetes Service RBAC Reader
- Assigns the **cs-website-reader** custom role on the subscription with the following actions:
  - Microsoft.Web/sites/Read
  - Microsoft.Web/sites/config/Read
  - Microsoft.Web/sites/config/list/Action
- Creates an Azure policy definition and management group assignment to create Azure subscription diagnostic settings
- Creates Microsoft Entra ID diagnostic setting
- Deploys infrastructure for Indicator of Attack (IOA) assessment
- Integrates the subscription into Falcon Cloud Security for Indicator of Misconfiguration (IOM) and Indicator of Attack (IOA) assessment

> [!IMPORTANT]
> Registration only supports the Azure root management group (Tenant root group).

#### Prerequisite

Ensure you have a CrowdStrike API client ID and client secret for Falcon Cloud Security. If you don't, you can set them up in the Falcon console:

- [US-1](https://falcon.crowdstrike.com/api-clients-and-keys/)
- [US-2](https://falcon.us-2.crowdstrike.com/api-clients-and-keys/)
- [EU](https://falcon.eu-1.crowdstrike.com/api-clients-and-keys/clients)

#### Required permissions

- **Application Developer**, **Cloud Application Administrator**, or **Application Administrator** role in Microsoft Entra ID to create the app registration in Microsoft Entra ID
- **Privileged Role Administrator** or **Global Administrator** role in Microsoft Entra ID to provide administrative consent to the requested Microsoft Graph API permissions.

  > [!NOTE]
  > Use the optional `grantAdminConsent` parameter to disable granting administrative consent to the requested Microsoft Graph API permissions automatically.

- **Owner** role for the Azure management group to be integrated into Falcon Cloud Security
- **Owner** role for the Azure subscription to be used for deployment of the infrastructure for Indicator of Attack (IOA) assessment

#### Deployment command

```sh
az deployment mg create --name 'cs-fcs-managementgroup-deployment' --location westeurope \
  --management-group-id $(az account show --query tenantId -o tsv) \
  --template-file cs-fcs-deployment-managementGroup.bicep \
  --only-show-errors
```

#### Remediate Azure Policy Assignment

To enable indicators of attack (IOAs) for all the already existing subscriptions, you must remediate the **cs-ioa-assignment** Azure policy assignment manually.

1. In the Azure portal, navigate to **Management Groups** and select the tenant root group.
2. Go to **Governance** > **Policy** and select **Authoring** > **Assignments**.
3. Click the **cs-ioa-assignment** assignment and then remediate the assignment by [creating a remediation task from a non-compliant policy assignment](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources?tabs=azure-portal#option-2-create-a-remediation-task-from-a-non-compliant-policy-assignment).
4. Click **Validate** to return to the cloud accounts page. Allow about two hours for the data to be available.

#### Parameters

You can use any of these methods to pass parameters:

- Generate a parameter file: [generate-params](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-cli#generate-params)
- Deploy the Bicep file using the parameters file: [deploy bicep file with parameters file](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameter-files?tabs=Bicep#deploy-bicep-file-with-parameters-file)
- Pass the parameters as arguments: [inline-parameters](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli#inline-parameters)

| Parameter name                          | Required | Description                                                                                                                    |
|-----------------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------|
| `defaultSubscriptionId`                 | yes      | Subscription Id of the default Azure Subscription.                                                                             |
| `falconCID`                             | yes      | CID for the Falcon API.                                                                                                        |
| `falconClientId`                        | yes      | Client ID for the Falcon API.                                                                                                  |
| `falconClientSecret`                    | yes      | Client secret for the Falcon API.                                                                                              |
| `falconCloudRegion`                     | no       | Falcon cloud region. Defaults to `US-1`. Allowed values are `US-1`, `US-2`, or `EU-1`.                                         |
| `useExistingAppRegistration`            | no       | Use an existing Application Registration. Defaults to `false`.                                                                 |
| `grantAppRegistrationAdminConsent`      | no       | Grant admin consent for Application Registration. Defaults to `true`.                                                          |
| `azureClientId`                         | no       | Application Id of an existing Application Registration in Entra ID. Only used with parameter `useExistingAppRegistration`.     |
| `azureClientSecret`                     | no       | Application Secret of an existing Application Registration in Entra ID. Only used with parameter `useExistingAppRegistration`. |
| `azurePrincipalId`                      | no       | Principal Id of the Application Registration in Entra ID. Only used with parameter `useExistingAppRegistration`.               |
| `azureAccountType`                      | no       | Type of the Azure account to integrate.                                                                                        |
| `location`                              | no       | Location for the resources deployed in this solution.                                                                          |
| `tags`                                  | no       | Tags to be applied to all resources.                                                                                           |
| `deployIOM`                             | no       | Deploy Indicator of Misconfiguration (IOM) integration. Defaults to `true`.                                                    |
| `assignAzureSubscriptionPermissions`    | no       | Assign required permissions on Azure Default Subscription automatically. Defaults to `false`.                                  |
| `assignAzureManagementGroupPermissions` | no       | Assign required permissions Azure Management Group automatically. Defaults to `true`.                                          |
| `deployIOA`                             | no       | Deploy Indicator of Attack (IOA) integration. Defaults to `true`.                                                              |
| `enableAppInsights`                     | no       | Enable Application Insights for additional logging of Function Apps. Defaults to `false`.                                      |
| `deployActivityLogDiagnosticSettings`   | no       | Deploy Activity Log Diagnostic Settings. Defaults to `true`.                                                                   |
| `deployEntraLogDiagnosticSettings`      | no       | Deploy Entra Log Diagnostic Settings. Defaults to `true`.                                                                      |

### Register a single Azure Subscription

The command below registers a single Azure Subscription into Falcon Cloud Security by performing the following actions:

- Creates an app registration in Microsoft Entra ID, including Microsoft Graph API permissions and administrative consent
- Creates Microsoft Azure activity log diagnostic setting
- Creates Microsoft Entra ID diagnostic setting
- Assigns the following Azure RBAC permissions on the Azure Subscription
  - Reader
  - Security Reader
  - Key Vault Reader
  - Azure Kubernetes Service RBAC Reader
- Assigns the **cs-website-reader** custom role on the Subscription with the following actions
  - Microsoft.Web/sites/Read
  - Microsoft.Web/sites/config/Read
  - Microsoft.Web/sites/config/list/Action
- Deploys infrastructure for Indicator of Attack (IOA) assessment
- Integrates the Subscription into the CrowdStrike Falcon Cloud Security for Indicator of Misconfiguration (IOM) and Indicator of Attack (IOA) assessment

#### Prerequisite

Ensure you have a CrowdStrike API client ID and client secret for Falcon Cloud Security. If you don't, you can set them up in the Falcon console:

- [US-1](https://falcon.crowdstrike.com/api-clients-and-keys/)
- [US-2](https://falcon.us-2.crowdstrike.com/api-clients-and-keys/)
- [EU](https://falcon.eu-1.crowdstrike.com/api-clients-and-keys/clients)

#### Required permissions

- **Application Developer**, **Cloud Application Administrator**, or **Application Administrator** role in Microsoft Entra ID to create the app registration in Microsoft Entra ID
- **Privileged Role Administrator** or **Global Administrator** role in Microsoft Entra ID to provide administrative consent to the requested Microsoft Graph API permissions.

  > [!NOTE]
  > Use the optional `grantAdminConsent` parameter to disable granting administrative consent to the requested Microsoft Graph API permissions automatically.

- **Owner** role of the Azure subscription to be integrated into CrowdStrike Falcon Cloud Security

#### Deployment command

```sh
az deployment sub create --name 'cs-fcs-subscription-deployment' --location westeurope \
  --template-file cs-fcs-deployment-subscription.bicep \
  --only-show-errors
```

> [!NOTE]
> The deployment command can be executed multiple times to register additional Azure subscriptions into CrowdStrike Falcon Cloud Security.

#### Parameters

You can use any of these methods to pass parameters:

- Generate a parameter file: [generate-params](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/bicep-cli#generate-params)
- Deploy the Bicep file using the parameters file: [deploy bicep file with parameters file](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/parameter-files?tabs=Bicep#deploy-bicep-file-with-parameters-file)
- Pass the parameters as arguments: [inline-parameters](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli#inline-parameters)

| Parameter name                        | Required | Description                                                                                                                    |
|---------------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------|
| `defaultSubscriptionId`               | yes      | Subscription Id of the default Azure Subscription.                                                                             |
| `falconCID`                           | yes      | CID for the Falcon API.                                                                                                        |
| `falconClientId`                      | yes      | Client ID for the Falcon API.                                                                                                  |
| `falconClientSecret`                  | yes      | Client secret for the Falcon API.                                                                                              |
| `falconCloudRegion`                   | no       | Falcon cloud region. Defaults to `US-1`. Allowed values are `US-1`, `US-2`, or `EU-1`.                                         |
| `useExistingAppRegistration`          | no       | Use an existing Application Registration. Defaults to `false`.                                                                 |
| `grantAppRegistrationAdminConsent`    | no       | Grant admin consent for Application Registration. Defaults to `true`.                                                          |
| `azureClientId`                       | no       | Application Id of an existing Application Registration in Entra ID. Only used with parameter `useExistingAppRegistration`.     |
| `azureClientSecret`                   | no       | Application Secret of an existing Application Registration in Entra ID. Only used with parameter `useExistingAppRegistration`. |
| `azurePrincipalId`                    | no       | Principal Id of the Application Registration in Entra ID. Only used with parameter `useExistingAppRegistration`.               |
| `azureAccountType`                    | no       | Type of the Azure account to integrate.                                                                                        |
| `location`                            | no       | Location for the resources deployed in this solution.                                                                          |
| `tags`                                | no       | Tags to be applied to all resources.                                                                                           |
| `deployIOM`                           | no       | Deploy Indicator of Misconfiguration (IOM) integration. Defaults to `true`.                                                    |
| `assignAzureSubscriptionPermissions`  | no       | Assign required permissions on Azure Default Subscription automatically. Defaults to `true`.                                   |
| `deployIOA`                           | no       | Deploy Indicator of Attack (IOA) integration. Defaults to `true`.                                                              |
| `enableAppInsights`                   | no       | Enable Application Insights for additional logging of Function Apps. Defaults to `false`.                                      |
| `deployActivityLogDiagnosticSettings` | no       | Deploy Activity Log Diagnostic Settings. Defaults to `true`.                                                                   |
| `deployEntraLogDiagnosticSettings`    | no       | Deploy Entra Log Diagnostic Settings. Defaults to `true`.                                                                      |

## Contributing

If you want to develop new content or improve on this collection, please open an issue or create a pull request. All contributions are welcome!

## Support

This is a community-driven, open source project aimed to register Falcon Cloud Security with Azure using Bicep. While not an official CrowdStrike product, this repository is maintained by CrowdStrike and supported in collaboration with the open source developer community.

For additional information, please refer to the [SUPPORT.md](https://github.com/CrowdStrike/fcs-azure-bicep/main/SUPPORT.md) file.

## License Information

See the [LICENSE](https://github.com/CrowdStrike/fcs-azure-bicep/main/LICENSE) for more information.
