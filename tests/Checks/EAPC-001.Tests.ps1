#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    Import-Module "$PSScriptRoot/../../src/EntraAppPosture.psd1" -Force
}

Describe 'EAPC-001 — Users cannot register applications' {

    It 'is registered against MSR-01 with the expected scopes' {
        InModuleScope EntraAppPosture {
            $check = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-001'
            $check                | Should -Not -BeNullOrEmpty
            $check.ControlIds     | Should -Be @('MSR-01')
            $check.RequiredScopes | Should -Be @('Policy.Read.All')
        }
    }

    It 'returns Pass when allowedToCreateApps is false' {
        InModuleScope EntraAppPosture {
            Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'tenant-1' } }
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{
                    DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $false }
                }
            }

            $check   = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-001'
            $finding = & $check.ScriptBlock $check

            $finding.Status                       | Should -Be 'Pass'
            $finding.ObjectType                   | Should -Be 'Tenant'
            $finding.ObjectId                     | Should -Be 'tenant-1'
            $finding.Evidence.AllowedToCreateApps | Should -Be $false
        }
    }

    It 'returns Fail when allowedToCreateApps is true' {
        InModuleScope EntraAppPosture {
            Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'tenant-2' } }
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{
                    DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $true }
                }
            }

            $check   = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-001'
            $finding = & $check.ScriptBlock $check

            $finding.Status                       | Should -Be 'Fail'
            $finding.Evidence.AllowedToCreateApps | Should -Be $true
        }
    }
}
