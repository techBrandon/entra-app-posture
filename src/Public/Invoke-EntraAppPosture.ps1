Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-EntraAppPosture {
    <#
    .SYNOPSIS
        Run Entra app-posture checks against the connected tenant.

    .DESCRIPTION
        Executes registered checks (one or more EAPC-NNN) against Microsoft Entra,
        returning one finding per evaluated object. With no parameters, runs every
        registered check. Filters narrow the run by check id or contributing
        control. Output is PSCustomObject findings on the pipeline.

    .PARAMETER CheckId
        Run only these EAPC-NNN checks.

    .PARAMETER ControlId
        Run only checks contributing to these MSR-NN controls.

    .PARAMETER ExcludeCheckId
        Run all selected checks except these EAPC-NNN ids.

    .EXAMPLE
        Invoke-EntraAppPosture

    .EXAMPLE
        Invoke-EntraAppPosture -ControlId MSR-04
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string[]] $CheckId,
        [string[]] $ControlId,
        [string[]] $ExcludeCheckId
    )

    $registry = @(Get-EapCheckRegistry)
    if ($registry.Count -eq 0) {
        Write-Warning "Invoke-EntraAppPosture: no checks are registered."
        return
    }

    $selected = $registry
    if ($CheckId)        { $selected = $selected | Where-Object { $_.Id -in $CheckId } }
    if ($ControlId)      { $selected = $selected | Where-Object { @($_.ControlIds | Where-Object { $_ -in $ControlId }).Count -gt 0 } }
    if ($ExcludeCheckId) { $selected = $selected | Where-Object { $_.Id -notin $ExcludeCheckId } }
    $selected = @($selected)

    if ($selected.Count -eq 0) {
        Write-Warning "Invoke-EntraAppPosture: filters matched zero checks."
        return
    }

    $scopes = @($selected.RequiredScopes | Select-Object -Unique)
    Connect-EapGraph -Scopes $scopes

    foreach ($check in $selected) {
        Write-Verbose "Running $($check.Id) — $($check.Title)"
        try {
            & $check.ScriptBlock $check
        }
        catch {
            New-EapFinding `
                -CheckId $check.Id `
                -ControlIds $check.ControlIds `
                -ObjectType 'CheckExecution' `
                -ObjectId $check.Id `
                -Status 'Error' `
                -Evidence @{ Message = $_.Exception.Message; Type = $_.Exception.GetType().FullName }
        }
    }
}
