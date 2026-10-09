#!/usr/bin/env bash
# Checks that need no Azure access: templates compile, JSON parses, the golden inventory matches its
# schema, and every evidence line in it exists in a checkout of the example's source repository.
#   ./check.sh [path-to-digital-marketplace-next]
set -euo pipefail
cd "$(dirname "$0")"
BICEP=${BICEP:-$(command -v bicep || echo "$HOME/.azure/bin/bicep")}
T=skills/sdlc-azure-deploy/templates/bicep

"$BICEP" build "$T/main.bicep" --stdout > /dev/null && echo "ok  main.bicep compiles"
ENVIRONMENT_NAME=check "$BICEP" build-params "$T/main.bicepparam" --stdout > /dev/null && echo "ok  main.bicepparam compiles"
bash -n skills/sdlc-azure-deploy/scripts/preflight.sh && echo "ok  preflight.sh parses"
bash -n skills/sdlc-azure-deploy/templates/bootstrap/bootstrap.sh && echo "ok  bootstrap.sh parses"

python3 - "${1:-}" <<'EOF'
import json, sys, pathlib
base = pathlib.Path("skills/sdlc-azure-deploy/schemas")
for f in list(base.glob("*.json")) + list(pathlib.Path("examples").rglob("*.json")):
    json.load(open(f))
print("ok  JSON parses")
inv = json.load(open("examples/digital-marketplace-next/expected-inventory.json"))
try:
    import jsonschema
    jsonschema.validate(inv, json.load(open(base / "inventory.schema.json")))
    print("ok  golden inventory matches its schema")
except ImportError:
    print("skip schema validation (pip install jsonschema)")
src = sys.argv[1]
if src:
    root = pathlib.Path(src)
    missing = []
    def walk(node):
        if isinstance(node, dict):
            for k, v in node.items():
                if k == "evidence":
                    for e in v:
                        p = root / e["file"]
                        if not p.is_file() or len(p.read_text().splitlines()) < e["line"]:
                            missing.append(f'{e["file"]}:{e["line"]}')
                else:
                    walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)
    walk(inv)
    print("ok  every evidence line exists" if not missing else "FAIL evidence missing: " + ", ".join(missing))
    sys.exit(1 if missing else 0)
EOF
