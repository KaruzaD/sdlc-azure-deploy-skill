#!/usr/bin/env bash
# Read-only checks before any planning or bootstrapping. Prints OK, WARN or FAIL per line and exits
# non-zero on FAIL. It changes nothing in Azure or GitHub.
#   preflight.sh [--tier sandbox|production] [--subscription ID] [--location canadacentral] [--repo owner/name]
set -uo pipefail

SUB=""
LOCATION=canadacentral
REPO=""
TIER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER=$2; shift 2 ;;
    --subscription) SUB=$2; shift 2 ;;
    --location) LOCATION=$2; shift 2 ;;
    --repo) REPO=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

FAILED=0
ok() { echo "OK    $1: $2"; }
warn() { echo "WARN  $1: $2"; }
fail() { echo "FAIL  $1: $2"; FAILED=1; }

for tool in az gh git jq docker openssl; do
  if command -v "$tool" > /dev/null; then ok "tool $tool" "found"; else fail "tool $tool" "not installed"; fi
done

if ! az account show > /dev/null 2>&1; then
  fail "az login" "not signed in; run az login"
  exit 1
fi
[ -z "$SUB" ] && SUB=$(az account show --query id -o tsv)
az account set --subscription "$SUB" > /dev/null 2>&1 || { fail "subscription" "cannot select $SUB"; exit 1; }
ok "subscription" "$(az account show --query '{n:name,id:id,tenant:tenantId}' -o tsv | tr '\t' ' ')"

# BC Gov subscriptions are named <licence plate>-<env>; a heuristic, not proof.
sub_name=$(az account show --query name -o tsv)
case "$TIER" in
  sandbox)
    if echo "$sub_name" | grep -qi -E -- '-prod([^a-z]|$)'; then
      fail "tier" "sandbox tier against a subscription named like production ($sub_name); do not continue"
    else
      ok "tier" "sandbox"
    fi ;;
  production)
    if echo "$sub_name" | grep -qi -E -- '-prod([^a-z]|$)'; then
      ok "tier" "production"
    else
      warn "tier" "production tier but the subscription is not named like production ($sub_name); confirm with the user"
    fi ;;
  "") warn "tier" "not given; ask the tier question first (references/tiers.md) and pass --tier" ;;
  *) fail "tier" "unknown tier '$TIER'; use sandbox or production" ;;
esac

case "$LOCATION" in
  canadacentral|canadaeast) ok "location" "$LOCATION" ;;
  *) fail "location" "$LOCATION is outside Canada Central and Canada East (BC Gov landing zone)" ;;
esac

user=$(az account show --query user.name -o tsv)
roles=$(az role assignment list --all --assignee "$user" --include-groups --include-inherited \
  --query "[].join(' @ ', [roleDefinitionName, scope])" -o tsv 2>/dev/null | sed -e "s#/subscriptions/$SUB#sub#" -e 's#/providers/Microsoft.Management/managementGroups/#mg:#' | sort -u | head -15)
if [ -z "$roles" ]; then
  warn "your roles" "none readable for $user; role creation may need someone else"
else
  ok "your roles" "(including through groups)"
  echo "$roles" | sed 's/^/        /'
fi

for ns in Microsoft.App Microsoft.OperationalInsights Microsoft.Insights Microsoft.ManagedIdentity Microsoft.DBforPostgreSQL Microsoft.Authorization; do
  state=$(az provider show -n "$ns" --query registrationState -o tsv 2>/dev/null)
  if [ "$state" = Registered ]; then ok "provider $ns" "$state"; else warn "provider $ns" "${state:-unknown}; register it before deploying"; fi
done

# Effects are not visible from the assignment list, and management-group assignments usually are not
# readable at all, so this cannot prove a design is allowed: the canary deployment does that.
policies=$(az policy assignment list --scope "/subscriptions/$SUB" --disable-scope-strict-match \
  --query "[?enforcementMode=='Default'].displayName" -o tsv 2>/dev/null | grep -i -E 'https|tls|public|location|private|tag|insecure' | head -20)
if [ -n "$policies" ]; then
  warn "policies" "assignments worth reading before designing (effects not evaluated):"
  echo "$policies" | sed 's/^/        /'
else
  warn "policies" "none visible from here; management-group policy is usually hidden, so plan a canary deployment"
fi

agents=$(az resource list --resource-type Microsoft.App/agents --query "[].{n:name,rg:resourceGroup}" -o tsv 2>/dev/null | tr '\t' '/' | tr '\n' ' ')
ok "SRE agents here" "${agents:-none found}"

if gh auth status > /dev/null 2>&1; then
  scopes=$(gh auth status 2>&1 | grep -i 'token scopes' | head -1)
  ok "gh login" "signed in. $scopes"
  echo "$scopes" | grep -q 'write:packages' || warn "gh scopes" "write:packages missing; needed only to push images from this machine"
else
  fail "gh login" "not signed in; run gh auth login"
fi

if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
fi
if [ -n "$REPO" ]; then
  vis=$(gh repo view "$REPO" --json visibility -q .visibility 2>/dev/null || echo unknown)
  ok "repository" "$REPO ($vis)"
else
  warn "repository" "could not determine; pass --repo owner/name"
fi

exit "$FAILED"
