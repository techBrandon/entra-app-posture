#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Applications

<#
.SYNOPSIS
    EAPC-014 — App registrations have no HTTP (non-localhost) redirect URIs.
    Maps to MSR-04.

.DESCRIPTION
    Iterates app registrations and flags any redirect URI that uses scheme
    'http' on a host other than literal 'localhost'. URIs that cannot be
    parsed as absolute URIs are also offenders. Apps with zero redirect
    URIs return 'NA'.

    Source: Microsoft Entra — Zero Trust — Protect engineering systems.
    Graph: applications.

.OUTPUTS
    [PSCustomObject] One finding per app registration; one finding per
    failed app evaluation; one whole-check Error finding if the listing
    itself fails.

.EXAMPLE
    pwsh ./Checks/EAPC-014.ps1
#>

[CmdletBinding()]
param(
    # Clear the per-session Graph cache before running. Use when re-running
    # the check after a tenant config change in the same pwsh session.
    [switch] $RefreshData
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/../Helpers.ps1"

if ($RefreshData) { $global:EapCache = @{} }

try {
    foreach ($app in Get-EapApplication) {
        try {
            # Collect redirect URIs from all three buckets (any may be null).
            $uris = @()
            foreach ($bucket in $app.Web, $app.Spa, $app.PublicClient) {
                if ($bucket -and $bucket.RedirectUris) {
                    $uris += @($bucket.RedirectUris)
                }
            }

            if ($uris.Count -eq 0) {
                New-EapFinding `
                    -CheckId    'EAPC-014' `
                    -ControlIds @('MSR-04') `
                    -ObjectType 'Application' `
                    -ObjectId   $app.AppId `
                    -ObjectName $app.DisplayName `
                    -Status     'NA' `
                    -Evidence   @{ Reason = 'No redirect URIs configured.' }
                continue
            }

            # An offender is a URI that fails to parse, or one with scheme=http
            # and host != literal 'localhost'.
            $offenders = foreach ($uri in $uris) {
                $parsed = $null
                if (-not [Uri]::TryCreate($uri, [UriKind]::Absolute, [ref] $parsed)) {
                    [PSCustomObject]@{ Uri = $uri; Reason = 'Could not parse as absolute URI.' }
                    continue
                }
                if ($parsed.Scheme -eq 'http' -and $parsed.Host.ToLowerInvariant() -ne 'localhost') {
                    [PSCustomObject]@{ Uri = $uri; Scheme = $parsed.Scheme; Host = $parsed.Host }
                }
            }
            $offenders = @($offenders)

            $evidence = @{ RedirectUriCount = $uris.Count }
            if ($offenders.Count -gt 0) { $evidence.OffendingUris = $offenders }

            $status = if ($offenders.Count -gt 0) { 'Fail' } else { 'Pass' }
            New-EapFinding `
                -CheckId    'EAPC-014' `
                -ControlIds @('MSR-04') `
                -ObjectType 'Application' `
                -ObjectId   $app.AppId `
                -ObjectName $app.DisplayName `
                -Status     $status `
                -Evidence   $evidence
        }
        catch {
            # One bad app does not abort the loop — emit a per-app Error.
            New-EapFinding `
                -CheckId    'EAPC-014' `
                -ControlIds @('MSR-04') `
                -ObjectType 'Application' `
                -ObjectId   ($app.AppId ?? $app.Id ?? 'unknown') `
                -ObjectName $app.DisplayName `
                -Status     'Error' `
                -Evidence   @{ Message = $_.Exception.Message; Type = $_.Exception.GetType().FullName }
        }
    }
}
catch {
    # Whole-check failure (auth, listing, etc.) — emit one Error finding.
    New-EapFinding `
        -CheckId    'EAPC-014' `
        -ControlIds @('MSR-04') `
        -ObjectType 'CheckExecution' `
        -ObjectId   'EAPC-014' `
        -ObjectName 'EAPC-014' `
        -Status     'Error' `
        -Evidence   @{ Message = $_.Exception.Message; Type = $_.Exception.GetType().FullName }
}
