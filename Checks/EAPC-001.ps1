#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns

<#
.SYNOPSIS
    EAPC-001 — Users cannot register applications. Maps to MSR-01.

.DESCRIPTION
    Reads the tenant authorization policy and reports whether the default
    user role can create application registrations. The secure state is
    AllowedToCreateApps = $false (Pass).

    Source guidance: Microsoft Entra — Zero Trust — Protect engineering
    systems. Graph: policies/authorizationPolicy.

.OUTPUTS
    [PSCustomObject] One finding, ObjectType = 'Tenant'.

.EXAMPLE
    pwsh ./Checks/EAPC-001.ps1
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
    $policy   = Get-EapAuthorizationPolicy
    $tenantId = (Get-MgContext).TenantId
    $allowed  = $policy.DefaultUserRolePermissions.AllowedToCreateApps

    # Defensive: bad data should produce Status='Error', not a wrong Pass/Fail.
    # PowerShell truthiness would coerce $null/0/'true' into bogus answers.
    if ($allowed -isnot [bool]) {
        $type = if ($null -eq $allowed) { '<null>' } else { $allowed.GetType().FullName }
        throw "AllowedToCreateApps was not Boolean (got '$allowed' of type $type)."
    }

    $status = if ($allowed) { 'Fail' } else { 'Pass' }
    New-EapFinding `
        -CheckId    'EAPC-001' `
        -ControlIds @('MSR-01') `
        -ObjectType 'Tenant' `
        -ObjectId   $tenantId `
        -ObjectName $tenantId `
        -Status     $status `
        -Evidence   @{ AllowedToCreateApps = $allowed }
}
catch {
    $tenantId = (Get-MgContext)?.TenantId ?? 'unknown'
    New-EapFinding `
        -CheckId    'EAPC-001' `
        -ControlIds @('MSR-01') `
        -ObjectType 'Tenant' `
        -ObjectId   $tenantId `
        -ObjectName $tenantId `
        -Status     'Error' `
        -Evidence   @{ Message = $_.Exception.Message; Type = $_.Exception.GetType().FullName }
}
