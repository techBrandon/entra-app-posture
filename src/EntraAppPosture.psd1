@{
    RootModule        = 'EntraAppPosture.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '5a69370f-a625-449b-9e4d-f16b2a671b3b'
    Author            = 'Brandon Colley'
    CompanyName       = 'TrustedSec'
    Copyright         = '(c) Brandon Colley. All rights reserved.'
    Description       = 'Read-only posture checks for Microsoft Entra Enterprise Applications, app registrations, service principals, consent settings, and workload identities. Maps to Microsoft Zero Trust — Protect engineering systems guidance.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @('Invoke-EntraAppPosture')
    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()

    RequiredModules   = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication';   ModuleVersion = '2.28.0' }
        @{ ModuleName = 'Microsoft.Graph.Identity.SignIns'; ModuleVersion = '2.28.0' }
        @{ ModuleName = 'Microsoft.Graph.Applications';     ModuleVersion = '2.28.0' }
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('Entra', 'EntraID', 'Azure', 'Security', 'Posture', 'ZeroTrust', 'Graph')
            ProjectUri   = 'https://github.com/techBrandon/entra-app-posture'
            LicenseUri   = 'https://github.com/techBrandon/entra-app-posture/blob/main/LICENSE'
            ReleaseNotes = 'Initial scaffolding. Slice 1: EAPC-001 (MSR-01) and EAPC-014 (MSR-04).'
        }
    }
}
