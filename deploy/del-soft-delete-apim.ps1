param ($subscriptionId, $apimName)

$location = "West Europe"
$token = Get-AzAccessToken
$uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.ApiManagement/locations/$location/deletedservices/$apimName/?api-version=2020-12-01"

$request = @{
    Method = "DELETE"
    Uri    = $uri
    Headers = @{
        Authorization = "Bearer $($token.Token)"
    }
}

Invoke-RestMethod @request