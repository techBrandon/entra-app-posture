# `src/` architecture

This document explains how the code in `src/` is organized, why it's organized that way, what calls what, and how a single invocation of `Invoke-EntraAppPosture` flows through the module. It is the reference for defending design choices and the starting point for adding new checks.

For domain context (what a control vs check is, the registry conventions, project standards), see:

- [`docs/controls.md`](../docs/controls.md) — canonical control/check registry
- [`docs/definitions.md`](../docs/definitions.md) — domain glossary
- [`CLAUDE.md`](../CLAUDE.md) — project notes and open implementation questions

---

## Mental model

The module is three concentric layers:

```
                 ┌──────────────────────────────┐
                 │  Public/                     │   user-facing surface (one cmdlet)
                 │    Invoke-EntraAppPosture    │
                 └──────────────────────────────┘
                              │  drives
                              ▼
                 ┌──────────────────────────────┐
                 │  Checks/                     │   one .ps1 per EAPC-NNN
                 │    EAPC-001.ps1              │   each calls Register-EapCheck
                 │    EAPC-014.ps1              │   each emits findings via
                 │    ...                       │   New-EapFinding
                 └──────────────────────────────┘
                              │  uses
                              ▼
                 ┌──────────────────────────────┐
                 │  Private/                    │   internal helpers, never
                 │    _Registry.ps1             │   exported. Checks call into
                 │    New-EapFinding.ps1        │   these; the runner calls
                 │    Connect-EapGraph.ps1      │   into these.
                 └──────────────────────────────┘
```

Three rules keep this clean:

1. **`Public/` exports a stable surface.** Today: one cmdlet. New exports require a deliberate decision.
2. **`Checks/` files contain *only* check logic.** Authoring a check should not require touching anything else in `src/` (other than `RequiredModules` in the manifest, when a new Graph submodule is needed).
3. **`Private/` is the only place where infrastructure lives.** If a helper is reused across multiple checks, it lives here. If a helper is used by exactly one check, it stays inline in that check file.

---

## Directory layout

```
src/
├── EntraAppPosture.psd1       Module manifest. Pins Microsoft.Graph submodules.
├── EntraAppPosture.psm1       Module loader. Dot-sources files in a fixed order.
│
├── Public/
│   └── Invoke-EntraAppPosture.ps1   The runner. The only exported cmdlet.
│
├── Private/
│   ├── _Registry.ps1                Registry storage + Register-EapCheck +
│   │                                Get-EapCheckRegistry. Underscore prefix
│   │                                forces it to load first.
│   ├── New-EapFinding.ps1           Single factory for finding objects.
│   └── Connect-EapGraph.ps1         Idempotent wrapper over Connect-MgGraph.
│
└── Checks/
    ├── EAPC-001.ps1                 One file per check. Filename matches EAPC id.
    └── EAPC-014.ps1                 Each calls Register-EapCheck at load time.
```

`tests/` mirrors the source. Check tests live in `tests/Checks/`; runner tests live at the top level (`tests/Invoke-EntraAppPosture.Tests.ps1`).

---

## Module load order

`EntraAppPosture.psm1` controls load order. Order matters because checks call `Register-EapCheck` at load time, and that helper must exist before any check file is dot-sourced.

```
Import-Module EntraAppPosture
        │
        ▼
EntraAppPosture.psm1
        │
        ├─ 1.  Private/_*.ps1            ← _Registry.ps1: defines $script:EapCheckRegistry,
        │                                  Register-EapCheck, Get-EapCheckRegistry
        │
        ├─ 2.  Private/*.ps1 (non-_)     ← New-EapFinding, Connect-EapGraph
        │
        ├─ 3.  Public/*.ps1              ← Invoke-EntraAppPosture (function definition only;
        │                                  not yet executed)
        │
        ├─ 4.  Checks/*.ps1              ← each file calls Register-EapCheck @{...}
        │                                  populating $script:EapCheckRegistry
        │
        └─ 5.  Export-ModuleMember        ← only Invoke-EntraAppPosture is exported
```

The `_` prefix on `_Registry.ps1` is the load-order signal: the loader uses two passes over `Private/` so `_*.ps1` always precedes anything else. If a future helper has no dependents inside `Private/`, it goes in the second pass (no underscore). If it must precede a sibling, it gets an underscore.

After load, `$script:EapCheckRegistry` holds one entry per registered check, keyed by EAPC id, and `Invoke-EntraAppPosture` is the only exported function.

---

## Runtime flow: `Invoke-EntraAppPosture`

