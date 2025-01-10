#!/bin/bash
# Enable debugging
set -x

# Variables
RESOURCE_GROUP="dtaskrg"
LOCATION="northeurope"
ACR_NAME="acr0000"
RANDOM_SUFFIX=$(openssl rand -hex 3)
BACKEND_APP_NAME="backend-app-${RANDOM_SUFFIX}"
FRONTEND_APP_NAME="frontend-app-${RANDOM_SUFFIX}"
SQL_DATABASE_NAME="dtaskdb"
SQL_SERVER_NAME="dtaskserver"
SQL_ADMIN_USERNAME="sqladmin"
SQL_ADMIN_PASSWORD=$(openssl rand -base64 16)
BACKEND_PLAN_NAME="${BACKEND_APP_NAME}-plan"
FRONTEND_PLAN_NAME="${FRONTEND_APP_NAME}-plan"
KEY_VAULT_NAME="${ACR_NAME}-kv"
KEY_VAULT_ACCESS_OBJECT_ID="58bf15bd-e182-4c81-a517-76a581ced7b4"
SP_NAME="myServicePrincipal"
FRONTEND_APP_REDIRECT_URI="http://localhost:3000"
USER_EMAIL="raphael@rdgmh.onmicrosoft.com"  # Ensure this is set
USER_DISPLAY_NAME="Raphael"
USER_PASSWORD=$(openssl rand -base64 16) # Generate a random password
ADMIN_GROUP_NAME="Admins"
USER_GROUP_NAME="Users"

# Path to the Terraform directory
TERRAFORM_DIR="/Users/raphaelgab-momoh/Desktop/success/spring-boot-react-example"

# Export database username and password as environment variables
export SQL_ADMIN_USERNAME="sqladmin"
export SQL_ADMIN_PASSWORD=$(openssl rand -base64 16)

# Print the exported variables for verification
echo "Exported SQL_ADMIN_USERNAME: $SQL_ADMIN_USERNAME"
echo "Exported SQL_ADMIN_PASSWORD: $SQL_ADMIN_PASSWORD"

# Validate USER_EMAIL
if [ -z "$USER_EMAIL" ]; then
  echo "ERROR: USER_EMAIL is not set. Please provide a valid email address for the user."
  exit 1
fi

