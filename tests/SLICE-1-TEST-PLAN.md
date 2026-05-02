# Slice 1 test plan — EAPC-001 and EAPC-014

This plan covers the two checks shipped in slice 1 ([EAPC-001](../Checks/EAPC-001.ps1) and [EAPC-014](../Checks/EAPC-014.ps1)). It enumerates every Pass / Fail / NA / Error path, the malformed-data edge cases that should produce `Error` (not Pass or Fail), the tenant configuration needed to exercise each path live, and the recommended code hardening based on the gaps the matrices expose.

## Status (as of the simplification rewrite)

- The "Recommended hardening" sections below have **shipped**. EAPC-001 now does explicit `-isnot [bool]` validation; EAPC-014 wraps each app's evaluation in its own `try/catch`. The "Current behavior" columns in the matrices below describe the *original* slice-1 implementation that prompted the hardening — read them as the rationale for the current code, not as a description of it.
- Pester coverage went from 18 → 30 tests in the simplification commit. The new cases include defensive-shape paths for EAPC-001 and the per-app Error isolation case for EAPC-014.
- Live-tenant verification still uses the seeding tables and verification commands below.

## Scope and approach

Three test layers, each with a different question:

| Layer | Question | Lives in |
|---|---|---|
| Pester unit tests | "Given a known Graph response, does the check produce the right finding?" | `tests/Checks/*.Tests.ps1` |
| Tenant scenarios | "Against real Graph responses on a controlled tenant, does the check produce the right finding?" | manual, this plan |
| Defensive-shape tests | "When Graph returns something the check did not anticipate, does the check fail safe (Error) instead of fail wrong (Pass/Fail)?" | both layers |

The third layer is the most important and the most neglected. Per the project bar (`docs/CLAUDE.md` — "verified against a real tenant"), Pester alone is not sufficient. Per defensive engineering, real-tenant testing alone is also not sufficient — production tenants are unlikely to exhibit the corrupt-data shapes that an attacker or misconfiguration could produce. Both layers are required.

## EAPC-001 — `allowedToCreateApps` matrix

The check reads `(Get-MgPolicyAuthorizationPolicy).DefaultUserRolePermissions.AllowedToCreateApps` and emits one tenant-wide finding.

### Happy paths

| # | `AllowedToCreateApps` | Current status | Expected status | Tested in Pester | Live-tenant scenario |
|---|---|---|---|---|---|
| 1 | `$false` | `Pass` | `Pass` | Yes | Set tenant policy to forbid user app creation |
| 2 | `$true`  | `Fail` | `Fail` | Yes | Set tenant policy to allow user app creation |

### Defensive-shape paths (currently produce wrong answers)

The current implementation does `$status = if ($allowed) { 'Fail' } else { 'Pass' }`. PowerShell's truthiness coerces non-boolean values, so any unexpected type returns Pass or Fail by accident — never Error. These cases need explicit type validation:

| # | Returned value | Current behavior | Recommended behavior | Reason |
|---|---|---|---|---|
| 3 | `$null` (property exists, value null) | Pass (null is falsy) | `Error` | We don't *know* the value; "Pass" is a false negative |
| 4 | `0` (int) | Pass (0 is falsy) | `Error` | Type mismatch; not a guaranteed semantic of Graph's bool |
| 5 | `1` (int) | Fail (truthy) | `Error` | Same as above |
| 6 | `'true'` (string) | Fail (non-empty string is truthy) | `Error` | Type mismatch |
| 7 | `'false'` (string) | Fail (non-empty string is truthy) | `Error` | False negative for the security state |
| 8 | `''` (empty string) | Pass (empty is falsy) | `Error` | Type mismatch |
| 9 | `DefaultUserRolePermissions` is `$null` | Throws under strict mode → caught by runner → `Error` | `Error` (already correct) | Strict-mode null-property access throws; runner converts |
| 10 | `Get-MgPolicyAuthorizationPolicy` returns `$null` | Throws → `Error` | `Error` (already correct) | Same path as #9 |
| 11 | `Get-MgPolicyAuthorizationPolicy` returns multiple objects | Reads `.DefaultUserRolePermissions` on the array, may throw or get the first | `Error` | The endpoint returns a single object; multiple is anomalous |
| 12 | `Get-MgContext` returns `$null` (not connected) | `(Get-MgContext).TenantId` throws → `Error` | `Error` (already correct) | Strict-mode path |

