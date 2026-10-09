#!/usr/bin/env bash
# One-time bootstrap of the identity and GitHub environment a deploy workflow needs.
# Generated from the sdlc-azure-deploy skill: fill bootstrap.env from the approved plan, then run
#   ./bootstrap.sh [--dry-run] identity|roles|github|all
# Every step is idempotent. `roles` is separate because it usually needs someone with rights the
# person running `identity` and `github` lacks; hand them the file and the output of --dry-run.
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; shift; fi
STEP=${1:-all}
ENV_FILE=${BOOTSTRAP_ENV:-"$(dirname "$0")/bootstrap.env"}
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${SUBSCRIPTION_ID:?}" "${LOCATION:?}" "${GITHUB_REPO:?}" "${GH_ENVIRONMENT:?}"
: "${BOOTSTRAP_RG:?}" "${IDENTITY_NAME:?}"

run() {
  echo "+ $*"
  if [ "$DRY_RUN" = 0 ]; then "$@"; fi
}

identity() {
  run az group create --subscription "$SUBSCRIPTION_ID" -n "$BOOTSTRAP_RG" -l "$LOCATION" --output none
  run az identity create --subscription "$SUBSCRIPTION_ID" -g "$BOOTSTRAP_RG" -n "$IDENTITY_NAME" --output none
  # Only runs of this GitHub environment in this repository can sign in as the identity.
  if ! az identity federated-credential show --subscription "$SUBSCRIPTION_ID" -g "$BOOTSTRAP_RG" \
      --identity-name "$IDENTITY_NAME" -n "github-$GH_ENVIRONMENT" > /dev/null 2>&1; then
    run az identity federated-credential create --subscription "$SUBSCRIPTION_ID" -g "$BOOTSTRAP_RG" \
      --identity-name "$IDENTITY_NAME" -n "github-$GH_ENVIRONMENT" \
      --issuer https://token.actions.githubusercontent.com \
      --subject "repo:$GITHUB_REPO:environment:$GH_ENVIRONMENT" --audiences api://AzureADTokenExchange
  fi
}

principal_id() {
  az identity show --subscription "$SUBSCRIPTION_ID" -g "$BOOTSTRAP_RG" -n "$IDENTITY_NAME" --query principalId -o tsv 2>/dev/null \
    || { [ "$DRY_RUN" = 1 ] && echo "<principal-id>"; }
}

roles() {
  # ROLE_ASSIGNMENTS holds one "role|scope|condition" per line; condition may be empty.
  local principal
  principal=$(principal_id)
  while IFS='|' read -r role scope condition; do
    [ -z "${role:-}" ] && continue
    if [ -n "${condition:-}" ]; then
      run az role assignment create --assignee-object-id "$principal" --assignee-principal-type ServicePrincipal \
        --role "$role" --scope "$scope" --condition-version 2.0 --condition "$condition" --output none
    else
      run az role assignment create --assignee-object-id "$principal" --assignee-principal-type ServicePrincipal \
        --role "$role" --scope "$scope" --output none
    fi
  done <<< "$ROLE_ASSIGNMENTS"
}

github() {
  local client_id tenant_id
  client_id=$(az identity show --subscription "$SUBSCRIPTION_ID" -g "$BOOTSTRAP_RG" -n "$IDENTITY_NAME" --query clientId -o tsv 2>/dev/null \
    || { [ "$DRY_RUN" = 1 ] && echo "<client-id>"; })
  tenant_id=$(az account show --subscription "$SUBSCRIPTION_ID" --query tenantId -o tsv 2>/dev/null \
    || { [ "$DRY_RUN" = 1 ] && echo "<tenant-id>"; })
  run gh api -X PUT "repos/$GITHUB_REPO/environments/$GH_ENVIRONMENT" --silent
  run gh variable set AZURE_CLIENT_ID --repo "$GITHUB_REPO" --env "$GH_ENVIRONMENT" --body "$client_id"
  run gh variable set AZURE_TENANT_ID --repo "$GITHUB_REPO" --env "$GH_ENVIRONMENT" --body "$tenant_id"
  run gh variable set AZURE_SUBSCRIPTION_ID --repo "$GITHUB_REPO" --env "$GH_ENVIRONMENT" --body "$SUBSCRIPTION_ID"
  if [ -n "${SRE_AGENT_ID:-}" ]; then
    run gh variable set SRE_AGENT_ID --repo "$GITHUB_REPO" --env "$GH_ENVIRONMENT" --body "$SRE_AGENT_ID"
  fi
  # Generated here and piped straight in, so the value is never printed or held by the agent.
  for name in ${GENERATED_SECRETS:-}; do
    if [ "$DRY_RUN" = 1 ]; then
      echo "+ openssl rand -base64 24 | gh secret set $name --repo $GITHUB_REPO --env $GH_ENVIRONMENT"
    elif ! gh secret list --repo "$GITHUB_REPO" --env "$GH_ENVIRONMENT" | grep -q "^$name\b"; then
      openssl rand -base64 24 | gh secret set "$name" --repo "$GITHUB_REPO" --env "$GH_ENVIRONMENT"
    fi
  done
}

case "$STEP" in
  identity) identity ;;
  roles) roles ;;
  github) github ;;
  all) identity; roles; github ;;
  *) echo "usage: $0 [--dry-run] identity|roles|github|all" >&2; exit 2 ;;
esac
