# Bootstrap

The one-time setup the pipeline cannot do for itself: an identity it signs in as, the roles that
identity needs, and the GitHub environment that holds its settings. `templates/bootstrap/bootstrap.sh`
does it from `bootstrap.env`; this file is what to ask, check and explain.

## Why a user-assigned managed identity

It is the preferred way for a pipeline to authenticate (managed identity, then federated
credential): an Entra service principal that Azure creates and manages, with no secret. A federated
credential on it lets only runs of one GitHub environment in one repository exchange their OIDC
token for an Azure token. It needs no Entra directory permission and no app registration. Explain
this to the user in these words or shorter; they may be unsure what a managed identity is. It is
not their Azure login.

An app registration is needed only for directory operations through Microsoft Graph, for signing
users in with Entra, for an API that defines its own scopes, or for a caller that cannot federate.
In the BC Gov tenant it is a My Service Centre request, never self-service.

## Interview

Ask one topic at a time and explain the consequence. Record answers in the state file.

1. Subscription. Show the ones preflight found; do not assume.
2. Location: `canadacentral` (default; networking exists only there) or `canadaeast`.
3. Environment name (12 characters or fewer; it prefixes every resource name).
4. Bootstrap resource group and identity names. The group is separate from the environment's so
   tearing the environment down keeps the identity.
5. GitHub repository, environment name (`dev`), and whether to require reviewers for it.
6. Image registry: public GHCR (no pull credential; the package must be public), private GHCR or
   ACR (needs a pull credential or identity; not built yet).
7. SRE agent: none, attach to an existing one (name and group), or create (needs spike S1). Run mode.
8. Trigger: manual now; later after the build workflow, on a push, or on a tag.
9. Who has the rights for the `roles` step: the user, or someone else.

## Roles the identity needs

Derive them from the plan, not from a fixed list. For the golden example: deploy rights to create
the resource group and resources, the right to create the agent's three read-only role assignments
(restricted by condition to those three role IDs, so a compromised pipeline cannot grant itself
more), and, when attaching, read access to the agent and write access to it.

`landing-zone-bcgov.md` says direct Owner or Contributor assignment is denied and that the
golden example's subscription-wide Contributor is untested against that. Resolve it with the user
before running `roles`: a pre-created resource group with non-privileged roles at its scope, a custom
role, or a request to the platform team.

Three role definition IDs for the agent: Reader `acdd72a7-3385-48ef-bd42-f606fba81ae7`, Monitoring
Reader `43d0d8ad-25c7-4714-9337-8ba259a9fe05`, Log Analytics Reader
`73c42c96-874c-492b-b04d-ab87d138a893`. The condition text that limits a User Access Administrator
assignment to them is in `examples/digital-marketplace-next/README.md`.

## Running it

1. Fill `bootstrap.env` from the state file. No secret goes in it.
2. `./bootstrap.sh --dry-run all`. Show the output to the user.
3. If the user has all the rights: run `all` once they say so.
4. If not: run `identity`, then hand `roles` to the person with the rights, with `bootstrap.env`,
   the dry-run output and a plain statement of what each role is for. Wait. Resume with `github`.
5. Generated secrets are piped straight into GitHub and never shown. If a person needs a value (a
   shared password for synthetic test users), ask whether to write it to a local file with mode 600
   outside the repository; never print it.
6. Verify by listing what exists (`az identity federated-credential list`, `az role assignment
   list --assignee`, `gh variable list --env`, `gh secret list --env`) and record the IDs.

## If the OIDC login later fails

`AADSTS70021: No matching federated identity record` means the subject claim differs from the
credential's. Print the live subject from inside a run and fix the credential to match. Never add a
client secret to get past it.
