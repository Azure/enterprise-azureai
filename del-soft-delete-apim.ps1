param ($subscriptionId, $apimName)

$location = "FranceCentral"
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

#you could also use az cli
# az apim deletedservice purge --location $location --service-name $apimName