# Validate USER_EMAIL format (basic check)
if ! [[ "$USER_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
  echo "ERROR: Invalid email format for USER_EMAIL. Please provide a valid email address."
  exit 1
fi

# Check if Azure CLI is logged in
if ! az account show > /dev/null 2>&1; then
  echo "ERROR: Please login to Azure CLI using 'az login' before running this script."
  exit 1
fi

# Fetch Azure AD Tenant ID
AZURE_AD_TENANT_ID=$(az account show --query tenantId --output tsv)
if [ -z "$AZURE_AD_TENANT_ID" ]; then
  echo "ERROR: Failed to fetch Azure AD Tenant ID."
  exit 1
fi

# Create Azure AD app registration for the backend
BACKEND_APP_CLIENT_ID=$(az ad app create --display-name "${BACKEND_APP_NAME}-app" --query appId --output tsv)
if [ -z "$BACKEND_APP_CLIENT_ID" ]; then
  echo "ERROR: Failed to create Azure AD app registration for the backend."
  exit 1
fi

# Create a service principal for the backend app
az ad sp create --id $BACKEND_APP_CLIENT_ID

# Create Azure AD app registration for the frontend
FRONTEND_APP_CLIENT_ID=$(az ad app create --display-name "${FRONTEND_APP_NAME}-app" --query appId --output tsv)
if [ -z "$FRONTEND_APP_CLIENT_ID" ]; then
  echo "ERROR: Failed to create Azure AD app registration for the frontend."
  exit 1
fi

# Create a service principal for the frontend app
az ad sp create --id $FRONTEND_APP_CLIENT_ID

# Create Azure AD groups if they don't exist
ADMIN_GROUP_ID=$(az ad group list --display-name $ADMIN_GROUP_NAME --query "[].id" --output tsv)
if [ -z "$ADMIN_GROUP_ID" ]; then
  echo "Creating group $ADMIN_GROUP_NAME..."
  ADMIN_GROUP_ID=$(az ad group create --display-name $ADMIN_GROUP_NAME --mail-nickname $ADMIN_GROUP_NAME --query id --output tsv)
else
  echo "Group $ADMIN_GROUP_NAME already exists."
fi

USER_GROUP_ID=$(az ad group list --display-name $USER_GROUP_NAME --query "[].id" --output tsv)
if [ -z "$USER_GROUP_ID" ]; then
  echo "Creating group $USER_GROUP_NAME..."
  USER_GROUP_ID=$(az ad group create --display-name $USER_GROUP_NAME --mail-nickname $USER_GROUP_NAME --query id --output tsv)
else
  echo "Group $USER_GROUP_NAME already exists."
fi

# Manually set the Object ID of the existing user
USER_OBJECT_ID="58bf15bd-e182-4c81-a517-76a581ced7b4"

if [ -z "$USER_OBJECT_ID" ]; then
  echo "ERROR: USER_OBJECT_ID is not set. Please provide the Object ID of the user."
  exit 1
fi

# Check if the user is already a member of the admin group
if ! az ad group member check --group $ADMIN_GROUP_ID --member-id $USER_OBJECT_ID --query "value" --output tsv; then
  echo "Adding user $USER_EMAIL to group $ADMIN_GROUP_NAME..."
  az ad group member add --group $ADMIN_GROUP_ID --member-id $USER_OBJECT_ID
else
  echo "User $USER_EMAIL is already a member of group $ADMIN_GROUP_NAME."
fi

# Check if the user is already a member of the user group
if ! az ad group member check --group $USER_GROUP_ID --member-id $USER_OBJECT_ID --query "value" --output tsv; then
  echo "Adding user $USER_EMAIL to group $USER_GROUP_NAME..."
  az ad group member add --group $USER_GROUP_ID --member-id $USER_OBJECT_ID
else
  echo "User $USER_EMAIL is already a member of group $USER_GROUP_NAME."
fi

# Check if resource group exists and delete if it does
if az group exists --name $RESOURCE_GROUP; then
  echo "Resource group $RESOURCE_GROUP already exists. Deleting..."
  az group delete --name $RESOURCE_GROUP --yes --no-wait
  echo "Waiting for resource group $RESOURCE_GROUP to be deleted..."
  az group wait --name $RESOURCE_GROUP --deleted
fi

# Create the resource group
echo "Creating resource group $RESOURCE_GROUP..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Purge the deleted Key Vault if it exists
deleted_vaults=$(az keyvault list-deleted --query "[?name=='${KEY_VAULT_NAME}'].name" -o tsv)
if [[ -n $deleted_vaults ]]; then
  echo "Purging deleted Key Vault $KEY_VAULT_NAME..."
  az keyvault purge --name $KEY_VAULT_NAME --location $LOCATION
fi

# Check if ACR exists and delete if it does
existing_acr=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "name" -o tsv 2>/dev/null || true)
if [[ -n $existing_acr ]]; then
  echo "ACR $ACR_NAME already exists. Deleting..."
  az acr delete --name $ACR_NAME --resource-group $RESOURCE_GROUP --yes
fi

# Check if service principal exists and delete if it does
existing_sp=$(az ad sp list --display-name $SP_NAME --query "[].appId" -o tsv)
if [[ -n $existing_sp ]]; then
  echo "Service principal $SP_NAME already exists. Deleting..."
  az ad sp delete --id $existing_sp
fi

# Create Azure Container Registry
echo "Creating Azure Container Registry $ACR_NAME..."
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Standard --admin-enabled true

# Verify ACR creation
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query id --output tsv)
if [ -z "$ACR_ID" ]; then
  echo "Failed to create ACR. Exiting."
  exit 1
fi

# Create a service principal and assign AcrPush role
SP_CREDENTIALS=$(az ad sp create-for-rbac --name $SP_NAME --scopes $ACR_ID --role AcrPush --query "{appId: appId, password: password, tenant: tenant}" --output json)
SP_APP_ID=$(echo $SP_CREDENTIALS | jq -r .appId)
SP_PASSWORD=$(echo $SP_CREDENTIALS | jq -r .password)
SP_TENANT=$(echo $SP_CREDENTIALS | jq -r .tenant)

echo "Service Principal ID: $SP_APP_ID"
echo "Service Principal Password: $SP_PASSWORD"
echo "Service Principal Tenant: $SP_TENANT"

# Assign AcrPull role to the service principal
az role assignment create --assignee $SP_APP_ID --role AcrPull --scope $ACR_ID

