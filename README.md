# Cube.js on Azure Container Apps Terraform Module

This Terraform module deploys a production-ready **Cube Core** (Cube.js) cluster on **Azure Container Apps** (ACA). It includes Cube Store for pre-aggregations, distributed caching, and automated deployment of your Cube configuration files.

## Features

- **Distributed Cube Store**: Deploys Cube Store with a router and multiple workers for high-performance pre-aggregations.
- **Auto-scaling API**: Cube API deployed on Azure Container Apps with configurable scaling.
- **Dedicated Refresh Worker**: Separate container instance for processing background pre-aggregation refreshes without impacting API performance.
- **Azure Integration**:
  - Uses **Azure Container Apps** for serverless container execution.
  - **Azure Storage Account (File Shares)** for persistent configuration and Cube Store cache.
  - **Azure User-Assigned Identity** for secure ACR image pulling.
  - **Log Analytics** for centralized observability.
- **Development Mode**: Toggle `dev_mode` to enable Cube Playground and simplify architecture for lower costs.

## Architecture

The module sets up the following components:

1.  **Cube API**: Handles incoming requests and serves data.
2.  **Cube Refresh Worker**: Processes pre-aggregation refreshes.
3.  **Cube Store Router**: Manages metadata and routes queries to workers.
4.  **Cube Store Workers**: Distributed storage for pre-aggregations.
5.  **Azure File Shares**:
    - `cube-conf`: Stores your Cube model and configuration files (automatically uploaded by the module).
    - `cube-cache`: Persistent storage for Cube Store data.

## Usage

```hcl
module "cube" {
  source = "github.com/your-org/cube-terraform" # Replace with actual source

  subscription_id         = "your-subscription-id"
  location                = "eastus2"
  env_prefix              = "cube-prod"
  
  acr_name                = "your-acr-name"
  acr_resource_group_name = "acr-rg"
  
  cube_image              = "cubejs/cube:v0.35"
  cubestore_image         = "cubejs/cubestore:v0.35"
  
  cube_files_dir          = "./cube-config" # Local directory with your Cube models
  
  allowed_ips = [
    { name = "office", value = "203.0.113.0/24" }
  ]
  
  cube_environment_variables = [
    { name = "CUBEJS_DB_TYPE", value = "postgres" },
    { name = "CUBEJS_DB_HOST", value = "your-db-host" },
    { name = "CUBEJS_DB_NAME", value = "your-db-name" },
    { name = "CUBEJS_DB_USER", value = "your-db-user" },
    { name = "CUBEJS_DB_PASS", value = "your-db-password" },
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `subscription_id` | The Azure Subscription ID | `string` | n/a | yes |
| `location` | Azure region to deploy resources | `string` | n/a | yes |
| `acr_name` | The Azure Container Registry name to pull images from | `string` | n/a | yes |
| `acr_resource_group_name` | Resource group name of the ACR | `string` | n/a | yes |
| `cube_image` | Full name of the Cube image in ACR (e.g., `mycube:latest`) | `string` | n/a | yes |
| `cubestore_image` | Full name of the Cube Store image in ACR | `string` | n/a | yes |
| `cube_files_dir` | Path to local directory containing Cube configuration files | `string` | n/a | yes |
| `allowed_ips` | List of IP ranges allowed to access the Cube API | `list(object)` | n/a | yes |
| `env_prefix` | Prefix for naming resources | `string` | `"cube"` | no |
| `num_workers` | Number of Cube Store workers | `number` | `2` | no |
| `worker_size` | Size of Cube Store workers (`small`, `medium`, `large`) | `string` | `"medium"` | no |
| `cube_api_scale` | Min/Max replicas for Cube API | `object` | `{min_size = 0, max_size = 2}` | no |
| `cube_environment_variables` | Additional environment variables for Cube containers | `list(object)` | `[]` | no |
| `dev_mode` | Enables Cube Playground and disables multi-node Cube Store for dev | `bool` | `false` | no |

## Important Notes

- **Initial Deployment**: The module uses `local-exec` to upload Cube files to Azure File Share. Ensure you have the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and authenticated.
- **Port Mappings**: The Cube Store Router uses a custom `azapi_update_resource` to handle multi-port mappings (3030, 3036, 9999) required for Cube Store operation.

## License


