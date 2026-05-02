# entra-app-posture

Read-only posture checks for Microsoft Entra Enterprise Applications and related identity objects, mapped to Microsoft's [Zero Trust — Protect engineering systems](https://learn.microsoft.com/en-us/entra/fundamentals/zero-trust-protect-engineering-systems) guidance.

## Status

Early development. Check IDs and behavior may change without notice until a 1.0 release.

## What it checks

See [`docs/controls.md`](docs/controls.md) for the canonical list of checks, their `EAPC-NNN` identifiers, and current implementation status.

## Requirements

- PowerShell 7.0 or later (`pwsh`)
- The specific `Microsoft.Graph.*` submodules each check declares via `#Requires`. Today: `Microsoft.Graph.Authentication`, `Microsoft.Graph.Identity.SignIns`, `Microsoft.Graph.Applications`. Install via `Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Applications -Scope CurrentUser`.

## Repository layout

```
Run-EntraAppPosture.ps1     # the orchestrator
Helpers.ps1                 # Connect-EapGraph, New-EapFinding,
                            # cached Graph getters
Checks/
  EAPC-001.ps1              # one runnable script per check
  EAPC-014.ps1
docs/                       # control/check registry, definitions
tests/                      # Pester unit tests
```

There is no module manifest and no PowerShell module to install. The orchestrator and each check are runnable scripts. `Helpers.ps1` is dot-sourced by the orchestrator and by every check that touches Graph — it provides:

- `Connect-EapGraph` — idempotent `Connect-MgGraph` wrapper.
- `New-EapFinding` — the single factory for the finding schema.
- `Get-EapAuthorizationPolicy`, `Get-EapApplication` — per-session cached Graph getters. The first call fetches; subsequent calls in the same session return the cached value. Force a refresh with `-Refresh`, or restart `pwsh`.

Per-session caching matters at scale: many checks (EAPC-011 through EAPC-021) will iterate the same `Get-MgApplication -All` result. The cache means it's fetched once per orchestrator run, no matter how many checks consume it.

## Usage

Run all checks:

```pwsh
pwsh ./Run-EntraAppPosture.ps1
```

Filter by check or by control:

```pwsh
pwsh ./Run-EntraAppPosture.ps1 -CheckId EAPC-014
pwsh ./Run-EntraAppPosture.ps1 -ControlId MSR-04
pwsh ./Run-EntraAppPosture.ps1 -ExcludeCheckId EAPC-001
```

Run a single check directly (without the orchestrator):

```pwsh
pwsh ./Checks/EAPC-001.ps1
```

Force a fresh Graph fetch (clears the per-session cache) — useful when toggling a tenant setting and re-running in the same `pwsh` session:

```pwsh
pwsh ./Run-EntraAppPosture.ps1 -RefreshData
pwsh ./Checks/EAPC-001.ps1 -RefreshData
```

The first run prompts for an interactive Microsoft Graph sign-in. Subsequent runs in the same session reuse the existing context.

## Output

Every check emits one or more `[PSCustomObject]` findings on the pipeline:

```pwsh
CheckId    : EAPC-001
ControlIds : {MSR-01}
ObjectType : Tenant
ObjectId   : <tenant guid>
ObjectName : <tenant guid>
Status     : Pass | Fail | NA | Error
Evidence   : {...}
Timestamp  : 2026-05-01T...
```

Pipe to `ConvertTo-Json` for structured output, or `Format-Table` for a quick read.

## Required Microsoft Graph permissions

The orchestrator aggregates the union of `Scopes` across the selected checks and signs in once. Today's least-privilege scope set:

| Scope | Used by |
|---|---|
| `Policy.Read.All` | EAPC-001 |
| `Application.Read.All` | EAPC-014 |

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Security

See [`SECURITY.md`](SECURITY.md) for vulnerability reporting.

## License

[MIT](LICENSE) — Copyright (c) 2026 Brandon Colley.
