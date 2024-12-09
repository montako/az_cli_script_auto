#!/bin/bash

# Log in to Azure
az login

# Enable querying across all subscriptions
az account list --output table

echo "Checking all subscriptions..."

# Loop through all subscriptions
for SUBSCRIPTION in $(az account list --query "[].id" -o tsv); do
  echo "Processing subscription: $SUBSCRIPTION"
  
  # Set the current subscription
  az account set --subscription $SUBSCRIPTION
  
  # Get all storage accounts in the subscription
  STORAGE_ACCOUNTS=$(az storage account list --query "[].{name:name,resourceGroup:resourceGroup}" -o tsv)

  # Loop through each storage account
  echo "Checking storage accounts in subscription: $SUBSCRIPTION"
  while IFS=$'\t' read -r STORAGE_ACCOUNT RESOURCE_GROUP; do
    echo "Checking storage account: $STORAGE_ACCOUNT in resource group: $RESOURCE_GROUP"
    
    # Get the status of infrastructure encryption
    INFRA_ENCRYPTION_STATUS=$(az storage account show \
      --name $STORAGE_ACCOUNT \
      --resource-group $RESOURCE_GROUP \
      --query "enableInfrastructureEncryption" -o tsv)
    
    echo "Storage Account: $STORAGE_ACCOUNT | Infrastructure Encryption Enabled: $INFRA_ENCRYPTION_STATUS"
  done <<< "$STORAGE_ACCOUNTS"
done

echo "Encryption status check completed."
