# Controls

This file is the canonical registry of every check in `entra-app-posture`. Source guidance: [Microsoft Entra — Zero Trust — Protect engineering systems](https://learn.microsoft.com/en-us/entra/fundamentals/zero-trust-protect-engineering-systems).

## ID rules

- Format: `EAPC-NNN`, three-digit zero-padded.
- Sequentially assigned. **Never reused, never reassigned** — once an ID maps to a check it keeps that meaning forever, even if the check is later removed or deferred.
- Every check shipped in code MUST have a matching row in this table.

## Status legend

- `Planned` — registered here, no code yet.
- `Drafting` — implementation in progress.
- `Implemented` — shipping in the module.
- `Deferred` — registered but intentionally not being built right now; ID stays reserved.

## Checks

| ID | Title | Category | MS source recommendation | Status |
|---|---|---|---|---|
| EAPC-001 | App and service principal creation restricted to privileged users | App lifecycle | Creating new applications and service principals is restricted to privileged users | Planned |
| EAPC-002 | Inactive apps lack highly privileged Graph API permissions | Inactive apps | Inactive applications don't have highly privileged Microsoft Graph API permissions | Planned |
| EAPC-003 | Inactive apps lack highly privileged built-in roles | Inactive apps | Inactive applications don't have highly privileged built-in roles | Planned |
| EAPC-004 | App registrations use safe redirect URIs | Redirect URI hygiene | App registrations use safe redirect URIs | Planned |
| EAPC-005 | Service principals use safe redirect URIs | Redirect URI hygiene | Service principals use safe redirect URIs | Planned |
| EAPC-006 | App registrations have no dangling or abandoned redirect URIs | Redirect URI hygiene | App registrations must not have dangling or abandoned domain redirect URIs | Planned |
| EAPC-007 | Resource-specific consent is restricted | Consent governance | Resource-specific consent is restricted | Planned |
| EAPC-008 | Workload identities are not assigned privileged roles | Workload identity | Workload Identities are not assigned privileged roles | Planned |
| EAPC-009 | Enterprise apps require explicit assignment or scoped provisioning | Enterprise apps | Enterprise applications must require explicit assignment or scoped provisioning | Planned |
| EAPC-010 | Enterprise apps have owners | Enterprise apps | Enterprise applications have owners | Planned |
