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
4. _TBD_ — link to the check authoring guide once it exists.

IDs in both namespaces are sequential, zero-padded, and **never reused** once a control or check ships in code.

## Dev setup

_TBD_ — install steps for `pwsh`, the relevant `Microsoft.Graph` submodules, and `Pester` will be documented once the module manifest lands.

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
