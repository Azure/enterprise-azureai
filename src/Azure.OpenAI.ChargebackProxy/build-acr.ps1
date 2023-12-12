param (
    [Parameter(Mandatory = $true)]
    [string]$RegistryName,
    [Parameter(Mandatory = $true)]
    [string]$Tag
)
az acr build --registry $RegistryName -t "$RegistryName.azurecr.io/openai-chargebackproxy:$Tag" --file .\Dockerfile --platform linux ..
