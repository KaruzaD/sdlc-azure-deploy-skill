# Source of this example

Copied from `digital-marketplace-next` (the working tree on commit `ccd3080d17`, where `infra/azure/`
and `.github/workflows/deploy-azure.yml` were not yet committed), on 2026-10-09.

| Here | There |
| --- | --- |
| `main.bicep`, `main.bicepparam`, `modules/`, `README.md` | `infra/azure/` |
| `workflow/deploy-azure.yml` | `.github/workflows/deploy-azure.yml` |
| `app/idp.Dockerfile` | `app/compose/idp/Dockerfile` |
| `expected-inventory.json` | written by hand: what a scan of that repository must find |

It is the golden case. It deployed successfully to Azure Container Apps and was verified end to end,
except where `references/lessons.md` and `references/landing-zone-bcgov.md` say otherwise. Do not
edit it to match the templates; change the templates until a run on this repository reproduces it.
