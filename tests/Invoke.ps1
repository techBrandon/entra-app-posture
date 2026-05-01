#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Runs the entra-app-posture Pester suite with a project-local TestDrive.

.DESCRIPTION
    Pester's TestDrive creates per-test temp directories. On Windows/Linux
    Pester uses [System.IO.Path]::GetTempPath() (which respects $env:TMPDIR);
    on macOS Pester hardcodes /private/tmp and ignores the env var. Some
    sandboxes (including Claude Code's default) deny writes there.

    This invoker redirects Pester to a project-local, gitignored directory:
      - Sets $env:TMPDIR for the .NET / non-macOS code path.
      - On macOS, also overrides Pester's internal Get-TempDirectory.

    Both changes are scoped to this PowerShell process; they do not affect
    other shells, sessions, or applications.
#>

[CmdletBinding()]
param(
    [string] $Path = "$PSScriptRoot",
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string] $Verbosity = 'Detailed'
)

$ErrorActionPreference = 'Stop'

$testDrive = Join-Path $PSScriptRoot '.testdrive'
if (-not (Test-Path $testDrive)) {
    New-Item -ItemType Directory -Path $testDrive | Out-Null
}
$env:TMPDIR = $testDrive

if ($IsMacOS) {
    & (Get-Module Pester) {
        param($Path)
        function script:Get-TempDirectory { $Path }
    } $testDrive
}

$config = New-PesterConfiguration
$config.Run.Path = $Path
$config.Output.Verbosity = $Verbosity

Invoke-Pester -Configuration $config
