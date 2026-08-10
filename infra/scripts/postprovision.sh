#!/bin/bash
set -e

echo "Running post-provision script..."

# Get the outputs from the deployment
output=$(azd env get-values)

# Parse outputs
while IFS= read -r line; do
    if [[ $line == SERVICE_BUS_CONNECTION__fullyQualifiedNamespace* ]]; then
        ServiceBusNamespace=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
    elif [[ $line == SERVICE_BUS_QUEUE_NAME* ]]; then
        ServiceBusQueueName=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
    fi
done <<< "$output"

echo "Creating/updating src/local.settings.json..."

cat > ./src/local.settings.json << EOF
{
    "IsEncrypted": false,
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
        "ServiceBusConnection__fullyQualifiedNamespace": "$ServiceBusNamespace",
        "ServiceBusQueueName": "$ServiceBusQueueName"
    }
}
EOF

echo "src/local.settings.json has been created/updated successfully!"
echo ""
echo "Service Bus Namespace: $ServiceBusNamespace"
echo "Service Bus Queue: $ServiceBusQueueName"
echo ""
echo "You can now run the function locally with 'cd src && func start'"
