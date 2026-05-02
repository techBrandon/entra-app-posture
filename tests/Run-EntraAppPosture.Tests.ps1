#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Applications

BeforeAll {
    $script:RunnerPath = Resolve-Path "$PSScriptRoot/../Run-EntraAppPosture.ps1"
}

Describe 'Run-EntraAppPosture' {

    BeforeEach {
        # Reset the helper cache between tests.
        $global:EapCache = @{}
        Mock Connect-MgGraph {}
        Mock Get-MgContext {
            [PSCustomObject]@{
                TenantId = 'tenant-1'
                Scopes   = @('Policy.Read.All', 'Application.Read.All')
            }
        }
        Mock Get-MgPolicyAuthorizationPolicy {
            [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $false } }
        }
        Mock Get-MgApplication {
            [PSCustomObject]@{
                AppId        = 'app-x'
                DisplayName  = 'app-x'
                Web          = [PSCustomObject]@{ RedirectUris = @('https://ok.example.com') }
                Spa          = $null
                PublicClient = $null
            }
        }
    }

    Context 'filtering' {
        It 'with no filters runs every check' {
            $findings = @(& $script:RunnerPath)
            $findings                              | Should -HaveCount 2
            ($findings.CheckId | Sort-Object)       | Should -Be @('EAPC-001', 'EAPC-014')
        }

        It '-CheckId narrows to a single check' {
            $findings = @(& $script:RunnerPath -CheckId 'EAPC-014')
            $findings                              | Should -HaveCount 1
            $findings[0].CheckId                   | Should -Be 'EAPC-014'
        }

        It '-ControlId MSR-01 returns only EAPC-001' {
            $findings = @(& $script:RunnerPath -ControlId 'MSR-01')
            $findings                              | Should -HaveCount 1
            $findings[0].CheckId                   | Should -Be 'EAPC-001'
        }

        It '-ControlId MSR-04 returns only EAPC-014' {
            $findings = @(& $script:RunnerPath -ControlId 'MSR-04')
            $findings                              | Should -HaveCount 1
            $findings[0].CheckId                   | Should -Be 'EAPC-014'
        }

        It '-ExcludeCheckId removes the matching check' {
            $findings = @(& $script:RunnerPath -ExcludeCheckId 'EAPC-001')
            $findings.CheckId                      | Should -Not -Contain 'EAPC-001'
            $findings.CheckId                      | Should -Contain  'EAPC-014'
        }

        It 'filters that match nothing emit a warning and produce no findings' {
            $findings = @(& $script:RunnerPath -CheckId 'EAPC-999' -WarningAction SilentlyContinue)
            $findings | Should -HaveCount 0
        }
    }

    Context 'authentication' {
        It 'skips Connect-MgGraph when context already has the required scopes' {
            $null = & $script:RunnerPath
            Should -Invoke Connect-MgGraph -Times 0 -Exactly
        }

        It 'calls Connect-MgGraph when scopes are missing' {
            # Mocked context never updates after Connect, so both the runner and
            # the inner check observe empty scopes and each call Connect once.
            # The behaviour we care about is "at least once" — both layers
            # honouring their idempotency contract is fine.
            Mock Get-MgContext { [PSCustomObject]@{ TenantId = 'tenant-1'; Scopes = @() } }
            $null = & $script:RunnerPath -CheckId 'EAPC-001'
            Should -Invoke Connect-MgGraph -Times 1
        }
    }

    Context '-RefreshData' {
        It 'clears the cache before any check runs' {
            # Stale cache that would yield Fail for EAPC-001 if reused.
            $global:EapCache.AuthorizationPolicy = [PSCustomObject]@{
                DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $true }
            }
            # Fresh response yields Pass.
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $false } }
            }

            $findings = @(& $script:RunnerPath -CheckId 'EAPC-001' -RefreshData)
            ($findings | Where-Object CheckId -EQ 'EAPC-001').Status | Should -Be 'Pass'
            Should -Invoke Get-MgPolicyAuthorizationPolicy -Times 1 -Exactly
        }
    }
}
