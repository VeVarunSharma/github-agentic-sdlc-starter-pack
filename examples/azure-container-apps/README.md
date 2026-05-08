# Example: Azure Container Apps

> A focused **delta** from the root baseline. This variant swaps the
> baseline's **Azure App Service for Containers** target for
> **[Azure Container Apps][aca-docs]** — the Microsoft-managed,
> Kubernetes-based serverless container platform.

## When to use this variant

- You want **scale-to-zero** for non-production environments (App
  Service Plans always keep at least one warm worker).
- You want **revisions + traffic splitting** for blue/green rollout
  without a separate load balancer.
- You're running **multiple microservices** in one environment that
  need cheap east-west networking via the Container Apps environment.
- You want to use **Dapr**, **KEDA scalers**, or other Container-Apps-
  native primitives.

Stay on the App Service baseline if: your app is a single long-lived
Node service, you don't need scale-to-zero, and you want the simplest
possible compute model.

## What changes vs. the baseline

| Concern              | Baseline (App Service)                          | This variant (Container Apps)                                |
| -------------------- | ----------------------------------------------- | ------------------------------------------------------------ |
| Compute              | `azurerm_linux_web_app` on `azurerm_service_plan` | `azurerm_container_app` in `azurerm_container_app_environment` |
| Image pull           | `container_registry_use_managed_identity` on Web App MI | `registry { identity = "system" }` on Container App MI |
| Roll forward         | `az webapp config container set --container-image-name` | `az containerapp update --image`                       |
| Logs                 | `azurerm_monitor_diagnostic_setting` → LAW      | Built into the Container App environment                     |
| Scale                | App Service Plan SKU + `Always On`              | `min_replicas`/`max_replicas` (zero-able), HTTP/KEDA scale rules |
| Traffic split        | Slot swap                                       | Multiple revisions with `traffic_weight`                     |
| Health probe         | `health_check_path`                             | `template.container.liveness_probe`                          |

The **OIDC bootstrap, ACR, Log Analytics, App Insights, GHAS, rulesets,
APM layer, and the `app/` Node sample** are all unchanged. You're
swapping the compute resource and the deploy step — nothing else.

## How to apply this variant

1. **Replace the baseline `infra/app/` directory** with the contents
   of [`infra/app/`](./infra/app/) here:

   ```bash
   rm -rf infra/app
   cp -r examples/azure-container-apps/infra/app infra/app
   ```

   (Or, in a fresh template-clone, just copy this directory before
   you ever run `infra/app` for the first time.)

2. **Replace the baseline `azure-deploy.yml`** with the variant
   workflow:

   ```bash
   cp examples/azure-container-apps/.github/workflows/azure-deploy.yml \
      .github/workflows/azure-deploy.yml
   ```

3. **Re-run `infra-apply.yml`** — it will tear down the App Service
   Plan + Web App and create the Container Apps environment + app.
   (For an already-deployed App Service stack, do this in a
   maintenance window — Terraform will destroy and re-create.)

4. **Update the `AZURE_WEBAPP_NAME` repo variable** to your new
   Container App name, or rename it to `AZURE_CONTAINERAPP_NAME`
   and update the workflow accordingly. The variant workflow uses
   `AZURE_CONTAINERAPP_NAME`.

That's it. The rest of the SDLC loop (spec issue → Copilot agent →
gates → human review → squash-merge → OIDC deploy) is identical.

## Cost notes

- **Consumption plan** is the default and lets the app scale to zero.
  You pay per vCPU-second + per request. For a low-traffic dev
  environment this is typically cents per day.
- **Dedicated workload profiles** (Premium) trade scale-to-zero for
  predictable performance. Switch by setting
  `workload_profile_type = "D4"` (or similar) on the environment.
- ACR, Log Analytics, and App Insights costs are unchanged from the
  baseline.

## What to read next

- [Azure Container Apps overview][aca-docs]
- [Container Apps revisions and traffic splitting][aca-revisions]
- [`docs/architecture.md`](../../docs/architecture.md) — the baseline
  architecture this variant deltas from
- [`docs/azure-oidc-setup.md`](../../docs/azure-oidc-setup.md) — OIDC
  bootstrap (unchanged)

[aca-docs]: https://learn.microsoft.com/azure/container-apps/overview
[aca-revisions]: https://learn.microsoft.com/azure/container-apps/revisions
