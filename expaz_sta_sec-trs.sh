#!/bin/bash

# Log in to Azure CLI
az login

# Fetch all subscriptions
echo "Fetching all subscriptions..."
subscriptions=$(az account list --query '[].id' -o tsv)

# Initialize output file
output_file="SecureTransferCheckResults.csv"
echo "SubscriptionName,StorageAccountName,ResourceGroupName,Location,SecureTransfer" > $output_file

# Loop through each subscription
for subscription in $subscriptions; do
    echo "Processing subscription: $subscription"
    
    # Set subscription context
    az account set --subscription "$subscription" &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Skipping inaccessible subscription: $subscription"
        continue
    fi

    # Get storage accounts for the current subscription
    storage_accounts=$(az storage account list --query '[].{name:name, resourceGroup:resourceGroup, location:location}' -o json)

    # Skip if no storage accounts exist
    if [[ -z "$storage_accounts" || "$storage_accounts" == "[]" ]]; then
        echo "No storage accounts found in subscription: $subscription"
        continue
    fi

    # Loop through each storage account
    echo "$storage_accounts" | jq -c '.[]' | while read storage_account; do
        storage_account_name=$(echo "$storage_account" | jq -r '.name')
        resource_group=$(echo "$storage_account" | jq -r '.resourceGroup')
        location=$(echo "$storage_account" | jq -r '.location')
        
        # Check if Secure Transfer is enabled
        secure_transfer=$(az storage account show --name "$storage_account_name" --resource-group "$resource_group" --query "enableHttpsTrafficOnly" -o tsv 2>/dev/null)

        # Handle secure transfer status
        if [[ "$secure_transfer" == "true" ]]; then
            secure_transfer_status="Enabled"
        elif [[ "$secure_transfer" == "false" ]]; then
            secure_transfer_status="Disabled"
        else
            secure_transfer_status="Unknown (Error)"
        fi

        # Append the result to the CSV file
        subscription_name=$(az account show --query 'name' -o tsv)
        echo "$subscription_name,$storage_account_name,$resource_group,$location,$secure_transfer_status" >> $output_file
    done
done

echo "Results exported to $output_file"
