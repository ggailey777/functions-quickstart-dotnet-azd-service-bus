---
description: This end-to-end .NET C# sample demonstrates the secure triggering of a Flex Consumption plan app from a Service Bus instance secured in a virtual network.
page_type: sample
products:
- azure-functions
- azure
urlFragment: service-bus-trigger-virtual-network
languages:
- csharp
- bicep
- azdeveloper
---

# Azure Functions .NET C# Service Bus Trigger using Azure Developer CLI

This template repository contains a Service Bus trigger reference sample for functions written in .NET C# and deployed to Azure using the Azure Developer CLI (`azd`). The sample uses managed identity and a virtual network to make sure deployment is secure by default. This sample demonstrates these two key features of the Flex Consumption plan:

* **High scale**. A low concurrency of 1 is configured for the function app in the `host.json` file. Once messages are loaded into Service Bus and the app is started, you can see how it scales to one app instance per message simultaneously.
* **Virtual network integration**. The Service Bus that this Flex Consumption app reads events from is secured behind a private endpoint. The function app can read events from it because it is configured with VNet integration. All connections to Service Bus and to the storage account associated with the Flex Consumption app also use managed identity connections instead of connection strings.

![Diagram showing Service Bus with a private endpoint and an Azure Functions Flex Consumption app triggering from it via VNet integration](./img/SB-VNET.png)

This project is designed to run on your local computer. You can also use GitHub Codespaces if available.

This sample processes queue-based events, demonstrating a common Azure Functions scenario where batch processing jobs are queued up with instructions for processing. The function app processes each message with a simulated delay to showcase the scaling capabilities.

> [!IMPORTANT]
> This sample creates several resources. Make sure to delete the resource group after testing to minimize charges!

## Prerequisites

