#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns

BeforeAll {
    $script:CheckPath = Resolve-Path "$PSScriptRoot/../../Checks/EAPC-001.ps1"
}

Describe 'EAPC-001 — Users cannot register applications' {

    BeforeEach {
        # Reset the helper cache between tests so a previous test's mocked
        # response doesn't leak in via $global:EapCache.
        $global:EapCache = @{}
        Mock Connect-MgGraph {}
        Mock Get-MgContext {
            [PSCustomObject]@{ TenantId = 'tenant-1'; Scopes = @('Policy.Read.All') }
        }
    }

    Context 'happy path' {
        It 'returns Pass when AllowedToCreateApps is $false' {
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $false } }
            }
            $finding = & $script:CheckPath
            $finding.Status                       | Should -Be 'Pass'
            $finding.CheckId                      | Should -Be 'EAPC-001'
            $finding.ControlIds                   | Should -Be @('MSR-01')
            $finding.ObjectType                   | Should -Be 'Tenant'
            $finding.ObjectId                     | Should -Be 'tenant-1'
            $finding.Evidence.AllowedToCreateApps | Should -Be $false
        }

        It 'returns Fail when AllowedToCreateApps is $true' {
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $true } }
            }
            $finding = & $script:CheckPath
            $finding.Status                       | Should -Be 'Fail'
            $finding.Evidence.AllowedToCreateApps | Should -Be $true
        }
    }

    Context 'defensive shape — non-Boolean returns Status=Error' {
        It 'returns Error when AllowedToCreateApps is $null' {
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $null } }
            }
            $finding = & $script:CheckPath
            $finding.Status            | Should -Be 'Error'
            $finding.Evidence.Message  | Should -Match 'not Boolean'
        }

        It 'returns Error when AllowedToCreateApps is 0 (int)' {
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = 0 } }
            }
            $finding = & $script:CheckPath
            $finding.Status            | Should -Be 'Error'
            $finding.Evidence.Message  | Should -Match 'Int32'
        }

        It "returns Error when AllowedToCreateApps is 'true' (string)" {
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = 'true' } }
            }
            $finding = & $script:CheckPath
            $finding.Status            | Should -Be 'Error'
            $finding.Evidence.Message  | Should -Match 'String'
        }

        It "returns Error when AllowedToCreateApps is 'false' (string, false-negative trap)" {
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = 'false' } }
            }
            $finding = & $script:CheckPath
            $finding.Status | Should -Be 'Error'
        }
    }

    Context 'defensive shape — missing structure returns Status=Error' {
        It 'returns Error when DefaultUserRolePermissions is null' {
            Mock Get-MgPolicyAuthorizationPolicy { [PSCustomObject]@{ DefaultUserRolePermissions = $null } }
            $finding = & $script:CheckPath
            $finding.Status | Should -Be 'Error'
        }

        It 'returns Error when the policy itself is null' {
            Mock Get-MgPolicyAuthorizationPolicy { $null }
            $finding = & $script:CheckPath
            $finding.Status | Should -Be 'Error'
        }
    }

    Context '-RefreshData' {
        BeforeEach {
            # Stale cache that, if reused, would yield Fail.
            $global:EapCache.AuthorizationPolicy = [PSCustomObject]@{
                DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $true }
            }
            # Fresh response that, if fetched, yields Pass.
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $false } }
            }
        }

        It 'discards the cache and fetches fresh data when set' {
            $finding = & $script:CheckPath -RefreshData
            $finding.Status | Should -Be 'Pass'
            Should -Invoke Get-MgPolicyAuthorizationPolicy -Times 1 -Exactly
        }

        It 'reuses the stale cache without -RefreshData (sanity check)' {
            $finding = & $script:CheckPath
            $finding.Status | Should -Be 'Fail'
            Should -Invoke Get-MgPolicyAuthorizationPolicy -Times 0 -Exactly
        }
    }
}
