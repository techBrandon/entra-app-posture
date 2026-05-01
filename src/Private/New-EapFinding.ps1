Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

        [Parameter()]
        [string] $ObjectName,

        [Parameter(Mandatory)]
        [ValidateSet('Pass', 'Fail', 'NA', 'Error')]
        [string] $Status,

        [Parameter()]
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