Cases 3–8 and 11 are the gap. The check should validate `AllowedToCreateApps -is [bool]` and emit a structured `Error` finding when it isn't.

### Recommended hardening for EAPC-001

```powershell
$policy = Get-MgPolicyAuthorizationPolicy
if ($policy -is [array] -and $policy.Count -gt 1) {
    # case 11
    throw "authorizationPolicy returned $($policy.Count) objects; expected 1."
}

$perms = $policy.DefaultUserRolePermissions
$allowed = $perms.AllowedToCreateApps

if ($allowed -isnot [bool]) {
    # cases 3–8
    throw "AllowedToCreateApps was not a Boolean (got $($allowed.GetType().FullName) = '$allowed')."
}

$status = if ($allowed) { 'Fail' } else { 'Pass' }
```

Throwing inside the script block is intentional — the runner converts thrown exceptions into `Status='Error'` findings with the message in `Evidence`, which is exactly the behavior we want.

## EAPC-014 — redirect-URI matrix

The check iterates `Get-MgApplication -All`, collects redirect URIs from `Web`, `Spa`, and `PublicClient`, and emits one finding per app. A URI is an offender if it cannot be parsed as an absolute URI **or** if it has scheme `http` and host other than exactly `localhost`.

### Per-URI matrix (table format used by Pester cases)

| # | URI | Expected | Currently | Notes |
|---|---|---|---|---|
| 1 | `https://example.com/cb` | Pass | Pass | Standard HTTPS |
| 2 | `http://example.com/cb` | Fail | Fail | Standard HTTP non-localhost |
| 3 | `http://localhost` | Pass | Pass | Literal localhost |
| 4 | `http://localhost:8080/cb` | Pass | Pass | Localhost with port |
| 5 | `http://LOCALHOST` | Pass | Pass | `[Uri].Host` lowercases, then `.ToLowerInvariant()` is idempotent |
| 6 | `http://localhost.evil.com` | Fail | Fail | Suffix-style smuggling |
| 7 | `http://127.0.0.1` | Fail | Fail | Numeric loopback ≠ string literal `localhost` |
| 8 | `http://[::1]` | Fail | Fail | IPv6 loopback ≠ string literal `localhost` |
| 9 | `https://localhost` | Pass | Pass | HTTPS is always Pass regardless of host |
| 10 | `Http://example.com` | Fail | Fail | `[Uri].Scheme` is normalized lowercase |
| 11 | `http://user:pass@example.com` | Fail | Fail | Userinfo doesn't change host |
| 12 | `http://example.com:80` | Fail | Fail | Explicit port doesn't change scheme/host evaluation |
| 13 | `ms-appx://contoso.example.com` | Pass | Pass | Custom scheme, not http |
| 14 | `customscheme://anything` | Pass | Pass | Same |
| 15 | `urn:ietf:rfc:2648` | Pass | Pass | Opaque URI, scheme=`urn` |
| 16 | `file:///etc/passwd` | Pass | Pass | scheme=`file`; out of scope for this check |
| 17 | `not a url` | Fail | Fail (parse failure) | TryCreate(Absolute) returns false |
| 18 | `''` (empty string) | Fail | Fail (parse failure) | TryCreate returns false |
| 19 | `'   '` (whitespace) | Fail | Fail (parse failure) | TryCreate returns false |
| 20 | `$null` element in `RedirectUris` | Fail | Fail (parse failure) | TryCreate(null,...) returns false |
| 21 | `http://` (no host) | Fail | Fail | Parses as URI with empty host; empty ≠ `localhost` |
| 22 | `http://xn--bcher-kva.example` | Fail | Fail | Punycode host; treated like any other non-localhost |
| 23 | URI with trailing whitespace `'http://example.com '` | Fail | Fail | TryCreate is strict about whitespace |
| 24 | Very long URI (e.g., 4 KB) | Fail (if http non-localhost) | Fail | Length doesn't change scheme/host evaluation |

All 24 cases are deterministic and Pester-testable.

### Per-app bucket matrix

