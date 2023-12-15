param dnsZoneName string 
param ipAddress string
param hostname string

resource dnsEntry 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name :  '${dnsZoneName}/${hostname}'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: ipAddress
      }
    ]
  }
}
