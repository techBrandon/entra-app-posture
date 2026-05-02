# entra-app-posture — project notes

## Project overview

PowerShell + Microsoft.Graph SDK toolkit that runs **read-only** posture checks against Microsoft Entra Enterprise Applications, app registrations, service principals, consent settings, and workload identities. Checks map to Microsoft's [Zero Trust — Protect engineering systems](https://learn.microsoft.com/en-us/entra/fundamentals/zero-trust-protect-engineering-systems) guidance. The tool **reports** findings; it does not remediate.

## Tech stack

- PowerShell 7+
- Microsoft.Graph SDK — each check declares the specific submodules it needs via `#Requires`; never the umbrella `Microsoft.Graph` package. Today's submodules: `Microsoft.Graph.Authentication`, `Microsoft.Graph.Identity.SignIns`, `Microsoft.Graph.Applications`.
- Pester 5+ for tests
- No PowerShell module manifest. The project is intentionally a flat collection of standalone scripts so administrators can read and run them without module/loader machinery.

## Registry conventions

The project uses a two-tier registry — controls aggregate, checks verify.

- **Control** (`MSR-NN`, two-digit zero-padded) — one per Microsoft recommendation we track. The aggregate finding.
- **Check** (`EAPC-NNN`, three-digit zero-padded) — one per discrete verifiable condition.

Both ID series are sequentially assigned and **never reused, never reassigned** once they ship in code.

A check may contribute to one or more controls. The mapping is recorded in the check's row in [`docs/controls.md`](docs/controls.md) — the `Controls` column lists each `MSR-NN` it contributes to, comma-separated.

**Aggregation:** each control declares its rule in the `Aggregation` column of [`docs/controls.md`](docs/controls.md). Supported forms:

- `AND` (default) — the control passes only when every non-NA contributing check passes. One Fail → Fail. All NA → NA.
- **Per-app boolean expression** (e.g., `per-app: (EAPC-030 AND EAPC-031) OR EAPC-032`) — the expression is evaluated independently for each examined object; the control passes only when every object satisfies the expression. Used when the control's failure condition depends on per-object combinations (e.g., MSR-09 requires either assignment-required OR scoped provisioning per app). An `NA` finding does not satisfy a leg; only an active `Pass` does.
- Additional patterns may be added as needed — document them in this section before using.

[`docs/controls.md`](docs/controls.md) is the canonical registry. Every control and every check shipped in code MUST have a matching row.

## External references

Primary sources for any check are always **Microsoft Learn** and the **Microsoft Graph API documentation**. Author every check fresh against MS-published guidance.