| # | Web | Spa | PublicClient | Expected | Currently | Notes |
|---|---|---|---|---|---|---|
| 25 | `null` | `null` | `null` | NA | NA | App with no redirect-URI buckets at all |
| 26 | `{RedirectUris=@()}` | `null` | `null` | NA | NA | Bucket present, empty array |
| 27 | `{RedirectUris=$null}` | `null` | `null` | NA | NA | Bucket present, null array |
| 28 | `{...one https...}` | `null` | `null` | Pass | Pass | Single safe URI on web |
| 29 | `null` | `{...one https...}` | `null` | Pass | Pass | Single safe URI on spa |
| 30 | `null` | `null` | `{...one https...}` | Pass | Pass | Single safe URI on publicClient |
| 31 | `{...https...}` | `{...http non-localhost...}` | `null` | Fail | Fail | Mixed — only spa offender flagged |
| 32 | `{...https, http://example.com...}` | `null` | `null` | Fail | Fail | Per-URI granularity within one bucket |
| 33 | `{...same uri twice...}` | `null` | `null` | Fail (twice in evidence) | Fail (twice in evidence) | Acceptable; we don't dedupe |
| 34 | All three populated, all https | | | Pass | Pass | Cross-bucket OK path |
| 35 | All three populated, one http per bucket | | | Fail (3 offenders) | Fail (3 offenders) | RedirectUriCount=3, OffendingUris=3 |

### Defensive-shape paths

| # | Scenario | Currently | Expected |
|---|---|---|---|
| 36 | `$app.AppId` is `$null` | `New-EapFinding -ObjectId $null` fails its `[ValidateNotNullOrEmpty()]` and throws → caught by runner → single `Error` finding for the whole check (not for that app) | One per-app `Error` finding, the rest of the run continues |
| 37 | `$app.DisplayName` is `$null` | Pass-through; `ObjectName` becomes empty string | Same (acceptable) |
| 38 | `Get-MgApplication` returns `$null` | Loop body doesn't execute; no findings | Same (acceptable — no apps means nothing to evaluate) |
| 39 | `Get-MgApplication` throws | Caught by runner → one `Error` finding | Same (already correct) |
| 40 | `Get-MgApplication` returns thousands of apps | Works, but may be slow | Acceptable for slice 1; revisit when paging/perf becomes an issue |
| 41 | `$app.Web` is missing as a property entirely (not just null) | `$app.Web` under strict mode v3 throws → runner emits one `Error` for the whole check | One per-app `Error`, rest of run continues |
| 42 | `RedirectUris` contains a non-string (e.g., a hashtable) | `[Uri]::TryCreate` accepts only `[string]`; coerces or fails | Audit — current behavior depends on .NET version |

Cases 36 and 41 are the meaningful gap. Right now an isolated bad app aborts the whole check via the runner's catch. The check should catch *its own* per-app exceptions, emit an `Error` finding for that app, and keep iterating.

### Recommended hardening for EAPC-014