```
User calls:  Invoke-EntraAppPosture -ControlId MSR-04
        │
        ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ Invoke-EntraAppPosture.ps1                                               │
│                                                                          │
│ 1. Get-EapCheckRegistry             → $registry  (all registered checks) │
│                                                                          │
│ 2. Apply filters in order:                                               │
│      -CheckId         → keep matching ids                                │
│      -ControlId       → keep checks whose ControlIds intersect           │
│      -ExcludeCheckId  → drop matching ids                                │
│    Result: $selected                                                     │
│                                                                          │
│ 3. Aggregate scopes from $selected:                                      │
│      $scopes = $selected.RequiredScopes | Select-Object -Unique          │
│                                                                          │
│ 4. Connect-EapGraph -Scopes $scopes                                      │
│      → checks Get-MgContext; only reconnects if scopes are missing       │
│                                                                          │
│ 5. foreach $check in $selected:                                          │
│      try { & $check.ScriptBlock $check }                                 │
│      catch { New-EapFinding -Status 'Error' ... }                        │
│                                                                          │
│ 6. Findings flow out on the pipeline as PSCustomObjects                  │
└──────────────────────────────────────────────────────────────────────────┘
```

A few invariants worth knowing:

- **Filters compose.** Passing `-CheckId` and `-ControlId` together intersects them — both must hold.
- **Scopes are aggregated, not per-check.** One `Connect-MgGraph` call covers the union of all selected checks' scopes. This is correct for delegated auth (the user consents once for the broadest set) but will need rethinking when app-only auth lands.
- **One check's failure does not break the run.** The runner wraps each check in `try/catch` and emits a `Status='Error'` finding instead of letting the exception propagate.
- **No control-level aggregation.** The runner returns per-object findings only. MSR-NN pass/fail rollup is deferred until a `Get-EapControlSummary` cmdlet lands (slice 2+).

---

## File-by-file responsibilities

### `EntraAppPosture.psd1`

Module manifest. The two things to know:

- **`RequiredModules`** is narrowly pinned per check requirement. Adding a new check that needs a new Graph submodule means adding an entry here. Do not add the umbrella `Microsoft.Graph` package — pin only the submodules a check actually uses.
- **`FunctionsToExport = @('Invoke-EntraAppPosture')`** is the export gate. Even if a function is defined in `Public/`, it must be listed here to be visible to consumers.

### `EntraAppPosture.psm1`

Module loader. Reads four directories in fixed order and dot-sources every `.ps1` it finds. No business logic lives here — it should never need to change when adding a check, only when adding a new top-level directory.

### `Public/Invoke-EntraAppPosture.ps1`

The runner. Walks the registry, filters, aggregates scopes, connects to Graph, dispatches to each check's script block, and emits findings.

**Calls:** `Get-EapCheckRegistry`, `Connect-EapGraph`, `New-EapFinding` (only for `Status='Error'` fallback findings), each registered check's `ScriptBlock`.

**Called by:** the user.

### `Private/_Registry.ps1`

Defines:

- **`$script:EapCheckRegistry`** — `[ordered]@{}` keyed by EAPC id. Populated at module load by check files. Module-private; never exported.
- **`Register-EapCheck`** — validates a check's metadata (Id format, ControlId format, no duplicate Id, scopes present, script block present) and stores the entry. Called once per check at load time.
- **`Get-EapCheckRegistry`** — returns the registry's values for the runner. Used by `Invoke-EntraAppPosture` and by tests.

**Called by:** every `Checks/*.ps1` (for `Register-EapCheck`); the runner (for `Get-EapCheckRegistry`).

### `Private/New-EapFinding.ps1`

Single factory for the `[PSCustomObject]` finding shape. Validates `Status` is one of `Pass | Fail | NA | Error` and `CheckId` matches `EAPC-\d{3}`.

Centralizing here means the finding schema can evolve (adding a `RunId`, changing the timestamp format, normalizing `Evidence` keys) without touching every check.

**Called by:** every check's script block; the runner's catch block (for `Error` findings).

### `Private/Connect-EapGraph.ps1`

Idempotent wrapper over `Connect-MgGraph`. Calls `Get-MgContext` first; only reconnects if any required scope is missing. Avoids re-prompting on every invocation during iterative development.

**Called by:** the runner (once per call to `Invoke-EntraAppPosture`).

### `Checks/EAPC-NNN.ps1`

Each file is a single `Register-EapCheck` invocation supplying metadata + a script block. The script block is the check's body — it queries Graph, evaluates objects, and emits findings.

The metadata hashtable declares everything the runner needs to know about the check without executing it: `Id`, `ControlIds`, `Title`, `RequiredScopes`, optional `Online` flag.

**Calls (typically):** `Get-Mg*` cmdlets from one of the pinned submodules; `New-EapFinding` for every emission.

**Called by:** the runner, via `& $check.ScriptBlock $check`.

---

## Data shapes

### Registry entry

What `Register-EapCheck` stores under each EAPC id:

```powershell
[PSCustomObject]@{
    Id             = 'EAPC-014'                          # EAPC-NNN
    ControlIds     = @('MSR-04')                         # one or more MSR-NN
    Title          = '...'                               # human-readable
    RequiredScopes = @('Application.Read.All')           # least-privilege
    Online         = $false                              # opt-out flag for future
                                                         # online checks
    ScriptBlock    = { param($Check) ... }               # the check body
}
```

