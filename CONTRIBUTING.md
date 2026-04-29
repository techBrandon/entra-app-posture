# Contributing

Thanks for your interest in `entra-app-posture`. This file is a skeleton — most sections are placeholders until the project is further along.

## Proposing a new check

1. Identify the next free `EAPC-NNN` ID by reading [`docs/controls.md`](docs/controls.md). IDs are sequential, three-digit zero-padded, and **never reused** once assigned.
2. Add a row to `docs/controls.md` with status `Planned` before opening a PR with code.
3. _TBD_ — link to the check authoring guide once it exists.

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

_TBD_ — Pester 5+ with `*.Tests.ps1` colocated next to the source under test.

## Pull request checklist

_TBD_