[Maester](https://maester.dev) ([source](https://github.com/maester365/maester)) is a high-quality community Entra-assessment toolkit. It may be consulted **only when absolutely necessary** — and never as a source of implementation logic.

- Acceptable uses: deciding *how* to query a particular object surface; validating the breadth of failure modes against community knowledge; informing entries in [`docs/definitions.md`](docs/definitions.md).
- Unacceptable uses: copying logic, check titles, or naming conventions; vendoring data files; treating Maester (rather than Microsoft) as the authoritative source.

If a check can be derived from MS docs alone, do not consult Maester at all.

## Repo layout

```
Run-EntraAppPosture.ps1     # orchestrator with $AllChecks manifest
Helpers.ps1                 # Connect-EapGraph, New-EapFinding,
                            # cached Graph getters
Checks/
  EAPC-NNN.ps1              # one runnable script per check
docs/
  controls.md               # canonical control/check registry
  definitions.md            # domain glossary
tests/
  Invoke.ps1                # macOS-aware Pester invoker
  Helpers.Tests.ps1
  Run-EntraAppPosture.Tests.ps1
  Checks/
    EAPC-NNN.Tests.ps1
```

No module manifest and no `.psm1` loader. The orchestrator and each check are runnable scripts. `Helpers.ps1` is the single shared file, dot-sourced by the orchestrator and by each check that touches Graph. It admits a function only when (a) two or more checks call it, or (b) it wraps an expensive Graph cmdlet that benefits from per-session caching.

## How checks are authored

Each `Checks/EAPC-NNN.ps1` follows this structure:

1. `#Requires` block — PowerShell version + the specific `Microsoft.Graph.*` submodules the check uses.
2. Comment-based help describing the check, its MSR mapping, and outputs.
3. `[CmdletBinding()] param()` and `$ErrorActionPreference = 'Stop'`. *Param block must come before any executable statement, including `. Helpers.ps1` — PowerShell parsing rule.*
4. Dot-source the helpers: `. "$PSScriptRoot/../Helpers.ps1"`.
5. Top-level `try`:
   - Query Graph through a `Get-Eap*` cached getter (which idempotently calls `Connect-EapGraph` for its scope before fetching).
   - Defensive type validation — bad data should produce `Status='Error'`, never a wrong `Pass`/`Fail`. PowerShell truthiness coerces `$null`/`0`/`'true'` into wrong answers without explicit `-isnot [bool]` checks.
   - Emit one finding per evaluated object via `New-EapFinding`.
6. Top-level `catch` — emit one `Status='Error'` finding via `New-EapFinding` for whole-check failures.
7. For iterating checks: wrap each iteration in its own `try`/`catch` so a single bad object yields a per-object `Error` finding without aborting the loop.

Adding a check requires: (a) registry row in [`docs/controls.md`](docs/controls.md), (b) `Checks/EAPC-NNN.ps1`, (c) row in `$AllChecks` at the top of `Run-EntraAppPosture.ps1`, (d) optionally a new `Get-Eap*` cached getter in `Helpers.ps1` if the check is the first consumer of a Graph cmdlet, (e) Pester tests under `tests/Checks/`.

## Caching

Cached Graph getters in `Helpers.ps1` use a process-scoped hashtable, `$global:EapCache`, keyed by a logical name (e.g., `'Applications'`). The cache:

- Lasts for the lifetime of the `pwsh` process.
- Is shared across child scopes — checks invoked by the orchestrator see the same cache.
- Uses `ContainsKey` for hit/miss, so an empty result (zero apps) is a valid cached value.
- Honours a `-Refresh` switch on each getter (used internally and by tests).

### Forcing a re-fetch — `-RefreshData`

`Run-EntraAppPosture.ps1` and each `Checks/EAPC-NNN.ps1` accept a `-RefreshData` switch. When set, the script clears `$global:EapCache` before any cached getter runs. Use it when iteratively testing tenant config changes from the same `pwsh` session — without the flag, the second run reuses the first run's cached response and reports a stale `Pass`/`Fail`.

```pwsh
pwsh ./Run-EntraAppPosture.ps1 -CheckId EAPC-001 -RefreshData
pwsh ./Checks/EAPC-001.ps1 -RefreshData
```

Equivalent escape hatches: `$global:EapCache = @{}` between runs, or restart `pwsh`.

### Tests

In tests, **always** reset the cache with `$global:EapCache = @{}` in `BeforeEach`. Mocked responses leak across tests otherwise.

## Output format

`[PSCustomObject]` on the pipeline. Schema:

```
CheckId    : 'EAPC-NNN'
ControlIds : @('MSR-NN', ...)
ObjectType : 'Tenant' | 'Application' | 'ServicePrincipal' | 'CheckExecution' | ...
ObjectId   : <canonical id>
ObjectName : <human-readable>
Status     : 'Pass' | 'Fail' | 'NA' | 'Error'
Evidence   : @{ ... }   # check-specific
Timestamp  : [datetime]::UtcNow
```

Findings are produced by `New-EapFinding` in `Helpers.ps1` — the single place the schema lives. Schema changes happen there, not in 35 different check files.

## Running tests

```sh
pwsh ./tests/Invoke.ps1
```

The invoker redirects Pester's TestDrive to a project-local, gitignored directory (`tests/.testdrive/`) so the suite runs without `/tmp` write access. On macOS it also overrides Pester's hardcoded `/private/tmp` path via module-scope injection. Both changes are scoped to the running process.

## Permissions / Microsoft Graph scopes

| Scope | Used by |
|---|---|
| `Policy.Read.All` | EAPC-001 |
| `Application.Read.All` | EAPC-014 |

The orchestrator aggregates the union of scopes across the selected checks and connects once. Each check can also be run standalone (`pwsh ./Checks/EAPC-NNN.ps1`) and will connect itself with just its own scope.

## Open implementation questions

Decisions deferred to code-authoring time. Listed here so future sessions don't re-litigate them.

### Behavior to settle when authoring checks

- **EAPC-021 HTTP response semantics**: follow redirects? timeout values? authenticated-only endpoints (legitimate 401) — pass, fail, or NA? endpoints unreachable from the runner — NA or fail?
- **Composite-check NA semantics (MSR-10)**: EAPC-033/034/035 treat app registration + service principal as one application. Decide: app reg with no SP → NA or pass-by-vacuity? SP with no local app reg (multitenant) → NA, or evaluate SP-side only?
- **Network-required vs offline-only checks**: EAPC-020/021 are the first to require network access; the rest are pure Graph queries. Module design should let users opt out of online checks without disabling the whole tool.

### Deliberate non-mappings (invisible by inspection of the registry)

- EAPC-009 / EAPC-010 are not cross-mapped to MSR-08 — EAPC-025 (broad workload-identity scope) covers their failure modes.
- EAPC-016 is not cross-mapped to MSR-06 — MS scopes MSR-06 to app registrations only.
- No check verifies that service principals lack redirect URIs entirely. MS guidance says they shouldn't, but multitenant SPs frequently do; MSR-05 audits safety of what's there rather than presence.

### Aggregation evolution

- MSR-10's aggregation may need to flip from `AND` to per-app `(no owners) OR (protected owners)` once EAPC-036 lands and "protected" is defined.

## Conventions defer to global standards

General PowerShell, git, and tooling standards live in the maintainer's `~/.claude/CLAUDE.md` and are not duplicated here. Add an entry below only when this project deviates from those defaults.

### Project-specific deviations

- **Testing approach**: prefer live tenant data over mocked fixtures when validating checks. Real-world Entra configurations expose edge cases (multitenant SPs, orphaned objects, partial role assignments, data-shape surprises) that theoretical reasoning misses. Pester unit tests still cover deterministic logic, but the bar for marking a check `Implemented` is "verified against a real tenant," not "passes contrived fixtures."
