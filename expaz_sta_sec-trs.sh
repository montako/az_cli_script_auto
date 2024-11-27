#!/bin/bash

# Log in to Azure CLI
az login

# Fetch only active subscriptions
echo "Fetching active subscriptions..."
subscriptions=$(az account list --query "[?state=='Enabled'].id" -o tsv)

# Initialize an output file
output_file="SecureTransferCheckResults.csv"
echo "SubscriptionName,StorageAccountName,ResourceGroupName,Location,SecureTransfer" > $output_file

# Loop through each active subscription
for subscription in $subscriptions; do
    echo "Checking subscription: $subscription"
    
    # Set the subscription context
    az account set --subscription $subscription

    # Verify the subscription is accessible
    if ! az account show --subscription "$subscription" &>/dev/null; then
        echo "Skipping inaccessible subscription: $subscription"
        continue
    fi

    # Get all storage accounts in the subscription
    storage_accounts=$(az storage account list --query '[].{name:name, resourceGroup:resourceGroup, location:location}' -o json)

    # Check if there are any storage accounts
    if [[ -z "$storage_accounts" || "$storage_accounts" == "[]" ]]; then
        echo "No storage accounts found in subscription: $subscription"
        continue
    fi

    # Loop through each storage account
    echo "$storage_accounts" | jq -c '.[]' | while read storage_account; do
        storage_account_name=$(echo $storage_account | jq -r '.name')
        resource_group=$(echo $storage_account | jq -r '.resourceGroup')
        location=$(echo $storage_account | jq -r '.location')
        
        # Check if Secure Transfer is enabled
        secure_transfer=$(az storage account show --name "$storage_account_name" --resource-group "$resource_group" --query "enableHttpsTrafficOnly" -o tsv 2>/dev/null)
        
        # Handle potential errors (e.g., permission issues or deleted storage accounts)
        if [[ -z "$secure_transfer" ]]; then
            secure_transfer_status="Unknown (Error)"
        elif [[ "$secure_transfer" == "true" ]]; then
            secure_transfer_status="Enabled"
        else
            secure_transfer_status="Disabled"
        fi

        # Append the results to the CSV file
        echo "$(az account show --query 'name' -o tsv),$storage_account_name,$resource_group,$location,$secure_transfer_status" >> $output_file
    done
done

echo "Results exported to $output_file"
