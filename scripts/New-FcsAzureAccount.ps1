param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("commercial")]
    [string]$AzureAccountType = "commercial",

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$')]
    [string]$AzureTenantId,

    [Parameter(Mandatory = $true)]
    [ValidateSet("ManagementGroup", "Subscription")]
    [string]$TargetScope,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$')]
    [string]$AzureSubscriptionId,

    [Parameter(Mandatory = $false)]
    [int]$AzureYearsValid = 1,

    [Parameter(Mandatory = $true)]
    [string]$UseExistingAppRegistration
)

# Falcon variables
switch ($Env:FALCON_CLOUD_REGION) {
    US-1 {
        $FALCON_API_BASE_URL = "api.crowdstrike.com"
    }
    US-2 {
        $FALCON_API_BASE_URL = "api.us-2.crowdstrike.com"
    }
    EU-1 {
        $FALCON_API_BASE_URL = "api.eu-1.crowdstrike.com"
    }
    Default {
        $FALCON_API_BASE_URL = "api.crowdstrike.com"
    }
}

# Get CrowdStrike API Access Token
function Get-FalconAPIAccessToken {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$ClientSecret
    )
    try {
        $Params = @{
            Uri     = "https://${FALCON_API_BASE_URL}/oauth2/token"
            Method  = "POST"
            Headers = @{
                "Content-Type" = "application/x-www-form-urlencoded"
            }
            Body    = @{
                client_id     = $ClientId
                client_secret = $ClientSecret
            }
        }
        return ((Invoke-WebRequest @Params).Content | ConvertFrom-Json).access_token
    }
    catch [System.Exception] {
        Write-Error "An exception was caught: $($_.Exception.Message)"
        break
    }
}

function Set-AzureAppRegistrationCertificate {
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$')]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$')]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$ClientSecret,

        [Parameter(Mandatory = $true)]
        [string]$ClientCertificate
    )
    try {
        $secureClientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $clientCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $secureClientSecret

        Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $clientCredential -ErrorAction Stop

        Set-AzContext -Subscription $SubscriptionId -ErrorAction Stop

        $appRegistration = Get-AzADAppCredential -ApplicationId $ClientId | Where-Object { $_.DisplayName -eq "O=CrowdStrike" } -ErrorAction Stop

        if ($appRegistration) {
            # Filter the existing certificates to only include those with DisplayName "O=CrowdStrike"
            $currentCerts = $appRegistration | Where-Object { $_.DisplayName -eq "O=CrowdStrike" }

            # Remove the existing certificates
            foreach ($cert in $currentCerts) {
                Remove-AzADAppCredential -ApplicationId $ClientId -KeyId $cert.KeyId
            }

            # Add the new certificate
            New-AzADAppCredential -ApplicationId $ClientId -CertValue $ClientCertificate -ErrorAction Stop
        }
    }
    catch [System.Exception] { 
        Write-Error "An exception was caught: $($_.Exception.Message)"
        break
    } 
    finally {
        Disconnect-AzAccount
    }
}

function New-FalconCloudAzureAccount {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $true)]
        [string]$AccountType,

        [Parameter(Mandatory = $true)]
        [string]$YearsValid
    )
    try {
        $Uri     = "https://${FALCON_API_BASE_URL}/cloud-connect-cspm-azure/entities/account/v1"
        $Method  = "POST"
        $Headers = @{
                "Authorization" = "Bearer ${AccessToken}"
            }
        $Body = @{
            "resources" = @(
                @{
                    "account_type" = $accountType
                    "client_id" = $clientId
                    "subscription_id" = $subscriptionId
                    "tenant_id" = $tenantId
                    "years_valid" = $yearsValid
                }
            )
        }
        # Create CSPM account
        Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -ContentType 'application/json' -Body (ConvertTo-Json @body)
    }
    catch [System.Exception] {
        Write-Error "An exception was caught: $($_.Exception.Message)"
        break
    }
}

function New-FalconCloudAzureGroup {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$DefaultSubscriptionId
    )
    try {
        $Uri     = "https://${FALCON_API_BASE_URL}/cloud-connect-cspm-azure/entities/management-group/v1"
        $Method  = "POST"
        $Headers = @{
            "Authorization" = "Bearer ${AccessToken}"
        }
        $Body = @{
            "resources" = @(
                @{
                    "default_subscription_id" = $defaultSubscriptionId
                    "tenant_id" = $tenantId
                }
            )
        }
        # Create CSPM account
        Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -ContentType 'application/json' -Body (ConvertTo-Json @body)
    }
    catch [System.Exception] {
        Write-Error "An exception was caught: $($_.Exception.Message)"
        break
    }
}

function Get-FalconCloudAzureCertificate {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessToken,

        [Parameter(Mandatory = $true)]
        [string]$TenantId
    )
    try {
        $Params = @{
            Uri     = "https://${FALCON_API_BASE_URL}/cloud-connect-cspm-azure/entities/download-certificate/v1"
            Method  = "GET"
            Headers = @{
                "Authorization" = "Bearer ${AccessToken}",
                "Content-Type" = "application/x-www-form-urlencoded"
            }
            Body    = @{
                tenant_id = $tenantId
            }
        }
        return ((Invoke-WebRequest @Params).Content | ConvertFrom-Json)
    }
    catch [System.Exception] {
        Write-Error "An exception was caught: $($_.Exception.Message)"
        break
    }
}

try {
    $DeploymentScriptOutputs = @{}

    $AccessToken = $(Get-FalconAPIAccessToken -ClientId ${Env:FALCON_CLIENT_ID} -ClientSecret ${Env:FALCON_CLIENT_SECRET})

    # Register Azure account in Falcon Cloud Security
    New-FalconCloudAzureAccount -AccessToken $AccessToken -TenantId $AzureTenantId -SubscriptionId $AzureSubscriptionId -ClientId $Env:AZURE_CLIENT_ID -AccountType $AzureAccountType -YearsValid $AzureYearsValid

    # Register Azure Management Group in Falcon Cloud Security
    if ($TargetScope -eq 'ManagementGroup') {
        New-FalconCloudAzureGroup -TenantId $AzureTenantId -DefaultSubscriptionId $AzureSubscriptionId 
    }

    # Get Falcon Azure Application certificate
    $azurePublicCertificate = (Get-FalconCloudAzureCertificate -TenantId $AzureTenantId).public_certificate

    # Add certificate to existing Azure Application Registration
    if([System.Convert]::ToBoolean($UseExistingAppRegistration)) {
        Set-AzureAppRegistrationCertificate -TenantId $AzureTenantId -SubscriptionId $AzureSubscriptionId -ClientId ${Env:AZURE_CLIENT_ID} -ClientSecret ${Env:AZURE_CLIENT_SECRET} -ClientCertificate $azurePublicCertificate
    }
    
    $DeploymentScriptOutputs['public_certificate'] = $azurePublicCertificate
}
catch {
    Write-Error "An exception was caught: $($_.Exception.Message)"
    break
}
