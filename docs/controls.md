# Controls

This file is the canonical registry of every control and every check shipped in `entra-app-posture`. Source guidance: [Microsoft Entra — Zero Trust — Protect engineering systems](https://learn.microsoft.com/en-us/entra/fundamentals/zero-trust-protect-engineering-systems). Term-of-art definitions referenced by checks (e.g., "inactive application", "dedicated administrative account", "highly privileged Graph permission") live in [`definitions.md`](definitions.md).

## Two-tier model

- **Control** (`MSR-NN`) — one row per Microsoft recommendation we track. The aggregate finding the tool reports.
- **Check** (`EAPC-NNN`) — one row per discrete verifiable condition. A check may contribute to one or more controls.

Each control declares its aggregation rule in the `Aggregation` column of the Controls table. The default rule is `AND` — the control passes only if every non-NA contributing check passes; one failing check fails it, and a control whose contributing checks are all NA is itself NA. Some controls override this with per-app boolean expressions or other patterns recorded directly in the column; see [`CLAUDE.md`](../CLAUDE.md) for the supported forms.

## ID rules

- `MSR-NN`: two-digit zero-padded. Sequentially assigned. **Never reused, never reassigned** once a control ships in code.
- `EAPC-NNN`: three-digit zero-padded. Sequentially assigned. **Never reused, never reassigned** once a check ships in code.
- Every control and every check shipped in code MUST have a matching row in this file.

> **One-time reset note.** The first scaffolding commit assigned `EAPC-001`–`EAPC-010` directly to MS recommendations as 1:1 placeholders. No code referenced those IDs, so they are reset and will be reassigned to actual sub-checks during the upcoming breakdown. The never-reuse rule applies starting with the first check that ships in code.

## Status legend

- `Planned` — registered here, no code yet.
- `Drafting` — implementation in progress.
- `Implemented` — shipping in the module.
- `Deferred` — registered but intentionally not being built right now; ID stays reserved.

## Controls

The `Aggregation` column declares how the control's pass/fail is computed from its contributing checks (default `AND`; see [`CLAUDE.md`](../CLAUDE.md) for other supported forms). The `Notes` column captures cross-references and caveats — most rows are blank.

| MSR-ID | Title | Source recommendation | Aggregation | Status | Notes |
|---|---|---|---|---|---|
| MSR-01 | App and service principal creation restricted to privileged users | Creating new applications and service principals is restricted to privileged users | AND | Planned | Application ownership concerns mentioned in this recommendation are covered by MSR-10. |
| MSR-02 | Inactive apps lack highly privileged Graph API permissions | Inactive applications don't have highly privileged Microsoft Graph API permissions | AND | Planned | |
| MSR-03 | Inactive apps lack highly privileged built-in roles | Inactive applications don't have highly privileged built-in roles | AND | Planned | |
| MSR-04 | App registrations use safe redirect URIs | App registrations use safe redirect URIs | AND | Planned | |
| MSR-05 | Service principals use safe redirect URIs | Service principals use safe redirect URIs | AND | Planned | |
| MSR-06 | App registrations have no dangling or abandoned redirect URIs | App registrations must not have dangling or abandoned domain redirect URIs | AND | Planned | |
| MSR-07 | Resource-specific consent is restricted | Resource-specific consent is restricted | AND | Planned | |
| MSR-08 | Workload identities are not assigned privileged roles | Workload Identities are not assigned privileged roles | AND | Planned | |
| MSR-09 | Enterprise apps require explicit assignment or scoped provisioning | Enterprise applications must require explicit assignment or scoped provisioning | `per-app: (EAPC-030 AND EAPC-031) OR EAPC-032` | Planned | |
| MSR-10 | Enterprise application ownership is appropriate | Enterprise applications have owners | AND | Planned | Privileged-app ownership: any owner is a privilege-escalation path; EAPC-033/034 flag presence of owners on privileged apps. EAPC-036 (Deferred) will refine this to allow protected-owner exceptions. |

## Checks

The `Controls` column lists every `MSR-NN` the check contributes to (comma-separated). A check may contribute to one or more controls.

| EAPC-ID | Controls | Title | Status |
|---|---|---|---|
| EAPC-001 | MSR-01 | Users cannot register applications | Implemented |
| EAPC-002 | MSR-01 | Users cannot consent to applications | Planned |
| EAPC-003 | MSR-01 | Application Developer role members are dedicated administrative accounts | Planned |
| EAPC-004 | MSR-01 | Application Administrator role members are dedicated administrative accounts | Planned |
| EAPC-005 | MSR-01 | Cloud Application Administrator role members are dedicated administrative accounts | Planned |
| EAPC-006 | MSR-01 | Custom roles with [app create/update permissions](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/custom-available-permissions) granted only to dedicated administrative accounts | Planned |
| EAPC-007 | MSR-02 | Inactive applications don't have highly privileged Graph API permissions | Planned |
| EAPC-008 | MSR-02 | Disabled service principals don't have highly privileged Graph API permissions | Planned |
| EAPC-009 | MSR-03 | Inactive applications don't have highly privileged built-in roles | Planned |
| EAPC-010 | MSR-03 | Disabled service principals don't have highly privileged built-in roles | Planned |
| EAPC-011 | MSR-04 | App registrations have no wildcard redirect URIs | Planned |
| EAPC-012 | MSR-04, MSR-06 | App registrations have no redirect URIs on reclaimable shared hosting domains | Planned |
| EAPC-013 | MSR-04 | App registrations have no URL-shortener redirect URIs | Planned |
| EAPC-014 | MSR-04 | App registrations have no HTTP (non-localhost) redirect URIs | Implemented |
| EAPC-015 | MSR-05 | Service principals have no wildcard redirect URIs | Planned |
| EAPC-016 | MSR-05 | Service principals have no redirect URIs on reclaimable shared hosting domains | Planned |
| EAPC-017 | MSR-05 | Service principals have no URL-shortener redirect URIs | Planned |
| EAPC-018 | MSR-05 | Service principals have no localhost redirect URIs | Planned |
| EAPC-019 | MSR-05 | Service principals have no HTTP (non-localhost) redirect URIs | Planned |
| EAPC-020 | MSR-06 | App registration redirect URI hostnames resolve in DNS | Planned |
| EAPC-021 | MSR-06 | App registration redirect URIs do not return HTTP 4xx/5xx errors | Planned |
| EAPC-022 | MSR-07 | Team-scoped RSC configuration is set to `EnabledForPreApprovedAppsOnly` | Planned |
| EAPC-023 | MSR-07 | Chat-scoped RSC configuration is set to `EnabledForPreApprovedAppsOnly` | Planned |
| EAPC-024 | MSR-07 | Pre-approval policies exist for apps that require RSC permissions | Planned |
| EAPC-025 | MSR-08 | Workload identities are not assigned highly privileged built-in roles | Planned |
| EAPC-026 | MSR-08 | Conditional Access policies target workload identities owned by the organization | Deferred |
| EAPC-027 | MSR-08 | Continuous Access Evaluation is enabled for workload identities | Deferred |
| EAPC-028 | MSR-08 | Microsoft Entra ID Protection workload-identity risk policies are configured | Deferred |
| EAPC-029 | MSR-08 | Workload identities are not assigned highly privileged Graph API permissions | Planned |
| EAPC-030 | MSR-09 | Enterprise applications have `Assignment Required = Yes` | Planned |
| EAPC-031 | MSR-09 | Enterprise applications with assignment required have explicit user/group/app assignments (non-empty, not 'All Users') | Planned |
| EAPC-032 | MSR-09 | Enterprise applications with provisioning configured have user/group scoping filters | Planned |
| EAPC-033 | MSR-10 | Applications with highly privileged Microsoft Graph API permissions do not have owners | Planned |
| EAPC-034 | MSR-10 | Applications that are members of a highly privileged built-in role do not have owners | Planned |
| EAPC-035 | MSR-10 | Application owners are consistent across app registration and service principal | Planned |
| EAPC-036 | MSR-10 | Application owners are protected | Deferred |
