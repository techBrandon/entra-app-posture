Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Load order: Private/_*.ps1 first (registry, low-level helpers), then the rest
# of Private/, then Public/, then Checks/. Checks register themselves at load
# time via Register-EapCheck, which must exist before any check file runs.
$loadGroups = @(
    Get-ChildItem -Path "$PSScriptRoot/Private/_*.ps1" -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -Exclude '_*' -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
    Get-ChildItem -Path "$PSScriptRoot/Checks/*.ps1" -ErrorAction SilentlyContinue
)

foreach ($file in $loadGroups) { . $file.FullName }

Export-ModuleMember -Function 'Invoke-EntraAppPosture'
