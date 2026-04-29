# entra-app-posture — project notes

## Project overview

PowerShell + Microsoft.Graph SDK toolkit that runs **read-only** posture checks against Microsoft Entra Enterprise Applications, app registrations, service principals, consent settings, and workload identities. Checks map to Microsoft's [Zero Trust — Protect engineering systems](https://learn.microsoft.com/en-us/entra/fundamentals/zero-trust-protect-engineering-systems) guidance. The tool **reports** findings; it does not remediate.

## Tech stack

- PowerShell 7+
- Microsoft.Graph SDK — specific submodules _TBD_ (pinned narrowly per check, not a blanket dependency on the umbrella `Microsoft.Graph` package)
- Pester 5+ for tests

## Check ID convention

- Format: `EAPC-NNN` (e.g., `EAPC-001`)
- Three-digit zero-padded
- Sequentially assigned. **Never reused, never reassigned** — even for deleted or deferred checks
- The canonical registry of every assigned ID is [`docs/controls.md`](docs/controls.md). Every check shipped in code MUST have a matching row.

## Repo layout

_TBD_ — will be filled in once `src/`, `tests/`, and the module manifest are added.

## How checks are authored

_TBD_

## Output format

_TBD_ — JSON / SARIF / PowerShell objects to be decided when the first check is implemented.

## Running tests

_TBD_

## Permissions / Microsoft Graph scopes

_TBD_ — least-privilege scopes will be documented per-check and aggregated in the README.

## Conventions defer to global standards

General PowerShell, git, and tooling standards live in the maintainer's `~/.claude/CLAUDE.md` and are not duplicated here. Add an entry below only when this project deviates from those defaults.

### Project-specific deviations

_None yet._
