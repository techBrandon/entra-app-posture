#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    Import-Module "$PSScriptRoot/../../src/EntraAppPosture.psd1" -Force

    function New-FakeApp {
        param(
            [string]   $AppId        = (New-Guid).ToString(),
            [string]   $DisplayName  = 'fake-app',
            [string[]] $WebUris,
            [string[]] $SpaUris,
            [string[]] $PublicClientUris
        )
        [PSCustomObject]@{
            AppId        = $AppId
            DisplayName  = $DisplayName
            Web          = if ($null -ne $WebUris)          { [PSCustomObject]@{ RedirectUris = $WebUris }          } else { $null }
            Spa          = if ($null -ne $SpaUris)          { [PSCustomObject]@{ RedirectUris = $SpaUris }          } else { $null }
            PublicClient = if ($null -ne $PublicClientUris) { [PSCustomObject]@{ RedirectUris = $PublicClientUris } } else { $null }
        }
    }
}

Describe 'EAPC-014 — App registrations have no HTTP (non-localhost) redirect URIs' {

    It 'is registered against MSR-04 with the expected scopes' {
        InModuleScope EntraAppPosture {
            $check = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-014'
            $check                | Should -Not -BeNullOrEmpty
            $check.ControlIds     | Should -Be @('MSR-04')
            $check.RequiredScopes | Should -Be @('Application.Read.All')
        }
    }

    It 'fails when any web redirect URI uses HTTP non-localhost' {
        InModuleScope EntraAppPosture -Parameters @{ App = (New-FakeApp -AppId 'app-1' -WebUris @('http://example.com/cb')) } {
            param($App)
            Mock Get-MgApplication { $App }
            $check    = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-014'
            $findings = @(& $check.ScriptBlock $check)

            $findings.Count                       | Should -Be 1
            $findings[0].Status                   | Should -Be 'Fail'
            $findings[0].ObjectId                 | Should -Be 'app-1'
            $findings[0].Evidence.OffendingUris   | Should -HaveCount 1
            $findings[0].Evidence.OffendingUris[0].Uri | Should -Be 'http://example.com/cb'
        }
    }

    It 'passes when all redirect URIs are HTTPS' {
        InModuleScope EntraAppPosture -Parameters @{ App = (New-FakeApp -AppId 'app-2' -WebUris @('https://example.com/cb')) } {
            param($App)
            Mock Get-MgApplication { $App }
            $check    = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-014'
            $findings = @(& $check.ScriptBlock $check)

            $findings[0].Status | Should -Be 'Pass'
            $findings[0].Evidence.ContainsKey('OffendingUris') | Should -BeFalse
        }
    }

    It 'passes when http URIs are exactly host=localhost' {
        InModuleScope EntraAppPosture -Parameters @{ App = (New-FakeApp -AppId 'app-3' -WebUris @('http://localhost:8080/cb')) } {
            param($App)
            Mock Get-MgApplication { $App }
            $check    = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-014'
            $findings = @(& $check.ScriptBlock $check)

            $findings[0].Status | Should -Be 'Pass'
        }
    }

    It 'fails when host suffix mimics localhost (e.g., localhost.evil.com)' {
        InModuleScope EntraAppPosture -Parameters @{ App = (New-FakeApp -AppId 'app-4' -WebUris @('http://localhost.evil.com/cb')) } {
            param($App)
            Mock Get-MgApplication { $App }
            $check    = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-014'
            $findings = @(& $check.ScriptBlock $check)

            $findings[0].Status                       | Should -Be 'Fail'
            $findings[0].Evidence.OffendingUris[0].Host | Should -Be 'localhost.evil.com'
        }
    }

    It 'returns NA for an app with zero redirect URIs across all buckets' {
        InModuleScope EntraAppPosture -Parameters @{ App = (New-FakeApp -AppId 'app-5') } {
            param($App)
            Mock Get-MgApplication { $App }
            $check    = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-014'
            $findings = @(& $check.ScriptBlock $check)

            $findings[0].Status | Should -Be 'NA'
        }
    }

    It 'evaluates URIs across web, spa, and publicClient buckets' {
        $app = $null
        InModuleScope EntraAppPosture -Parameters @{
            App = (New-FakeApp -AppId 'app-6' `
                    -WebUris          @('https://ok.example.com')      `
                    -SpaUris          @('http://bad-spa.example.com')  `
                    -PublicClientUris @('http://bad-pc.example.com'))
        } {
            param($App)
            Mock Get-MgApplication { $App }
            $check    = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-014'
            $findings = @(& $check.ScriptBlock $check)

            $findings[0].Status                     | Should -Be 'Fail'
            $findings[0].Evidence.RedirectUriCount  | Should -Be 3
            $findings[0].Evidence.OffendingUris     | Should -HaveCount 2
        }
    }

    It 'flags un-parseable URIs as offenders' {
        InModuleScope EntraAppPosture -Parameters @{ App = (New-FakeApp -AppId 'app-7' -WebUris @('not a url')) } {
            param($App)
            Mock Get-MgApplication { $App }
            $check    = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-014'
            $findings = @(& $check.ScriptBlock $check)

            $findings[0].Status                          | Should -Be 'Fail'
            $findings[0].Evidence.OffendingUris[0].Reason | Should -Match 'parse'
        }
    }

    It 'emits one finding per app when iterating multiple apps' {
        InModuleScope EntraAppPosture -Parameters @{
            Apps = @(
                (New-FakeApp -AppId 'a1' -WebUris @('https://a1.example.com'))
                (New-FakeApp -AppId 'a2' -WebUris @('http://a2.example.com'))
                (New-FakeApp -AppId 'a3')
            )
        } {
            param($Apps)
            Mock Get-MgApplication { $Apps }
            $check    = Get-EapCheckRegistry | Where-Object Id -EQ 'EAPC-014'
            $findings = @(& $check.ScriptBlock $check)

            $findings                              | Should -HaveCount 3
            ($findings | Where-Object ObjectId -EQ 'a1').Status | Should -Be 'Pass'
            ($findings | Where-Object ObjectId -EQ 'a2').Status | Should -Be 'Fail'
            ($findings | Where-Object ObjectId -EQ 'a3').Status | Should -Be 'NA'
        }
    }
}
