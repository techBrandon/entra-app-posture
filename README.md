# entra-app-posture

Read-only posture checks for Microsoft Entra Enterprise Applications and related identity objects, mapped to Microsoft's [Zero Trust — Protect engineering systems](https://learn.microsoft.com/en-us/entra/fundamentals/zero-trust-protect-engineering-systems) guidance.

## Status

Early development. Check IDs and behavior may change without notice until a 1.0 release.

## What it checks

See [`docs/controls.md`](docs/controls.md) for the canonical list of checks, their `EAPC-NNN` identifiers, and current implementation status.

## Requirements

_TBD_ — PowerShell 7+ and selected `Microsoft.Graph` submodules. The exact submodule list will be pinned as checks are authored, to avoid a blanket dependency on the full SDK.

## Installation

_TBD_

## Usage

_TBD_

## Output

_TBD_

## Required Microsoft Graph permissions

_TBD_ — least-privilege scopes will be documented per-check and aggregated here.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Security

See [`SECURITY.md`](SECURITY.md) for vulnerability reporting.

## License

[MIT](LICENSE) — Copyright (c) 2026 Brandon Colley.
