#Requires -Version 7.0
#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
    Shared helpers for entra-app-posture checks. Dot-source from each check.

.DESCRIPTION
    Three groups of helpers:

    1. Connect-EapGraph — idempotent Connect-MgGraph wrapper. Skips reconnection
       when the current Graph context already has every requested scope.

    2. New-EapFinding — the single factory for posture-check findings. Validates
       the schema (Status, CheckId pattern) and stamps the timestamp. Schema
       changes happen here, not in 35 different check files.

    3. Cached Graph getters — Get-EapAuthorizationPolicy, Get-EapApplication.
       Each connects with its required scope, returns cached data on subsequent
       calls in the same session, or re-fetches with -Refresh. The cache lives
       in $global:EapCache and is cleared by exiting pwsh.

    Helpers are admitted to this file when (a) they are called by 2+ checks, or
    (b) they wrap an expensive Graph call that benefits from per-session
    caching. New cached getters land alongside their first consumer check.
#>

# Per-session cache, lazily initialised. Lives in the global scope so each
# check (running in a child scope when invoked via the orchestrator) can read
# and write the same hashtable.
if (-not $global:EapCache) {
    $global:EapCache = @{}
}

function Connect-EapGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Scopes
    )

    $ctx = Get-MgContext
    if ($ctx -and -not @($Scopes | Where-Object { $_ -notin $ctx.Scopes })) {
        # Every requested scope is already present.
        return
    }
    Connect-MgGraph -Scopes $Scopes -NoWelcome | Out-Null
}

function New-EapFinding {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^EAPC-\d{3}$')]
        [string] $CheckId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ControlIds,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ObjectType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ObjectId,

        [string] $ObjectName,

        [Parameter(Mandatory)]
        [ValidateSet('Pass', 'Fail', 'NA', 'Error')]
        [string] $Status,

        [hashtable] $Evidence = @{}
    )

    [PSCustomObject]@{
        CheckId    = $CheckId
        ControlIds = @($ControlIds)
        ObjectType = $ObjectType
        ObjectId   = $ObjectId
        ObjectName = $ObjectName
        Status     = $Status
        Evidence   = $Evidence
        Timestamp  = [datetime]::UtcNow
    }
}

function Get-EapAuthorizationPolicy {
    [CmdletBinding()]
    param([switch] $Refresh)

    Connect-EapGraph -Scopes 'Policy.Read.All'
    if ($Refresh -or -not $global:EapCache.ContainsKey('AuthorizationPolicy')) {
        $global:EapCache.AuthorizationPolicy = Get-MgPolicyAuthorizationPolicy
    }
    $global:EapCache.AuthorizationPolicy
}

function Get-EapApplication {
    [CmdletBinding()]
    param([switch] $Refresh)

    Connect-EapGraph -Scopes 'Application.Read.All'
    if ($Refresh -or -not $global:EapCache.ContainsKey('Applications')) {
        $global:EapCache.Applications = @(Get-MgApplication -All)
    }
    $global:EapCache.Applications
}
