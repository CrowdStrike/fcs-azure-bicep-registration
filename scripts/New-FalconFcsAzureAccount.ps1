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

try {
    $DeploymentScriptOutputs = @{}

    # Check if the PSFalcon module is available
    if (!(Get-Module -Name PSFalcon)) {
        if (!(Get-Module -ListAvailable -Name PSFalcon)) {
            Install-Module -Name PSFalcon -Force
        }
        Import-Module -Name PSFalcon
    }

    # Request Falcon API access token
    Request-FalconToken -ClientId $Env:FALCON_CLIENT_ID -ClientSecret $Env:FALCON_CLIENT_SECRET -Cloud $($Env:FALCON_CLOUD_REGION.ToLower())

    # Register Azure account in Falcon Cloud Security
    New-FalconCloudAzureAccount -TenantId $AzureTenantId -SubscriptionId $AzureSubscriptionId -ClientId $Env:AZURE_CLIENT_ID -AccountType $AzureAccountType -YearsValid $AzureYearsValid

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
