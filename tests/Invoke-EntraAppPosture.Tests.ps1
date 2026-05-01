#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    Import-Module "$PSScriptRoot/../src/EntraAppPosture.psd1" -Force
}

Describe 'Invoke-EntraAppPosture filters' {

    BeforeEach {
        InModuleScope EntraAppPosture {
            Mock Connect-EapGraph {}
            Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'test-tenant' } }
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{
                    DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $false }
                }
            }
            Mock Get-MgApplication {
                [PSCustomObject]@{
                    AppId        = 'app-x'
                    DisplayName  = 'app-x'
                    Web          = [PSCustomObject]@{ RedirectUris = @('https://example.com') }
                    Spa          = $null
                    PublicClient = $null
                }
            }
        }
    }

    It '-ControlId MSR-01 returns only EAPC-001' {
        InModuleScope EntraAppPosture {
            $findings = @(Invoke-EntraAppPosture -ControlId 'MSR-01')
            $findings              | Should -HaveCount 1
            $findings[0].CheckId   | Should -Be 'EAPC-001'
        }
    }

    It '-ControlId MSR-04 returns only EAPC-014' {
        InModuleScope EntraAppPosture {
            $findings = @(Invoke-EntraAppPosture -ControlId 'MSR-04')
            $findings              | Should -HaveCount 1
            $findings[0].CheckId   | Should -Be 'EAPC-014'
        }
    }

    It '-CheckId narrows to a single check' {
        InModuleScope EntraAppPosture {
            $findings = @(Invoke-EntraAppPosture -CheckId 'EAPC-014')
            $findings              | Should -HaveCount 1
            $findings[0].CheckId   | Should -Be 'EAPC-014'
        }
    }

    It '-ExcludeCheckId removes the matching check' {
        InModuleScope EntraAppPosture {
            $findings = @(Invoke-EntraAppPosture -ExcludeCheckId 'EAPC-001')
            $findings.CheckId      | Should -Not -Contain 'EAPC-001'
        }
    }

    It 'no filters returns one finding per registered check' {
        InModuleScope EntraAppPosture {
            $registered = @(Get-EapCheckRegistry).Count
            $findings   = @(Invoke-EntraAppPosture)
            $findings   | Should -HaveCount $registered
        }
    }

    It 'emits an Error finding when a check throws' {
        InModuleScope EntraAppPosture {
            Mock Get-MgPolicyAuthorizationPolicy { throw 'simulated graph failure' }
            $findings = @(Invoke-EntraAppPosture -CheckId 'EAPC-001')
            $findings              | Should -HaveCount 1
            $findings[0].Status    | Should -Be 'Error'
            $findings[0].Evidence.Message | Should -Match 'simulated graph failure'
        }
    }
}
