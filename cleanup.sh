#!/bin/bash

# Variables
RESOURCE_GROUP="dtaskrg"

# Delete the resource group
echo "Deleting resource group $RESOURCE_GROUP..."
az group delete --name $RESOURCE_GROUP --yes --no-wait
echo "Resource group $RESOURCE_GROUP deletion initiated."

# Infrastructure/cleanup.sh  Run the cleanup script to delete the resource group and all resources within it. The script will not wait for the deletion to complete, so you can continue working while the resources are being deleted.
./cleanup.sh