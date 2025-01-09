
Here’s a comprehensive **`README.md`** for the project. It includes instructions for setting up, deploying, and using the infrastructure and application, as well as an overview of the architecture and components.

---

# Spring Boot React Application Deployment on Azure

This project provides a **CI/CD pipeline** and **Infrastructure as Code (IaC)** solution for deploying a Spring Boot backend and React frontend application on Azure. The infrastructure is defined using **Bicep**, and the deployment is automated using a **Bash script** (`deploy.sh`). The solution includes **autoscaling**, **monitoring**, **Azure AD authentication**, and **Key Vault integration**.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Setup and Deployment](#setup-and-deployment)
4. [CI/CD Pipeline](#cicd-pipeline)
5. [Monitoring and Auditing](#monitoring-and-auditing)
6. [Cleanup](#cleanup)
7. [Contributing](#contributing)
8. [License](#license)

---

## Architecture Overview

The architecture consists of the following components:

1. **Backend**:
   - Spring Boot application deployed to Azure App Service.
   - Uses Azure SQL Database for persistent storage.
2. **Frontend**:
   - React application deployed to Azure App Service.
   - Communicates with the backend via REST API.
3. **Infrastructure**:
   - Azure Container Registry (ACR) for storing Docker images.
   - Azure Key Vault for securely managing secrets.
   - Azure Monitor and Log Analytics for monitoring and auditing.
   - Azure AD for authentication and role-based access control.
4. **CI/CD Pipeline**:
   - GitHub Actions for building, testing, and deploying the application.

---

## Prerequisites

Before deploying the infrastructure, ensure you have the following:

1. **Azure Account**:
   - An active Azure subscription.
2. **Azure CLI**:
   - Install the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
3. **GitHub Account**:
   - A GitHub account for setting up the CI/CD pipeline.
4. **Docker**:
   - Install [Docker](https://docs.docker.com/get-docker/) for building and pushing container images.
5. **Bicep**:
   - Install the [Bicep CLI](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install).

---

## Setup and Deployment

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/spring-boot-react-example.git
cd spring-boot-react-example
```

### 2. Configure Azure CLI

Log in to your Azure account:

```bash
az login
```

Set the default subscription:

```bash
az account set --subscription <subscription-id>
```

### 3. Deploy the Infrastructure

Run the `deploy.sh` script to deploy the infrastructure:

```bash
chmod +x deploy.sh
./deploy.sh
```

This script will:
- Create a resource group.
- Provision Azure resources (SQL Database, App Services, ACR, Key Vault, etc.).
- Configure Azure AD authentication.
- Build and push Docker images to ACR.

### 4. Configure GitHub Secrets

For the CI/CD pipeline, configure the following secrets in your GitHub repository:

1. `AZURE_CREDENTIALS`: Azure service principal credentials.
2. `ACR_NAME`: Name of the Azure Container Registry.
3. `RESOURCE_GROUP`: Name of the Azure resource group.

---

## CI/CD Pipeline

The CI/CD pipeline is defined in the `.github/workflows/ci-cd.yml` file. It performs the following steps:

1. **Build and Test**:
   - Build and test the Spring Boot backend and React frontend.
2. **Build and Push Docker Images**:
   - Build Docker images for the backend and frontend and push them to ACR.
3. **Deploy Infrastructure**:
   - Deploy the infrastructure using the Bicep file.
4. **Deploy Application**:
   - Deploy the backend and frontend applications to Azure App Service.

---

## Monitoring and Auditing

The infrastructure includes **Azure Monitor** and **Log Analytics** for monitoring and auditing. You can access the monitoring data in the Azure portal:

1. **Application Insights**:
   - View application performance and error logs.
2. **Log Analytics**:
   - Query and analyze logs for auditing purposes.

--- 
##Sure, here is the full Bicep file based on the excerpts and context provided:

### Full 

main.bicep

 File
```bicep


// Parameters
param location string = resourceGroup().location
param sqlServerName string
param sqlAdminUsername string
@secure()
param sqlAdminPassword string
param sqlDatabaseName string
param acrName string
param backendAppName string
param frontendAppName string
param backendAppClientId string
param frontendAppClientId string
param azureAdTenantId string
param keyVaultAccessObjectId string
param spAppId string
@secure()
param spPassword string
param adminGroupId string
param userGroupId string

// Resources

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
    sampleName: 'AdventureWorksLT'
  }
}

// App Service Plan for Backend
resource backendPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${backendAppName}-plan'
  location: location
  sku: {
    name: 'P1v2'
    tier: 'PremiumV2'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

// App Service Plan for Frontend
resource frontendPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${frontendAppName}-plan'
  location: location
  sku: {
    name: 'P1v2'
    tier: 'PremiumV2'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

// Backend App Service
resource backendApp 'Microsoft.Web/sites@2021-02-01' = {
  name: backendAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: backendPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AZURE_AD_CLIENT_ID'
          value: backendAppClientId
        }
        {
          name: 'AZURE_AD_TENANT_ID'
          value: azureAdTenantId
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrName}.azurecr.io'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: spAppId
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: spPassword
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
    }
  }
}

// Backend App Authentication Settings
resource backendAuth 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: backendApp
  name: 'authsettings'
  properties: {
    enabled: true
    defaultProvider: 'AzureActiveDirectory'
    clientId: backendAppClientId
    allowedAudiences: [
      'https://${backendAppName}.azurewebsites.net'
    ]
    issuer: '${environment().authentication.loginEndpoint}${azureAdTenantId}/v2.0'
    additionalLoginParams: [
      'response_type=code id_token',
      'scope=openid profile email'
    ]
    unauthenticatedClientAction: 'RedirectToLoginPage'
    tokenStoreEnabled: true
    validateIssuer: true
  }
}

// Frontend App Service
resource frontendApp 'Microsoft.Web/sites@2021-02-01' = {
  name: frontendAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: frontendPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'REACT_APP_API_URL'
          value: 'https://${backendAppName}.azurewebsites.net'
        }
        {
          name: 'REACT_APP_AZURE_AD_CLIENT_ID'
          value: frontendAppClientId
        }
        {
          name: 'REACT_APP_AZURE_AD_TENANT_ID'
          value: azureAdTenantId
        }
        {
          name: 'REACT_APP_AZURE_AD_REDIRECT_URI'
          value: 'http://localhost:3000'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrName}.azurecr.io'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: spAppId
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: spPassword
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
    }
  }
}

