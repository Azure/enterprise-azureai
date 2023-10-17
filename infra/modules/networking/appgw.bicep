param name string 
param location string = resourceGroup().location
param appgwSubnetId string
param appgwPublicIpId string
param logAnalyticsWorkspaceId string
param appgw_sku string = 'WAF_v2'
param apigwBackendHostname string = 'go.apifirst.internal'
param portalBackendHostname string = 'portal.apifirst.internal'
param mgmtBackendHostname string = 'mgmt.apifirst.internal'
param tags object = {}

var appgw_id = resourceId('Microsoft.Network/applicationGateways', name)

resource appgw 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: name
  location: location
  tags: tags
  properties:{
    sku:{
      name:appgw_sku
      tier:appgw_sku
    }
    enableHttp2:true
    autoscaleConfiguration:{
      minCapacity: 1
      maxCapacity: 2
    }
    webApplicationFirewallConfiguration:{
      enabled:true
      firewallMode:'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.1'
      disabledRuleGroups:[
        {
          ruleGroupName: 'REQUEST-920-PROTOCOL-ENFORCEMENT'
          rules:[
            920320
          ]
        }
      ]
      exclusions:[
        
      ]
      requestBodyCheck:false
    }
    probes:[
      {
        name: 'apimgw-probe'
        properties:{
          pickHostNameFromBackendHttpSettings:true
          interval:30
          timeout:30
          path: '/status-0123456789abcdef'
          protocol:'Https'
          unhealthyThreshold:3
          match:{
            statusCodes:[
              '200-399'
            ]
          }
        }
      }
      {
        name: 'apimportal-probe'
        properties:{
          pickHostNameFromBackendHttpSettings:true
          interval:30
          timeout:30
          path: '/signin'
          protocol:'Https'
          unhealthyThreshold:3
          match:{
            statusCodes:[
              '200-399'
              '404'
            ]
          }
        }
      }            
    ]
    gatewayIPConfigurations:[
      {
        name: 'appgw-ip-config'
        properties:{
          subnet:{
            id: appgwSubnetId
          }
        }
      }
    ]
    frontendIPConfigurations:[
      { 
        name:'appgw-public-frontend-ip'
        properties:{
          publicIPAddress:{
            id: appgwPublicIpId
          }
        }
      }
    ]
    frontendPorts:[
      {
        name: 'port_443'
        properties:{
          port: 443
        }
      }
    ]
    backendAddressPools:[
      { 
        name: 'backend-apigw'
        properties:{
          backendAddresses:[
            {
              fqdn: apigwBackendHostname
            }
          ]
        }
      }
      { 
        name: 'backend-mgmt'
        properties:{
          backendAddresses:[
            {
              fqdn: mgmtBackendHostname
            }
          ]
        }
      }
      { 
        name: 'backend-portal'
        properties:{
          backendAddresses:[
            {
              fqdn: portalBackendHostname
            }
          ]
        }
      }            
    ]
    backendHttpSettingsCollection:[
     {
       name: 'apim_gw_httpsetting'
       properties:{
         port: 443
         protocol:'Https'
         cookieBasedAffinity:'Disabled'
         requestTimeout: 120
         connectionDraining:{
           enabled:true
           drainTimeoutInSec: 20
         }
         pickHostNameFromBackendAddress:true
         probe:{
          id: concat(appgw_id, '/probes/apimgw-probe')
         }
         trustedRootCertificates:[
           {
            id: concat(appgw_id, '/trustedRootCertificates/root_cert_internaldomain')
           }
         ]
       }
     } 
     {
      name: 'apim_portal_httpsetting'
      properties:{
        port: 443
        protocol:'Https'
        cookieBasedAffinity:'Disabled'
        requestTimeout: 120
        connectionDraining:{
          enabled:true
          drainTimeoutInSec: 20
        }
        pickHostNameFromBackendAddress:true
        probe:{
         id: concat(appgw_id, '/probes/apimportal-probe')
        }
        trustedRootCertificates:[
          {
           id: concat(appgw_id, '/trustedRootCertificates/root_cert_internaldomain')
          }
        ]
      }
     } 
     {
      name: 'apim_mgmt_httpsetting'
      properties:{
        port: 443
        hostName: mgmtBackendHostname
        protocol:'Https'
        cookieBasedAffinity:'Disabled'
        requestTimeout: 120
        connectionDraining:{
          enabled:true
          drainTimeoutInSec: 20
        }
        pickHostNameFromBackendAddress:false
        probe:{
         id: concat(appgw_id, '/probes/apimgw-probe')
        }
        trustedRootCertificates:[
          {
           id: concat(appgw_id, '/trustedRootCertificates/root_cert_internaldomain')
          }
        ]
      }
     }            
    ]
    httpListeners:[
      {
        name: 'apigw-https-listener'
        properties:{
          protocol:'Https'
          frontendIPConfiguration:{
            id: concat(appgw_id, '/frontendIPConfigurations/appgw-public-frontend-ip')
          }
          frontendPort:{
            id: concat(appgw_id, '/frontendPorts/port_443')
          }
          sslCertificate:{
            id: concat(appgw_id, '/sslCertificates/ssl-appgw-external')
          }
        }
      }
      {
        name: 'apiportal-https-listener'
        properties:{
          protocol:'Https'
          frontendIPConfiguration:{
            id: concat(appgw_id, '/frontendIPConfigurations/appgw-public-frontend-ip')
          }
          frontendPort:{
            id: concat(appgw_id, '/frontendPorts/port_443')
          }
          sslCertificate:{
            id: concat(appgw_id, '/sslCertificates/ssl-portal-external')
          }
        }
      }
      {
        name: 'apimgmt-https-listener'
        properties:{
          protocol:'Https'
          frontendIPConfiguration:{
            id: concat(appgw_id, '/frontendIPConfigurations/appgw-public-frontend-ip')
          }
          frontendPort:{
            id: concat(appgw_id, '/frontendPorts/port_443')
          }
          sslCertificate:{
            id: concat(appgw_id, '/sslCertificates/ssl-mgmt-external')
          }
        }
      }            
    ]
    rewriteRuleSets:[
      {
        name: 'default-rewrite-rules'
        properties:{
          rewriteRules:[
            {
              ruleSequence : 1000
              conditions:[
              ]
              name: 'HSTS header injection'
              actionSet:{
                requestHeaderConfigurations:[
                  
                ]
                responseHeaderConfigurations:[
                  {
                    headerName: 'Strict-Transport-Security'
                    headerValue: 'max-age=31536000; includeSubDomains'
                  }
                ]
              }
            }
          ]
        }
      }
    ]
    requestRoutingRules:[
      {
        name: 'routing-apigw'
        properties:{
          ruleType:'Basic'
          httpListener:{
            id: concat(appgw_id, '/httpListeners/apigw-https-listener')
          }
          backendAddressPool:{
            id: concat(appgw_id, '/backendAddressPools/backend-apigw')
          }
          backendHttpSettings:{
            id: concat(appgw_id, '/backendHttpSettingsCollection/apim_gw_httpsetting')
          }
          rewriteRuleSet:{
            id: concat(appgw_id, '/rewriteRuleSets/default-rewrite-rules')
          }
        }
      }
      {
        name: 'routing-apiportal'
        properties:{
          ruleType:'Basic'
          httpListener:{
            id: concat(appgw_id, '/httpListeners/apiportal-https-listener')
          }
          backendAddressPool:{
            id: concat(appgw_id, '/backendAddressPools/backend-portal')
          }
          backendHttpSettings:{
            id: concat(appgw_id, '/backendHttpSettingsCollection/apim_portal_httpsetting')
          }
          rewriteRuleSet:{
            id: concat(appgw_id, '/rewriteRuleSets/default-rewrite-rules')
          }
        }
      }
      {
        name: 'routing-apimgmt'
        properties:{
          ruleType:'Basic'
          httpListener:{
            id: concat(appgw_id, '/httpListeners/apimgmt-https-listener')
          }
          backendAddressPool:{
            id: concat(appgw_id, '/backendAddressPools/backend-mgmt')
          }
          backendHttpSettings:{
            id: concat(appgw_id, '/backendHttpSettingsCollection/apim_mgmt_httpsetting')
          }
          rewriteRuleSet:{
            id: concat(appgw_id, '/rewriteRuleSets/default-rewrite-rules')
          }
        }
      }            
    ]
  }
}

resource diagSettings 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
 name: 'writeToLogAnalytics'
 scope: appgw
 properties:{
  workspaceId : logAnalyticsWorkspaceId
   logs:[
     {
       category: 'ApplicationGatewayAccessLog'
       enabled:true
       retentionPolicy:{
         enabled:true
         days: 20
       }
     }
     {
      category: 'ApplicationGatewayPerformanceLog'
      enabled:true
      retentionPolicy:{
        enabled:true
        days: 20
      }
    }  
    {
      category: 'ApplicationGatewayFirewallLog'
      enabled:true
      retentionPolicy:{
        enabled:true
        days: 20
      }
    }           
   ]
   metrics:[
     {
       enabled:true
       timeGrain: 'PT1M'
       retentionPolicy:{
        enabled:true
        days: 20
      }
     }
   ]
 }
}

output appgwResourceId string = appgw.id
