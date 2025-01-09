// Parameters
param location string
param sqlServerName string
param sqlAdminUsername string
@secure()
param sqlAdminPassword string
param adminGroupId string
param userGroupId string
param keyVaultName string
param backendAppName string
param frontendAppName string
param backendPlanName string
param frontendPlanName string
param acrName string // Added ACR name parameter for Docker image references

// Resources

// Azure SQL Server
resource sqlServer 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: 'dtaskdb'
  parent: sqlServer
  location: location
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
    sampleName: 'AdventureWorksLT'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: adminGroupId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
            'delete'
          ]
        }
      }
      {
        tenantId: subscription().tenantId
        objectId: userGroupId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${keyVaultName}-appinsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: '${keyVaultName}-loganalytics'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'monitoring'
  scope: keyVault
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
  }
}

// Backend App Service Plan
resource backendPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: backendPlanName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
}

// Frontend App Service Plan
resource frontendPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: frontendPlanName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${backendAppName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Backend App Service
resource backendApp 'Microsoft.Web/sites@2021-02-01' = {
  name: backendAppName
  location: location
  properties: {
    serverFarmId: backendPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AZURE_SQL_CONNECTION_STRING'
          value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName};Initial Catalog=mydatabase;Persist Security Info=False;User ID=${sqlAdminUsername};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
        }
        {
          name: 'PORT'
          value: '8080'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrName}.azurecr.io'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: '$(acrName)'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: '$(acrPassword)'
        }
      ]
      linuxFxVersion: 'DOCKER|${acrName}.azurecr.io/backend:latest'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
      sqlDatabase
      nsg
  ]
}

// Frontend App Service
resource frontendApp 'Microsoft.Web/sites@2021-02-01' = {
  name: frontendAppName
  location: location
  properties: {
    serverFarmId: frontendPlan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'REACT_APP_API_URL'
          value: 'https://${backendApp.properties.defaultHostName}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrName}.azurecr.io'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: '$(acrName)'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: '$(acrPassword)'
        }
      ]
      linuxFxVersion: 'DOCKER|${acrName}.azurecr.io/frontend:latest'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    nsg
  ]
}

// Auto-scaling for backend
resource backendAutoScale 'Microsoft.Insights/autoscaleSettings@2021-05-01-preview' = {
  name: '${backendAppName}-autoscale'
  location: location
  properties: {
    profiles: [
      {
        name: 'AutoScaleProfile'
        capacity: {
          minimum: '1'
          maximum: '10'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'Microsoft.Web/serverfarms'
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
              metricResourceUri: backendPlan.id
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT1M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'Microsoft.Web/serverfarms'
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
              metricResourceUri: backendPlan.id
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT1M'
            }
          }
        ]
      }
    ]
    enabled: true
    targetResourceUri: backendPlan.id
  }
  dependsOn: []
}

// Auto-scaling for frontend
resource frontendAutoScale 'Microsoft.Insights/autoscaleSettings@2021-05-01-preview' = {
  name: '${frontendAppName}-autoscale'
  location: location
  properties: {
    profiles: [
      {
        name: 'AutoScaleProfileFrontend'
        capacity: {
          minimum: '1'
          maximum: '10'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'Microsoft.Web/serverfarms'
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
              metricResourceUri: frontendPlan.id
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT1M'
            }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'Microsoft.Web/serverfarms'
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
              metricResourceUri: frontendPlan.id
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT1M'
            }
          }
        ]
      }
    ]
    enabled: true
    targetResourceUri: frontendPlan.id
  }
  dependsOn: []
}