`ScriptBlock` receives the registry entry as `$Check` so it can self-reference its own `Id` and `ControlIds` when calling `New-EapFinding`. Checks should not hard-code their own EAPC id inside the script block — read it from `$Check.Id`.

### Finding

What every check emits and what `Invoke-EntraAppPosture` returns on the pipeline:

```powershell
[PSCustomObject]@{
    CheckId    = 'EAPC-014'                              # which check emitted this
    ControlIds = @('MSR-04')                             # which controls it contributes to
    ObjectType = 'Application'                           # 'Tenant' | 'Application' |
                                                         # 'ServicePrincipal' | ...
    ObjectId   = '<appId or tenantId>'                   # canonical object identifier
    ObjectName = 'My App'                                # human-readable
    Status     = 'Fail'                                  # 'Pass' | 'Fail' | 'NA' | 'Error'
    Evidence   = @{ ... }                                # check-specific hashtable
    Timestamp  = [datetime]::UtcNow                      # always UtcNow at emission
}
```

`Evidence` is the only shape-flexible field. Each check decides what evidence captures the why behind a `Fail` (e.g., `OffendingUris`, `AllowedToCreateApps`). Keep keys descriptive and prefer typed values (booleans, ints, arrays of objects) over pre-formatted strings — downstream consumers can format; they cannot un-format.

`Status='NA'` means the check was inapplicable to the object (e.g., an app with zero redirect URIs is vacuously safe under EAPC-014). `Status='Error'` means the check itself failed to execute — only the runner emits these.

---

## The check authoring contract

To add a new check, three things change:

1. **Register a row in [`docs/controls.md`](../docs/controls.md).** Status `Planned`. ID is the next free `EAPC-NNN`.
2. **Add `src/Checks/EAPC-NNN.ps1`** with a single `Register-EapCheck` call.
3. **Add `tests/Checks/EAPC-NNN.Tests.ps1`** with synthetic Graph responses covering Pass / Fail / NA paths.

Optionally:

4. If the check needs a Graph submodule not already pinned, add it to `RequiredModules` in `EntraAppPosture.psd1`.

Minimal check skeleton:

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Register-EapCheck @{
    Id             = 'EAPC-NNN'
    ControlIds     = @('MSR-NN')
    Title          = '<verb-led, declarative title matching docs/controls.md>'
    RequiredScopes = @('<minimum scopes>')
    Online         = $false
} -ScriptBlock {
    param([Parameter(Mandatory)] $Check)

    # 1. Query Graph (use only submodules pinned in the manifest).
    # 2. Iterate over the returned objects.
    # 3. For each object, emit one finding via New-EapFinding using
    #    $Check.Id and $Check.ControlIds.
    # 4. Use Status='NA' when the check is inapplicable to the object;
    #    do not silently skip.
}
```

What **not** to do in a check file:

- Hard-code the EAPC id inside the script block. Read `$Check.Id`.
- Call `Connect-MgGraph` directly. The runner handles auth.
- Create your own finding shape. Always go through `New-EapFinding`.
- Catch and swallow exceptions. Let them bubble to the runner, which converts them to `Status='Error'` findings.
- Add a helper function in the check file if more than one check needs it. Move it to `Private/`.

---

## Extension points and what's deliberately not here

What the framework supports today:

- Registering N checks; filtering by `CheckId` / `ControlId` / `ExcludeCheckId`.
- One PSCustomObject finding per evaluated object.
- Interactive Graph auth with idempotent reconnection.
- Per-check error isolation.

What's deliberately deferred (each can be added without restructuring):

| Capability | Where it will land | Trigger |
|---|---|---|
| Control-level aggregation (`Get-EapControlSummary`) | new `Public/Get-EapControlSummary.ps1` | when 3+ checks share a single MSR-NN |
| JSON / SARIF exporters | new `Public/Export-EapResult.ps1` | when finding shape stabilizes across more checks |
| App-only / certificate / managed-identity auth | extend `Connect-EapGraph.ps1` | when scopes stabilize and CI use cases land |
| `-Online:$false` opt-out for network-dependent checks | flag already in registry; needs runner support | when EAPC-020 / EAPC-021 (DNS, HTTP) land |
| Per-app boolean aggregation (MSR-09 form) | new helper in `Private/`, used by `Get-EapControlSummary` | when any MSR-09 check lands |
| Topical helper subfolders under `Private/` | reorganize when 3+ helpers cluster on one topic | not before |
| Per-check exported cmdlets (`Invoke-EAPC014`) | not planned | use `-CheckId` filter instead |

Each deferral is a deliberate choice from slice 1's plan, not an oversight. Adding any of them earlier than the trigger condition risks designing for a hypothetical instead of a real check.