# Login to ACR
az acr login --name $ACR_NAME

# Increase Docker client timeout
export DOCKER_CLIENT_TIMEOUT=300
export COMPOSE_HTTP_TIMEOUT=300

# Verify Dockerfile exists in backend and frontend directories, create if not found
if [ ! -f ./backend/Dockerfile ]; then
  echo "Dockerfile not found in ./backend directory. Creating a default Dockerfile..."
  cat <<EOF > ./backend/Dockerfile
# Use an official OpenJDK runtime as a parent image
FROM openjdk:11-jre-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Make port 8080 available to the world outside this container
EXPOSE 8080

# Set environment variables
ENV SPRING_PROFILES_ACTIVE=dev

# Run the application
CMD ["java", "-jar", "backend.jar"]
EOF
fi

if [ ! -f ./frontend/Dockerfile ]; then
  echo "Dockerfile not found in ./frontend directory. Creating a default Dockerfile..."
  cat <<EOF > ./frontend/Dockerfile
# Use an official Node.js runtime as a parent image
FROM node:14

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages
RUN npm install

# Make port 80 available to the world outside this container
EXPOSE 80

# Set environment variables
ENV REACT_APP_API_URL=http://backend:8080

# Run the application
CMD ["npm", "start"]
EOF
fi

# Build and push backend Docker image
echo "Building and pushing backend Docker image..."
for i in {1..5}; do
  docker build -t $ACR_NAME.azurecr.io/backend:latest ./backend && break || sleep 15
done
for i in {1..5}; do
  docker push $ACR_NAME.azurecr.io/backend:latest && break || sleep 15
done

# Verify backend Docker image push completion
for i in {1..5}; do
  if az acr repository show --name $ACR_NAME --repository backend --query "tags[?contains(@, 'latest')]" | grep -q "latest"; then
    echo "Backend Docker image push completed."
    break
  else
    echo "Waiting for backend Docker image push to complete..."
    sleep 15
  fi
done

# Build and push frontend Docker image
echo "Building and pushing frontend Docker image..."
for i in {1..5}; do
  docker build -t $ACR_NAME.azurecr.io/frontend:latest ./frontend && break || sleep 15
done
for i in {1..5}; do
  docker push $ACR_NAME.azurecr.io/frontend:latest && break || sleep 15
done

# Verify frontend Docker image push completion
for i in {1..5}; do
  if az acr repository show --name $ACR_NAME --repository frontend --query "tags[?contains(@, 'latest')]" | grep -q "latest"; then
    echo "Frontend Docker image push completed."
    break
  else
    echo "Waiting for frontend Docker image push to complete..."
    sleep 15
  fi
done

# Navigate to the Terraform directory
cd $TERRAFORM_DIR

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate the Terraform configuration
echo "Validating Terraform configuration..."
terraform validate

# Deploy the infrastructure using Terraform
echo "Deploying infrastructure using Terraform..."
terraform apply -auto-approve \
  -var "location=$LOCATION" \
  -var "sql_server_name=$SQL_SERVER_NAME" \
  -var "sql_admin_username=$SQL_ADMIN_USERNAME" \
  -var "sql_admin_password=$SQL_ADMIN_PASSWORD" \
  -var "admin_group_ids=[\"$ADMIN_GROUP_ID\"]" \
  -var "user_group_ids=[\"$USER_GROUP_ID\"]" \
  -var "user_ids=[\"$USER_OBJECT_ID\"]" \
  -var "key_vault_name=$KEY_VAULT_NAME" \
  -var "backend_app_name=$BACKEND_APP_NAME" \
  -var "frontend_app_name=$FRONTEND_APP_NAME" \
  -var "backend_plan_name=$BACKEND_PLAN_NAME" \
  -var "frontend_plan_name=$FRONTEND_PLAN_NAME" \
  -var "acr_name=$ACR_NAME"

# Wait for resources to be fully provisioned
echo "Waiting for resources to be fully provisioned..."
sleep 300

# Output the URLs of the deployed applications
BACKEND_URL=$(terraform output -raw backend_app_url)
FRONTEND_URL=$(terraform output -raw frontend_app_url)

echo "Backend URL: https://$BACKEND_URL"
echo "Frontend URL: https://$FRONTEND_URL"

echo "Deployment completed successfully!"