+ [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
+ [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local?tabs=v4%2Clinux%2Ccsharp%2Cportal%2Cbash#install-the-azure-functions-core-tools)
+ To use Visual Studio Code to run and debug locally:
  + [Visual Studio Code](https://code.visualstudio.com/)
  + [Azure Functions extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)
  + [C# extension](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csharp)
+ [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (for deployment)
+ [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-windows)
+ An Azure subscription with Microsoft.Web and Microsoft.App [registered resource providers](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider)

## Initialize the local project

You can initialize a project from this `azd` template in one of these ways:

+ Use this `azd init` command from an empty local (root) folder:

    ```shell
    azd init --template functions-quickstart-dotnet-azd-service-bus
    ```

    Supply an environment name, such as `flexquickstart` when prompted. In `azd`, the environment is used to maintain a unique deployment context for your app.

+ Clone the GitHub template repository locally using the `git clone` command:

    ```shell
    git clone https://github.com/Azure-Samples/functions-quickstart-dotnet-azd-service-bus.git
    cd functions-quickstart-dotnet-azd-service-bus
    ```

    You can also clone the repository from your own fork in GitHub.

## Provision Azure resources

1. Run the following command to provision all required Azure resources:

    ```shell
    azd provision
    ```

    You're prompted to supply these required deployment parameters:

    | Parameter | Description |
    | ---- | ---- |
    | _Environment name_ | An environment that's used to maintain a unique deployment context for your app. You won't be prompted if you created the local project using `azd init`. |
    | _Azure subscription_ | Subscription in which your resources are created. |
    | _Azure location_ | Azure region in which to create the resource group that contains the new Azure resources. Only regions that currently support the Flex Consumption plan are shown. |
    | _VNET_ENABLED_ | Whether to deploy with VNet integration and private endpoints. Enter `false` unless you need private networking. |

    This creates all necessary Azure resources including:
    - Azure Service Bus namespace and queue
    - Azure Function App (Flex Consumption)
    - Application Insights for monitoring
    - Storage Account for function app
    - Virtual Network with private endpoints (if `VNET_ENABLED=true`)

    After provisioning completes, a post-provision script automatically generates `src/local.settings.json` with the correct Service Bus connection settings:

    ```json
    {
        "IsEncrypted": false,
        "Values": {
            "AzureWebJobsStorage": "UseDevelopmentStorage=true",
            "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
            "ServiceBusConnection__fullyQualifiedNamespace": "<your-namespace>.servicebus.windows.net",
            "ServiceBusQueueName": "<your-queue-name>"
        }
    }
    ```

2. Navigate to the `src` folder and restore the .NET packages:

    ```shell
    cd src
    dotnet restore
    ```

## Run your app locally

1. Start the Azurite storage emulator. You can do this using the [Azurite extension](https://marketplace.visualstudio.com/items?itemName=Azurite.azurite) in VS Code or by running `azurite` in a separate terminal.

2. From the `src` folder, run this command to start the Functions host locally:

    ```shell
    func start
    ```

3. The function will start and display the available functions. You should see output similar to:

    ```
    Functions:
        ServiceBusQueueTrigger: serviceBusQueueTrigger
    ```

    The function is now running locally and connected to the remote Service Bus resource you provisioned. You can send test messages using the Service Bus Explorer in the Azure Portal.

4. When you're done, press Ctrl+C in the terminal window to stop the `func` host process.

## Run your app using Visual Studio Code

1. Open the project root folder in Visual Studio Code.
2. Start the Azurite storage emulator.
3. Press **Run/Debug (F5)** to run in the debugger.
4. The Azure Functions extension will automatically detect your function and start the local runtime.
5. The function connects to the remote Service Bus resource provisioned in Azure.

## Source Code

The Service Bus trigger function is defined in [`src/ServiceBusQueueTrigger.cs`](./src/ServiceBusQueueTrigger.cs). The function uses the `[ServiceBusTrigger]` attribute to define the trigger configuration.

This code shows the Service Bus queue trigger:

```csharp
using System;
using System.Threading.Tasks;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace ServiceBusProcessor
{
    public class ServiceBusQueueTrigger
    {
        private readonly ILogger<ServiceBusQueueTrigger> _logger;

        public ServiceBusQueueTrigger(ILogger<ServiceBusQueueTrigger> logger)
        {
            _logger = logger;
        }

        [Function("ServiceBusQueueTrigger")]
        public async Task Run([ServiceBusTrigger("%ServiceBusQueueName%", Connection = "ServiceBusConnection")] 
            string messageBody, FunctionContext context)
        {
            _logger.LogInformation("C# ServiceBus Queue trigger start processing a message: {messageBody}", messageBody);
            
            // Simulate processing time with a 30-second delay to demonstrate scaling behavior
            await Task.Delay(TimeSpan.FromSeconds(30));
            
            _logger.LogInformation("C# ServiceBus Queue trigger end processing a message");
        }
    }
}
```

Key aspects of this code:

+ The `[ServiceBusTrigger]` attribute configures the function to trigger when messages arrive in the specified Service Bus queue
+ The queue name is read from the `ServiceBusQueueName` environment variable using the `%ServiceBusQueueName%` syntax
+ The connection string is read from the `ServiceBusConnection` setting
+ The function includes a 30-second `await Task.Delay(TimeSpan.FromSeconds(30))` delay to simulate message processing time and demonstrate the scaling behavior
+ Each message body is logged for debugging purposes using structured logging

The function configuration in [`src/host.json`](./src/host.json) sets `maxConcurrentCalls` to 1 for the Service Bus extension:

```json
{
  "extensions": {
    "serviceBus": {
        "maxConcurrentCalls": 1
    }
  }
}
```

This configuration ensures that each function instance processes only one message at a time, which triggers the Flex Consumption plan to scale out to multiple instances when multiple messages are queued.

## Deploy to Azure

Run this command to deploy your function app code to Azure:

```shell
azd deploy
```

This builds the .NET project and deploys it to the function app provisioned earlier.

## Test the solution

1. With the function running (either locally via `func start` or deployed to Azure), send a test message to the Service Bus queue by running the generated script:

    ```shell
    ./send-message.sh
    ```

    On Windows (PowerShell):

    ```powershell
    ./send-message.ps1
    ```

    On Windows (cmd):

    ```cmd
    powershell -File send-message.ps1
    ```

    These scripts were generated by the post-provision step with your Service Bus namespace and queue name already filled in.

2. You should see output in the function's terminal similar to:

    ```output
    [2024-11-10T10:30:15.123Z] C# ServiceBus Queue trigger start processing a message: Hello from the CLI
    [2024-11-10T10:30:45.123Z] C# ServiceBus Queue trigger end processing a message
    ```

3. **Monitor scaling behavior** (after deploying to Azure):
   - Send multiple messages in quick succession
   - Open Application Insights live metrics and observe the number of instances ('servers online')
   - Notice your app scaling the number of instances to handle processing the messages
   - Given the purposeful 30-second delay in the app code, you should see messages being processed in 30-second intervals once the app's maximum instance count (default of 100) is reached

## Redeploy your code

You can run `azd deploy` as many times as you need to deploy code updates to your function app. If you need to update infrastructure, run `azd provision` again.

> [!NOTE]
> Deployed code files are always overwritten by the latest deployment package.

## Clean up resources

When you're done working with your function app and related resources, you can use this command to delete the function app and its related resources from Azure and avoid incurring any further costs:

```shell
azd down
```

## Resources

For more information on Azure Functions, Service Bus, and VNet integration, see the following resources:

* [Azure Functions documentation](https://docs.microsoft.com/azure/azure-functions/)
* [Azure Service Bus documentation](https://docs.microsoft.com/azure/service-bus/)
* [Azure Virtual Network documentation](https://docs.microsoft.com/azure/virtual-network/)