// Frontend App Authentication Settings
resource frontendAuth 'Microsoft.Web/sites/config@2021-02-01' = {
  parent: frontendApp
  name: 'authsettings'
  properties: {
    enabled: true
    defaultProvider: 'AzureActiveDirectory'
    clientId: frontendAppClientId
    allowedAudiences: [
      'https://${frontendAppName}.azurewebsites.net'
    ]
    issuer: '${environment().authentication.loginEndpoint}${azureAdTenantId}/v2.0'
    additionalLoginParams: [
      'response_type=code id_token',
      'scope=openid profile email'
    ]
    unauthenticatedClientAction: 'RedirectToLoginPage'
    tokenStoreEnabled: true
    validateIssuer: true
  }
}

// Autoscale settings for backend
resource backendAutoscale 'Microsoft.Insights/autoscalesettings@2015-04-01' = {
  name: '${backendAppName}-autoscale'
  location: location
  properties: {
    profiles: [
      {
        name: 'defaultProfile'
        capacity: {
          minimum: '1'
          maximum: '10'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuTime' // Correct metric for App Services
              metricNamespace: 'Microsoft.Web/sites'
              metricResourceUri: backendApp.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
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
              metricName: 'CpuTime' // Correct metric for App Services
              metricNamespace: 'Microsoft.Web/sites'
              metricResourceUri: backendApp.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
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
}

// Autoscale settings for frontend
resource frontendAutoscale 'Microsoft.Insights/autoscalesettings@2015-04-01' = {
  name: '${frontendAppName}-autoscale'
  location: location
  properties: {
    profiles: [
      {
        name: 'defaultProfile'
        capacity: {
          minimum: '1'
          maximum: '10'
          default: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuTime' // Correct metric for App Services
              metricNamespace: 'Microsoft.Web/sites'
              metricResourceUri: frontendApp.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
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
              metricName: 'CpuTime' // Correct metric for App Services
              metricNamespace: 'Microsoft.Web/sites'
              metricResourceUri: frontendApp.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
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
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: '${acrName}-kv'
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
        objectId: keyVaultAccessObjectId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
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

// Log Analytics Workspace for Monitoring
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'log-analytics-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Application Insights for Monitoring
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appInsights-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}
```

### Summary of the Bicep File:
1. **Parameters:** Defines various parameters for the deployment, including SQL server details, application names, Azure AD client IDs, and more.
2. **SQL Server and Database:** Creates a SQL Server and a sample SQL Database.
3. **App Service Plans:** Creates App Service Plans for both backend and frontend applications.
4. **App Services:** Creates App Services for backend and frontend applications with appropriate configurations and environment variables.
5. **Authentication Settings:** Configures Azure Active Directory authentication for both backend and frontend applications.
6. **Autoscale Settings:** Configures autoscale settings for both backend and frontend applications using the `CpuTime` metric.
7. **Key Vault:** Creates a Key Vault with access policies for different object IDs.
8. **Log Analytics and Application Insights:** Creates a Log Analytics workspace and Application Insights for monitoring.




## The Deploy.sh Script

```bash
#!/bin/bash

# Parameters
sqlDatabaseName=$SQL_DATABASE_NAME
sqlAdminUsername=$SQL_ADMIN_USERNAME
sqlAdminPassword=$SQL_ADMIN_PASSWORD
keyVaultAccessObjectId=$KEY_VAULT_ACCESS_OBJECT_ID
sqlServerName=$SQL_SERVER_NAME
azureAdTenantId=$AZURE_AD_TENANT_ID
backendAppClientId=$BACKEND_APP_CLIENT_ID
frontendAppClientId=$FRONTEND_APP_CLIENT_ID
spAppId=$SP_APP_ID
spPassword=$SP_PASSWORD
adminGroupId=$ADMIN_GROUP_ID
userGroupId=$USER_GROUP_ID

# Deploy the Bicep template
echo "Deploying infrastructure using Bicep..."
az deployment group create --resource-group dtaskrg --template-file /Users/raphaelgab-momoh/Desktop/assignment/spring-boot-react-example/Infrastructure/main.bicep --parameters acrName=acr0000 backendAppName=backend-app-665762 frontendAppName=frontend-app-665762 sqlDatabaseName=$sqlDatabaseName sqlAdminUsername=$sqlAdminUsername sqlAdminPassword=$sqlAdminPassword keyVaultAccessObjectId=$keyVaultAccessObjectId sqlServerName=$sqlServerName azureAdTenantId=$azureAdTenantId backendAppClientId=$backendAppClientId frontendAppClientId=$frontendAppClientId spAppId=$spAppId spPassword=$spPassword adminGroupId=$adminGroupId userGroupId=$userGroupId

# Sleep for 30 seconds to wait for ACR to be fully provisioned
echo "Waiting for ACR to be fully provisioned..."
sleep 30

# Build and push backend Docker image
echo "Building and pushing backend Docker image..."
for i in {1..5}; do
  docker build -t $ACR_NAME.azurecr.io/backend:latest ./backend && break || sleep 30
done
for i in {1..5}; do
  docker push $ACR_NAME.azurecr.io/backend:latest && break || sleep 30
done

# Build and push frontend Docker image
echo "Building and pushing frontend Docker image..."
for i in {1..5}; do
  docker build -t $ACR_NAME.azurecr.io/frontend:latest ./frontend && break || sleep 30
done
for i in {1..5}; do
  docker push $ACR_NAME.azurecr.io/frontend:latest && break || sleep 30
done

# Wait for resources to be fully provisioned
echo "Waiting for resources to be fully provisioned..."
sleep 40

# Retrieve URLs
BACKEND_URL=$(az webapp show --resource-group dtaskrg --name backend-app-665762 --query defaultHostName -o tsv)
FRONTEND_URL=$(az webapp show --resource-group dtaskrg --name frontend-app-665762 --query defaultHostName -o tsv)

echo "Backend URL: https://$BACKEND_URL"
echo "Frontend URL: https://$FRONTEND_URL"

# Additional deployment steps or configurations
# ...

echo "Deployment completed."
```
### Summary of the `deploy.sh` Script

The `deploy.sh` script automates the deployment of infrastructure and application components using Azure Bicep and Docker. Here is a summary of its key steps:

1. **Set Parameters:**
   - Retrieves and sets various parameters required for the deployment, such as SQL database name, admin username and password, Key Vault access object ID, SQL server name, Azure AD tenant ID, application client IDs, service principal ID and password, and group IDs.

2. **Deploy Infrastructure Using Bicep:**
   - Uses the Azure CLI to deploy the infrastructure defined in the Bicep file (`main.bicep`) to the specified resource group (`dtaskrg`).
   - Parameters for the Bicep deployment include ACR name, backend and frontend app names, SQL database details, Key Vault access object ID, Azure AD tenant ID, application client IDs, service principal credentials, and group IDs.

3. **Wait for ACR Provisioning:**
   - Sleeps for 30 seconds to allow the Azure Container Registry (ACR) to be fully provisioned.

4. **Build and Push Docker Images:**
   - Builds and pushes the backend Docker image to ACR, retrying up to 5 times with a 30-second sleep interval between attempts.
   - Builds and pushes the frontend Docker image to ACR, retrying up to 5 times with a 30-second sleep interval between attempts.

5. **Wait for Resources to be Fully Provisioned:**
   - Sleeps for 40 seconds to allow all resources to be fully provisioned.

6. **Retrieve and Display URLs:**
   - Uses the Azure CLI to retrieve the default hostnames for the backend and frontend applications.
   - Displays the URLs for the backend and frontend applications.

7. **Additional Deployment Steps:**
   - Placeholder for any additional deployment steps or configurations that may be required.

8. **Completion Message:**
   - Prints a message indicating that the deployment is completed.

For any questions or issues, please open an issue in the repository.

---

This `README.md` provides a clear and concise guide for setting up, deploying, and using the project.