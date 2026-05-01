Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Connect-EapGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Scopes
    )

    $existing = Get-MgContext -ErrorAction SilentlyContinue
    if ($existing) {
        $current = @($existing.Scopes)
        $missing = $Scopes | Where-Object { $_ -notin $current }
        if (-not $missing) {
            Write-Verbose "Connect-EapGraph: existing context already has required scopes."
            return
        }
        Write-Verbose "Connect-EapGraph: reconnecting to add scopes: $($missing -join ', ')"
        $Scopes = @($current + $Scopes | Select-Object -Unique)
    }

    Connect-MgGraph -Scopes $Scopes -NoWelcome | Out-Null
}