```powershell
Get-MgApplication -All | ForEach-Object {
    $app = $_
    try {
        if ([string]::IsNullOrEmpty($app.AppId)) {
            throw "Application has no AppId; object id = '$($app.Id)'."
        }

        # ... existing URI evaluation ...
    }
    catch {
        New-EapFinding `
            -CheckId    $Check.Id `
            -ControlIds $Check.ControlIds `
            -ObjectType 'Application' `
            -ObjectId   ($app.AppId ?? $app.Id ?? 'unknown') `
            -ObjectName $app.DisplayName `
            -Status     'Error' `
            -Evidence   @{ Message = $_.Exception.Message; Type = $_.Exception.GetType().FullName }
    }
}
```

Per-app `try/catch` matters because EAPC-014 emits N findings (one per app), and we don't want a single bad row to suppress findings for the other N-1 apps.

## Pester additions

The current Pester suite covers cases 1, 2, 3, 6, 17, 25, 28, 31, 33, 35 (mapped from existing test descriptions). To close the matrix, add Pester tests for:

**EAPC-001:**
- Cases 3–8 (defensive types) — once hardening lands.
- Case 11 (multiple objects) — once hardening lands.

**EAPC-014:**
- Cases 4, 5, 7, 8, 9, 10, 11, 12, 13, 15, 18, 19, 20, 21, 22, 23 (URI variants).
- Cases 26, 27, 29, 30, 34 (bucket variants).
- Case 36 (per-app Error isolation) — once hardening lands.

Mocking strategy after the simplification rewrite: checks are scripts (not module functions), so Pester's `Mock` works directly on the cmdlets they call — no `InModuleScope` needed. Pattern:

```powershell
BeforeEach {
    Mock Connect-MgGraph {}
    Mock Get-MgContext { [PSCustomObject]@{ TenantId='tx'; Scopes=@('Application.Read.All') } }
}
It '...' {
    Mock Get-MgApplication { New-FakeApp -WebUris @('http://example.com') }
    $f = & $script:CheckPath
    $f.Status | Should -Be 'Fail'
}
```

The `New-FakeApp` helper lives in the test file's `BeforeAll` block and returns synthetic `[PSCustomObject]` shapes that mirror `Get-MgApplication`'s output.

## Live-tenant test setup

Use a non-production tenant. The seed creates one app registration per scenario the check needs to exercise live. Names are deliberate — they should sort together and be obvious to delete after testing.

> **Heads-up on caching during iterative testing.** `Helpers.ps1` caches Graph responses in `$global:EapCache` for the lifetime of the `pwsh` process. If you toggle a tenant setting and re-run a check from the **same** `pwsh` session, the second run reads the stale cached response. Pass `-RefreshData` to force a re-fetch:
>
> ```pwsh
> pwsh ./Run-EntraAppPosture.ps1 -CheckId EAPC-001 -RefreshData
> pwsh ./Checks/EAPC-001.ps1 -RefreshData
> ```
>
> Equivalent: `$global:EapCache = @{}` between runs, or open a fresh `pwsh` (child processes spawned from a non-pwsh shell get their own cache).

### EAPC-001 (tenant policy)

Run twice, toggling the tenant-wide policy:

```pwsh
# Pass scenario — confirm Status='Pass'
Update-MgPolicyAuthorizationPolicy -DefaultUserRolePermissions @{ allowedToCreateApps = $false }
pwsh ./Checks/EAPC-001.ps1

# Fail scenario — confirm Status='Fail'
Update-MgPolicyAuthorizationPolicy -DefaultUserRolePermissions @{ allowedToCreateApps = $true }
pwsh ./Checks/EAPC-001.ps1
```

Restore the tenant's intended setting before leaving.

### EAPC-014 (app registrations)

Create the following app registrations. Capture each one's `AppId` for verification. All names use the prefix `eap-test-014-` so they're easy to find and delete.

| App | Web | Spa | PublicClient | Expected status |
|---|---|---|---|---|
| `eap-test-014-pass-https` | `https://example.com/cb` | — | — | Pass |
| `eap-test-014-pass-localhost` | `http://localhost:8080/cb` | — | — | Pass |
| `eap-test-014-pass-customscheme` | — | — | `ms-appx://contoso.example.com` | Pass |
| `eap-test-014-na` | (none) | (none) | (none) | NA |
| `eap-test-014-fail-http` | `http://example.com/cb` | — | — | Fail (1 offender) |
| `eap-test-014-fail-loopback-ip` | `http://127.0.0.1/cb` | — | — | Fail (1 offender) |
| `eap-test-014-fail-suffix-trick` | `http://localhost.evil.com/cb` | — | — | Fail (1 offender) |
| `eap-test-014-fail-mixed` | `https://safe.example.com`, `http://bad.example.com` | — | — | Fail (1 offender, RedirectUriCount=2) |
| `eap-test-014-fail-cross-bucket` | `https://safe.example.com` | `http://bad-spa.example.com` | `http://bad-pc.example.com` | Fail (2 offenders, RedirectUriCount=3) |

Several of these (custom schemes, loopback IPs, suffix tricks) cannot be added through the Azure portal UI — it validates client-side. Provision via Microsoft Graph directly. Run this once against your test tenant:

