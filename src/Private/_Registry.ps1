Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:EapCheckRegistry = [ordered]@{}

function Register-EapCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [hashtable] $Metadata,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    foreach ($key in 'Id', 'ControlIds', 'Title', 'RequiredScopes') {
        if (-not $Metadata.ContainsKey($key)) {
            throw "Register-EapCheck: metadata is missing required key '$key'."
        }
    }

    $id = [string] $Metadata.Id
    if ($id -notmatch '^EAPC-\d{3}$') {
        throw "Register-EapCheck: Id '$id' does not match EAPC-NNN."
    }
    if ($script:EapCheckRegistry.Contains($id)) {
        throw "Register-EapCheck: duplicate Id '$id'."
    }

    $controlIds = @($Metadata.ControlIds)
    if ($controlIds.Count -eq 0) {
        throw "Register-EapCheck ($id): ControlIds must list at least one MSR-NN."
    }
    foreach ($controlId in $controlIds) {
        if ([string] $controlId -notmatch '^MSR-\d{2}$') {
            throw "Register-EapCheck ($id): ControlId '$controlId' does not match MSR-NN."
        }
    }

    $requiredScopes = @($Metadata.RequiredScopes)
    if ($requiredScopes.Count -eq 0) {
        throw "Register-EapCheck ($id): RequiredScopes must list at least one Graph scope."
    }

    $online = $false
    if ($Metadata.ContainsKey('Online')) { $online = [bool] $Metadata.Online }

    $script:EapCheckRegistry[$id] = [PSCustomObject]@{
        Id             = $id
        ControlIds     = $controlIds
        Title          = [string] $Metadata.Title
        RequiredScopes = $requiredScopes
        Online         = $online
        ScriptBlock    = $ScriptBlock
    }
}

function Get-EapCheckRegistry {
    [CmdletBinding()]
    param()
    $script:EapCheckRegistry.Values
}
