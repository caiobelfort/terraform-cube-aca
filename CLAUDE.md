# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A reusable Terraform module that deploys a production-ready **Cube Core (Cube.js)** cluster on **Azure Container Apps (ACA)**. It is consumed via `source = "../.."` in the `examples/` directories, not deployed directly.

## Common commands

```bash
# From examples/development/ or examples/production/
terraform init
terraform validate
terraform fmt -recursive
terraform plan -var-file=.tfvars
terraform apply -var-file=.tfvars
terraform destroy -var-file=.tfvars
```

**Prerequisite**: Azure CLI must be installed and authenticated (`az login`) because `volumes.tf` uses a `local-exec` provisioner to upload Cube config files to Azure File Share on every apply.

## Module file layout

| File | Responsibility |
|------|---------------|
| `main.tf` | Resource group, Log Analytics, Container App Environment, user-assigned identity, ACR role assignment, and shared `locals` |
| `versions.tf` | Provider version constraints (azurerm ≥4.56, azapi ≥2.8, time ≥0.13, Terraform ≥1.14) |
| `variables.tf` | All input variables |
| `volumes.tf` | Storage account, two file shares (`cube-conf` ReadOnly, `cube-cache` ReadWrite), and the `local-exec` that syncs `cube_files_dir` into the conf share on every apply |
| `router.tf` | CubeStore router container app + `azapi_update_resource` to add extra ports |
| `workers.tf` | CubeStore worker container apps (count = `num_workers`) + `azapi_update_resource` per worker |
| `refresher.tf` | Cube refresh worker container app |
| `api.tf` | Cube API container app (the only externally reachable component, port 4000) |
| `outputs.tf` | (empty / placeholder) |

## Key architectural patterns

### `dev_mode` flag
Setting `dev_mode = true` skips creation of the router (`count = 0`), workers (`count = 0`), and refresher (`count = 0`), leaving only the single `cube_api` container. This enables the Cube Playground at a lower cost.

### Multi-port workaround via `azapi`
The `azurerm_container_app` resource only supports a single ingress port. The router needs ports 9999 (meta), 3030, 3031, 3036, and workers need port 3031 in addition to their primary port. `azapi_update_resource` patches the ACA resource via the ARM API (`Microsoft.App/containerApps@2025-01-01`) after Terraform creates it to add `additionalPortMappings`.

### Worker startup ordering
Workers depend on `time_sleep.wait_60_seconds`, which itself depends on the router and its `azapi_update_resource`. This 60-second delay ensures the router is fully operational before workers attempt to connect.

### `env_version` / forced restarts
`local.env_version` is set to `formatdate("YYYYMMDDhhmmss", timestamp())`, injected as the `VERSION` env var into every container. Because `timestamp()` changes on each plan/apply, this forces a new revision on every apply — effectively restarting all containers.

### Worker naming and ports
Workers are named `cubestoreworker1`, `cubestoreworker2`, … and listen on ports `10001`, `10002`, … The `CUBESTORE_WORKERS` env var is built as a comma-separated string of `name:port` pairs from `local.workers_str`.

### Identity for ACR pulls
A `UserAssigned` managed identity is created and granted `AcrPull` on the ACR. All container apps reference this identity for registry authentication.

## Provider requirements

- **azurerm** ≥ 4.56 — primary Azure resource management
- **azapi** ≥ 2.8 — used exclusively for the multi-port patch on router and workers
- **time** ≥ 0.13 — used for the 60-second `time_sleep` between router and worker creation
- **random** — used in examples only for generating a suffix in the module (via `random_string.suffix`)

## Examples

- `examples/development/` — `dev_mode = true`, minimal resources, enables Cube Playground
- `examples/production/` — `dev_mode = false`, 1 worker (`small`), API scaled 1–2 replicas

Both examples keep Cube model files under `./cube/` relative to the example directory and reference the module via `source = "../.."`.
