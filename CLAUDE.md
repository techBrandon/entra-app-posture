# entra-app-posture — project notes

## Project overview

PowerShell + Microsoft.Graph SDK toolkit that runs **read-only** posture checks against Microsoft Entra Enterprise Applications, app registrations, service principals, consent settings, and workload identities. Checks map to Microsoft's [Zero Trust — Protect engineering systems](https://learn.microsoft.com/en-us/entra/fundamentals/zero-trust-protect-engineering-systems) guidance. The tool **reports** findings; it does not remediate.

## Tech stack

- PowerShell 7+
- Microsoft.Graph SDK — specific submodules _TBD_ (pinned narrowly per check, not a blanket dependency on the umbrella `Microsoft.Graph` package)
- Pester 5+ for tests

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

_TBD_ — will be filled in once `src/`, `tests/`, and the module manifest are added.

## How checks are authored

_TBD_

## Output format

_TBD_ — JSON / SARIF / PowerShell objects to be decided when the first check is implemented.

## Running tests

_TBD_

## Permissions / Microsoft Graph scopes

_TBD_ — least-privilege scopes will be documented per-check and aggregated in the README.

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
