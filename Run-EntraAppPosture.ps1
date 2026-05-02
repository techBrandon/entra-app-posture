#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
    Run entra-app-posture checks against the connected tenant.

.DESCRIPTION
    Runs one or more EAPC-NNN check scripts from ./Checks. With no
    parameters, runs every check listed in the $AllChecks manifest below.
    Filters narrow the run by check id or contributing control.

    Each check is a standalone script in ./Checks/EAPC-NNN.ps1 that can
    also be run directly with `pwsh ./Checks/EAPC-NNN.ps1`. This script
    just orchestrates a set of them.

.PARAMETER CheckId
    Run only these EAPC-NNN checks.

.PARAMETER ControlId
    Run only checks contributing to these MSR-NN controls.

.PARAMETER ExcludeCheckId
    Run all selected checks except these EAPC-NNN ids.

.PARAMETER RefreshData
    Clear the per-session Graph cache before running. Use when iteratively
    testing tenant config changes from the same pwsh session — without this,
    the second run re-uses the first run's cached Graph response and reports
    a stale Pass/Fail.

.OUTPUTS
    [PSCustomObject] Findings on the pipeline.

.EXAMPLE
    pwsh ./Run-EntraAppPosture.ps1

.EXAMPLE
    pwsh ./Run-EntraAppPosture.ps1 -ControlId MSR-04

.EXAMPLE
    pwsh ./Run-EntraAppPosture.ps1 -RefreshData
#>

[CmdletBinding()]
param(
    [string[]] $CheckId,
    [string[]] $ControlId,
    [string[]] $ExcludeCheckId,
    [switch]   $RefreshData
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/Helpers.ps1"

if ($RefreshData) { $global:EapCache = @{} }

# The list of checks. Add a row when adding a new check.
$AllChecks = @(
    @{ Id = 'EAPC-001'; ControlIds = @('MSR-01'); Scopes = @('Policy.Read.All');      File = 'EAPC-001.ps1' }
    @{ Id = 'EAPC-014'; ControlIds = @('MSR-04'); Scopes = @('Application.Read.All'); File = 'EAPC-014.ps1' }
)

# Filter
$selected = $AllChecks
if ($CheckId)        { $selected = $selected | Where-Object { $_.Id -in $CheckId } }
if ($ControlId)      { $selected = $selected | Where-Object { @($_.ControlIds | Where-Object { $_ -in $ControlId }).Count -gt 0 } }
if ($ExcludeCheckId) { $selected = $selected | Where-Object { $_.Id -notin $ExcludeCheckId } }
$selected = @($selected)

if ($selected.Count -eq 0) {
    Write-Warning "No checks matched the filters."
    return
}

# Pre-connect once with the union of required scopes so the user signs in once.
# Connect-EapGraph no-ops if the current context already covers every scope.
$scopes = @($selected.Scopes | Select-Object -Unique)
Connect-EapGraph -Scopes $scopes

# Run each check. A check that throws produces one Status='Error' finding
# instead of breaking the run. (Each check also has its own internal
# error handling, so this catch is belt-and-suspenders.)
foreach ($check in $selected) {
    Write-Verbose "Running $($check.Id)"
    try {
        & "$PSScriptRoot/Checks/$($check.File)"
    }
    catch {
        New-EapFinding `
            -CheckId    $check.Id `
            -ControlIds $check.ControlIds `
            -ObjectType 'CheckExecution' `
            -ObjectId   $check.Id `
            -ObjectName $check.Id `
            -Status     'Error' `
            -Evidence   @{ Message = $_.Exception.Message; Type = $_.Exception.GetType().FullName }
    }
}
