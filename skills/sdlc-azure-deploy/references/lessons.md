# Lessons from the first deployment

What went wrong or surprised, found deploying `digital-marketplace-next`. Each is a check or a
default in the templates. Add to this file when a new project teaches something; do not delete an
entry because a template now handles it.

1. **Validation does not predict policy.** Preflight validation passed, then the real deployment was
   denied by `Enforce-TLS-SSL-Q225` for an internal app with plain-HTTP ingress. Run a canary
   deployment early. `app.bicep` fixes `allowInsecure: false`.
2. **Co-locate a service that only one other calls.** The fix for 1 was one app with two containers
   and the proxy pointed at `localhost`. Decide this at planning.
3. **Build-time addresses force two passes.** The frontend bakes in the identity provider's address,
   which depends on the environment's domain. Detect `buildTime[].dependsOnInfra`. Where it is only
   a convenience, change the code to read it at run time and avoid the second pass.
4. **An identity provider behind ingress needs its public address told to it.** Set its hostname and
   its proxy-header handling, and render redirect URIs from the real origin. The issuer in tokens must
   equal the address the browser and the app use.
5. **GHCR visibility cannot be set through the API.** A package in a personal namespace starts
   private; making it public is a manual step. A package linked to a public repository's workflow may
   inherit its visibility; confirm on first run. Without it the apps cannot pull.
6. **Lowercase the registry path** and log in with a token that has `write:packages` when pushing from
   a machine.
7. **Tag images with the commit.** A fixed tag with an unchanged template creates no new revision, so
   an updated image is not pulled.
8. **PostgreSQL over TLS.** Put `sslmode=require` in the connection string; the Azure-services
   firewall rule let the Container Apps environment connect. Departs from R19 in a strict landing
   zone.
9. **Local volumes are not persistent.** An uploads directory on `EmptyDir` is lost on restart.
10. **`az containerapp exec` is interactive only.** Check through the public interface, the logs, or
    a one-shot job instead.
11. **`az monitor app-insights query` stops on an extension prompt.** Query the workspace tables.
12. **The SRE agent PATCH needs the identity in the body, is asynchronous, and was only run by a user
    with the agent's administrator role.** See `sre-agent.md`.
13. **The agent's own App Insights is not the application's.** Do not repoint it.
14. **Read config from the environment in `.bicepparam`** with `readEnvironmentVariable`, so the
    same file serves a laptop and the pipeline; secrets stay in the environment.
15. **A governance rule can name another deploy target.** Here, a rule sent lower environments to
    OpenShift unless a decision record documented an exception. The change is a proposal for the owner
    to approve; the agent drafts it and does not apply it.
16. **A user's Owner may come from a group at the management group.** `az role assignment list`
    needs `--include-groups` to show it. Preflight does.
