#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Applications

BeforeAll {
    $script:HelpersPath = Resolve-Path "$PSScriptRoot/../Helpers.ps1"
    . $script:HelpersPath
}

Describe 'Helpers.ps1' {

    BeforeEach {
        # Reset cache between every test.
        $global:EapCache = @{}
        Mock Connect-MgGraph {}
    }

    Context 'Connect-EapGraph' {
        It 'calls Connect-MgGraph when no context exists' {
            Mock Get-MgContext { $null }
            Connect-EapGraph -Scopes 'Policy.Read.All'
            Should -Invoke Connect-MgGraph -Times 1 -Exactly
        }

        It 'calls Connect-MgGraph when a required scope is missing from the context' {
            Mock Get-MgContext { [PSCustomObject]@{ Scopes = @('Other.Scope') } }
            Connect-EapGraph -Scopes 'Policy.Read.All'
            Should -Invoke Connect-MgGraph -Times 1 -Exactly
        }

        It 'no-ops when context already has every required scope' {
            Mock Get-MgContext { [PSCustomObject]@{ Scopes = @('Policy.Read.All', 'Application.Read.All') } }
            Connect-EapGraph -Scopes 'Policy.Read.All'
            Should -Invoke Connect-MgGraph -Times 0 -Exactly
        }
    }

    Context 'New-EapFinding' {
        It 'returns a PSCustomObject with the full schema' {
            $f = New-EapFinding -CheckId 'EAPC-001' -ControlIds @('MSR-01') `
                -ObjectType 'Tenant' -ObjectId 'tenant-1' `
                -Status 'Pass' -Evidence @{ K = 'V' }

            $f                      | Should -BeOfType [PSCustomObject]
            $f.CheckId              | Should -Be 'EAPC-001'
            $f.ControlIds           | Should -Be @('MSR-01')
            $f.ObjectType           | Should -Be 'Tenant'
            $f.ObjectId             | Should -Be 'tenant-1'
            $f.Status               | Should -Be 'Pass'
            $f.Evidence.K           | Should -Be 'V'
            $f.Timestamp            | Should -BeOfType [datetime]
        }

        It 'rejects an invalid Status value' {
            { New-EapFinding -CheckId 'EAPC-001' -ControlIds @('MSR-01') `
                -ObjectType 'Tenant' -ObjectId 't' -Status 'Bogus' } | Should -Throw
        }

        It 'rejects a CheckId that does not match EAPC-NNN' {
            { New-EapFinding -CheckId 'not-a-check' -ControlIds @('MSR-01') `
                -ObjectType 'Tenant' -ObjectId 't' -Status 'Pass' } | Should -Throw
        }

        It 'defaults Evidence to an empty hashtable' {
            $f = New-EapFinding -CheckId 'EAPC-001' -ControlIds @('MSR-01') `
                -ObjectType 'Tenant' -ObjectId 't' -Status 'Pass'
            $f.Evidence | Should -BeOfType [hashtable]
            $f.Evidence.Count | Should -Be 0
        }
    }

    Context 'Get-EapAuthorizationPolicy caching' {
        BeforeEach {
            Mock Get-MgContext { [PSCustomObject]@{ Scopes = @('Policy.Read.All') } }
            Mock Get-MgPolicyAuthorizationPolicy {
                [PSCustomObject]@{ DefaultUserRolePermissions = [PSCustomObject]@{ AllowedToCreateApps = $false } }
            }
        }

        It 'fetches once on first call' {
            $null = Get-EapAuthorizationPolicy
            Should -Invoke Get-MgPolicyAuthorizationPolicy -Times 1 -Exactly
        }

        It 'returns cached value on subsequent calls without re-fetching' {
            $null = Get-EapAuthorizationPolicy
            $null = Get-EapAuthorizationPolicy
            $null = Get-EapAuthorizationPolicy
            Should -Invoke Get-MgPolicyAuthorizationPolicy -Times 1 -Exactly
        }

        It '-Refresh forces a re-fetch' {
            $null = Get-EapAuthorizationPolicy
            $null = Get-EapAuthorizationPolicy -Refresh
            Should -Invoke Get-MgPolicyAuthorizationPolicy -Times 2 -Exactly
        }
    }

    Context 'Get-EapApplication caching' {
        BeforeEach {
            Mock Get-MgContext { [PSCustomObject]@{ Scopes = @('Application.Read.All') } }
            Mock Get-MgApplication {
                [PSCustomObject]@{ AppId = 'app-1'; DisplayName = 'app-1' }
            }
        }

        It 'fetches once on first call' {
            $null = Get-EapApplication
            Should -Invoke Get-MgApplication -Times 1 -Exactly
        }

        It 'returns cached value on subsequent calls without re-fetching' {
            $null = Get-EapApplication
            $null = Get-EapApplication
            Should -Invoke Get-MgApplication -Times 1 -Exactly
        }

        It '-Refresh forces a re-fetch' {
            $null = Get-EapApplication
            $null = Get-EapApplication -Refresh
            Should -Invoke Get-MgApplication -Times 2 -Exactly
        }

        It 'caches an empty result (zero apps) without re-fetching' {
            Mock Get-MgApplication { @() }
            $null = Get-EapApplication
            $null = Get-EapApplication
            Should -Invoke Get-MgApplication -Times 1 -Exactly
        }
    }
}
