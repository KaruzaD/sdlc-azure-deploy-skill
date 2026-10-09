# Scan checklist

Goal: fill `inventory.json` completely, each finding with evidence (file and line), and list what you
could not determine under `unknowns`. Read; do not change anything. Do not infer what you can read.

## Find

- **Services.** Every Dockerfile and compose service. For each: what it is (frontend, backend,
  worker, identity provider, migration job, mail catcher), its build context and Dockerfile, the
  ports it listens on (`EXPOSE`, the code that calls `listen`), its health or status route, whether
  an outside client must reach it, and which other services it calls and how. A web server that
  reverse-proxies to a backend is a dependency to record: it decides whether they share an app.
- **Datastores.** Which databases, caches and blob stores; the driver and its connection setting;
  where migrations and seed data live and how they run. Whether the database is reached with a
  password.
- **Run-time config.** Every environment variable the code reads (search `process.env`, `os.environ`,
  `Environment.GetEnvironmentVariable`, config files). Mark which are secrets and which come from a
  resource the deployment creates.
- **Build-time config.** Values baked into an image when it is built (`ARG`, `VITE_*`, `NEXT_PUBLIC_*`,
  `REACT_APP_*`). Mark those whose value is an address that only exists after deployment: they force a
  build after the infrastructure exists.
- **Persistence.** Paths a service writes that must survive a restart (uploads, caches, local state).
- **Auth.** How users sign in; whether the environment needs its own identity provider, and what
  address it must be reachable at, and which redirect URIs it must allow.
- **Mail.** Whether it sends mail and through what; whether a mail catcher is needed.
- **Telemetry.** Any SDK already present; the log format and destination. JSON on stdout is enough
  for the logs to reach Log Analytics; request and exception telemetry needs an SDK.
- **Existing CI.** Workflows that build or test, the registry they use, any deploy target they name.
- **Governance.** A constitution, decision records, CODEOWNERS, contributing rules. In particular a
  rule that names a different deploy target, and any data-classification statement. Do not edit any of
  these; report them.
- **Tests.** How to build and test, so the plan's code changes can be checked.

## Rules for the scan

- Cite the line, not the file. If a finding rests on several lines, cite the one that decides it.
- A finding with no evidence is an unknown, not a finding.
- If two places disagree (a Dockerfile port and a compose port), report both and add an unknown.
- Do not run the application or contact any service. Do not read `.env` files, key files or anything
  that looks like a credential, and do not copy values from them. Record only the variable name.
