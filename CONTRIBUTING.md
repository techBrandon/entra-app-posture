# Contributing

Thanks for your interest in `entra-app-posture`. This file is a skeleton — most sections are placeholders until the project is further along.

## Proposing a new control or check

The project uses a two-tier registry in [`docs/controls.md`](docs/controls.md): controls (`MSR-NN`) aggregate the Microsoft recommendations we track, and checks (`EAPC-NNN`) are the discrete conditions that a check function verifies. A check can contribute to more than one control.

### Adding a control (`MSR-NN`)

Rare — typically only when Microsoft publishes new guidance worth tracking.

1. Identify the next free `MSR-NN` by reading [`docs/controls.md`](docs/controls.md).
2. Add a row to the `## Controls` table with status `Planned`. Put the verbatim MS recommendation phrasing in the `Source recommendation` column for traceability.

### Adding a check (`EAPC-NNN`)

1. Identify the next free `EAPC-NNN` by reading [`docs/controls.md`](docs/controls.md).
2. Add a row to the `## Checks` table with status `Planned` before opening a PR with code.
3. In the `Controls` column, list every `MSR-NN` the check contributes to (comma-separated). One check may contribute to multiple controls.
4. Create `Checks/EAPC-NNN.ps1`. See existing checks for the structure: `#Requires` block, `[CmdletBinding()] param()`, dot-source `Helpers.ps1`, top-level `try`/`catch`, query Graph through a `Get-Eap*` getter (or add a new one to `Helpers.ps1` if your check is the first consumer), defensive validation, emit findings via `New-EapFinding`. Iterating checks add a per-item `try`/`catch` so one bad item yields a per-item `Error` finding without aborting the loop.
5. Add a row to the `$AllChecks` manifest at the top of `Run-EntraAppPosture.ps1`.
6. If the check needs a Graph cmdlet not already wrapped in `Helpers.ps1`, add a cached getter there and a corresponding test in `tests/Helpers.Tests.ps1`.
7. Add Pester tests at `tests/Checks/EAPC-NNN.Tests.ps1`. Mock the underlying `Get-Mg*` cmdlets directly (the helper's caching layer is transparent). Reset the cache in `BeforeEach` with `$global:EapCache = @{}` so previous tests don't leak state.

**Don't:**
- Hard-code `Connect-MgGraph` calls in checks. Use `Get-Eap*` getters; they connect on demand.
- Inline `[PSCustomObject]@{ ... }` finding literals. Use `New-EapFinding`.
- Catch and swallow exceptions inside the per-item logic without emitting an `Error` finding.

IDs in both namespaces are sequential, zero-padded, and **never reused** once a control or check ships in code.

## Dev setup

PowerShell 7+ (`pwsh`) is required. The same install commands work on macOS, Linux, and Windows; Windows has a couple of extra prerequisites called out below.

```sh
# Microsoft.Graph submodules used by current checks
pwsh -c "Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Applications -Scope CurrentUser"

# Pester 5+ for the test suite
pwsh -c "Install-Module Pester -MinimumVersion 5.0.0 -Scope CurrentUser -SkipPublisherCheck"
```

Run a single check directly:

```sh
pwsh ./Checks/EAPC-001.ps1
```

Run the full suite via the orchestrator:

```sh
pwsh ./Run-EntraAppPosture.ps1
```

### Windows notes

Run everything in **PowerShell 7+ (`pwsh`)**, not Windows PowerShell 5.1 — the project's `#Requires -Version 7.0` won't parse under 5.1.

1. Install PowerShell 7+ if `pwsh --version` doesn't work yet:
   ```powershell
   winget install --id Microsoft.PowerShell --source winget
   ```
   Then open a new "PowerShell 7" terminal and run the commands above from there.

2. Set the execution policy for the current user once, if you've never done so:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```

3. The `-SkipPublisherCheck` on the `Install-Module Pester` line is **required** on Windows: Windows PowerShell ships with an old Pester 3.4.0 signed by Microsoft, and the current PSGallery Pester is signed by a different publisher — without the flag the install errors with a publisher mismatch.

4. If `Install-Module` fails with "Unable to resolve package source" on Windows Server or older builds, force TLS 1.2 first:
   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   ```

5. The macOS-only branch in `tests/Invoke.ps1` (the `if ($IsMacOS) { ... }` Pester `Get-TempDirectory` override) is skipped on Windows. Setting `$env:TMPDIR` is also a no-op there since .NET reads `$env:TEMP` on Windows. Both are harmless leftovers — the suite runs the same way on either OS.

## Recommended skills (optional)

If you use Claude Code or another Agent Skill–compatible harness, install the [`merill/msgraph`](https://github.com/merill/msgraph) skill. It bundles the full Microsoft Graph API surface (27,700+ endpoints, resource schemas, permission scopes, community samples) as locally-searchable indexes, which is a strong fit for authoring and reviewing checks in this repo.

User-scoped install (recommended — available to all your projects):

```sh
npx skills add merill/msgraph
```

Or manual:

```sh
curl -fsSL -o /tmp/msgraph.zip https://github.com/merill/msgraph/releases/latest/download/msgraph.zip
unzip /tmp/msgraph.zip -d ~/.claude/skills/
```

For project-scoped install, substitute `.claude/skills/` (relative to the repo root) for `~/.claude/skills/`. Project-scoped installs should be gitignored, not committed.

## Code style

_TBD_ — defaults to the PowerShell conventions in the maintainer's global standards (PowerShell 7+, `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, approved verbs, `Invoke-ScriptAnalyzer` and `Invoke-Formatter`). Project-specific overrides will be added here as decisions are made.

## Testing

Pester 5+ with `*.Tests.ps1` colocated under `tests/` mirroring the source layout.

Run the suite via the project invoker:

```sh
pwsh ./tests/Invoke.ps1
```

The invoker sets `$env:TMPDIR` to `tests/.testdrive/` (gitignored) so Pester's TestDrive doesn't depend on `/tmp` write access. The change is scoped to that PowerShell process only.

To filter, pass `-Path`:

```sh
pwsh ./tests/Invoke.ps1 -Path ./tests/Checks/EAPC-014.Tests.ps1
```

## Pull request checklist

_TBD_