```pwsh
# Requires Application.ReadWrite.All (broader than the read-only scope EAPC-014 itself uses).
Connect-MgGraph -Scopes Application.ReadWrite.All -NoWelcome

$testApps = @(
    @{ Name = 'eap-test-014-pass-https'
       Web = @{ RedirectUris = @('https://example.com/cb') } }

    @{ Name = 'eap-test-014-pass-localhost'
       Web = @{ RedirectUris = @('http://localhost:8080/cb') } }

    @{ Name         = 'eap-test-014-pass-customscheme'
       PublicClient = @{ RedirectUris = @('ms-appx://contoso.example.com') } }

    @{ Name = 'eap-test-014-na' }   # no buckets at all

    @{ Name = 'eap-test-014-fail-http'
       Web = @{ RedirectUris = @('http://example.com/cb') } }

    @{ Name = 'eap-test-014-fail-loopback-ip'
       Web = @{ RedirectUris = @('http://127.0.0.1/cb') } }

    @{ Name = 'eap-test-014-fail-suffix-trick'
       Web = @{ RedirectUris = @('http://localhost.evil.com/cb') } }

    @{ Name = 'eap-test-014-fail-mixed'
       Web = @{ RedirectUris = @('https://safe.example.com', 'http://bad.example.com') } }

    @{ Name         = 'eap-test-014-fail-cross-bucket'
       Web          = @{ RedirectUris = @('https://safe.example.com') }
       Spa          = @{ RedirectUris = @('http://bad-spa.example.com') }
       PublicClient = @{ RedirectUris = @('http://bad-pc.example.com') } }
)

foreach ($app in $testApps) {
    if (Get-MgApplication -Filter "displayName eq '$($app.Name)'" -Top 1 -ErrorAction SilentlyContinue) {
        Write-Host "skip   $($app.Name) (already exists)"
        continue
    }

    $params = @{ DisplayName = $app.Name }
    foreach ($bucket in 'Web', 'Spa', 'PublicClient') {
        if ($app.ContainsKey($bucket)) { $params[$bucket] = $app[$bucket] }
    }

    $created = New-MgApplication @params
    Write-Host "create $($app.Name) → AppId $($created.AppId)"
}
```

Re-running the script is safe — the `displayName eq` filter skips entries already in the tenant. The script uses `Application.ReadWrite.All` (broader than EAPC-014's read-only scope), so you may want to disconnect afterwards: `Disconnect-MgGraph` then reconnect with the read-only set when you run the check.

The cases the portal blocks but Graph allows (custom schemes, loopback IPs, suffix smuggling) are exactly the patterns an attacker would use — seeding via Graph is the realistic exercise.

### Verification commands

```pwsh
# Spot-check by app
pwsh ./Run-EntraAppPosture.ps1 -CheckId EAPC-014 |
    Where-Object ObjectName -Like 'eap-test-014-*' |
    Select-Object ObjectName, Status, @{n='Offenders';e={$_.Evidence.OffendingUris.Uri -join ', '}} |
    Format-Table -AutoSize

# Round-trip JSON check
pwsh ./Run-EntraAppPosture.ps1 -CheckId EAPC-014 |
    Where-Object ObjectName -Like 'eap-test-014-*' |
    ConvertTo-Json -Depth 5

# Single-check execution (no orchestrator)
pwsh ./Checks/EAPC-014.ps1 |
    Where-Object ObjectName -Like 'eap-test-014-*' |
    Format-Table -AutoSize
```

Compare each row against the expected column in the seeding table. Anything that doesn't match is either a bug in the check or a seed misconfiguration — investigate before continuing.

### Cleanup

```pwsh
# Requires Application.ReadWrite.All; client-side Where-Object avoids the
# eventual-consistency header that Graph's startsWith filter would require.
Get-MgApplication -All |
    Where-Object DisplayName -Like 'eap-test-014-*' |
    ForEach-Object { Remove-MgApplication -ApplicationId $_.Id -Confirm }
```

## Recommended sequence

1. ~~Land the EAPC-001 and EAPC-014 hardening (cases 3–8, 11, 36, 41) in a single change.~~ **Shipped** (cases 3–8 and 11 for EAPC-001; case 36 for EAPC-014).
2. ~~Add the corresponding Pester tests.~~ **Shipped** — suite is now 30 tests.
3. Seed the test tenant per the table above.
4. Run live verification; reconcile any mismatches.
5. Update [`docs/controls.md`](../docs/controls.md) to flip EAPC-001 and EAPC-014 from `Planned` to `Implemented`.
6. Tear down the seeded apps.

Steps 3–6 are the remaining work for marking these checks `Implemented` per the project bar (`CLAUDE.md`: "verified against a real tenant").
