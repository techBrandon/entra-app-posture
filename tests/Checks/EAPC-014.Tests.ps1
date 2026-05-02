#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Applications

BeforeAll {
    $script:CheckPath = Resolve-Path "$PSScriptRoot/../../Checks/EAPC-014.ps1"

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

    BeforeEach {
        # Reset the helper cache between tests so a previous test's mocked
        # response doesn't leak in via $global:EapCache.
        $global:EapCache = @{}
        Mock Connect-MgGraph {}
        Mock Get-MgContext {
            [PSCustomObject]@{ TenantId = 'tenant-1'; Scopes = @('Application.Read.All') }
        }
    }

    Context 'URI cases — single app, single bucket' {
        It 'fails on http://example.com' {
            Mock Get-MgApplication { New-FakeApp -AppId 'app-1' -WebUris @('http://example.com/cb') }
            $f = & $script:CheckPath
            $f.Status                              | Should -Be 'Fail'
            $f.ObjectId                            | Should -Be 'app-1'
            $f.Evidence.OffendingUris              | Should -HaveCount 1
            $f.Evidence.OffendingUris[0].Uri       | Should -Be 'http://example.com/cb'
        }

        It 'passes on https' {
            Mock Get-MgApplication { New-FakeApp -WebUris @('https://example.com/cb') }
            $f = & $script:CheckPath
            $f.Status | Should -Be 'Pass'
        }

        It 'passes on http://localhost' {
            Mock Get-MgApplication { New-FakeApp -WebUris @('http://localhost') }
            $f = & $script:CheckPath
            $f.Status | Should -Be 'Pass'
        }

        It 'passes on http://localhost:8080' {
            Mock Get-MgApplication { New-FakeApp -WebUris @('http://localhost:8080/cb') }
            $f = & $script:CheckPath
            $f.Status | Should -Be 'Pass'
        }

        It 'passes on http://LOCALHOST (case-insensitive)' {
            Mock Get-MgApplication { New-FakeApp -WebUris @('http://LOCALHOST/cb') }
            $f = & $script:CheckPath
            $f.Status | Should -Be 'Pass'
        }

        It 'fails on http://localhost.evil.com (suffix smuggling)' {
            Mock Get-MgApplication { New-FakeApp -WebUris @('http://localhost.evil.com/cb') }
            $f = & $script:CheckPath
            $f.Status                              | Should -Be 'Fail'
            $f.Evidence.OffendingUris[0].Host      | Should -Be 'localhost.evil.com'
        }

        It 'fails on http://127.0.0.1 (numeric loopback is not literal localhost)' {
            Mock Get-MgApplication { New-FakeApp -WebUris @('http://127.0.0.1/cb') }
            $f = & $script:CheckPath
            $f.Status | Should -Be 'Fail'
        }

        It 'fails on Http://example.com (mixed-case scheme)' {
            Mock Get-MgApplication { New-FakeApp -WebUris @('Http://example.com/cb') }
            $f = & $script:CheckPath
            $f.Status | Should -Be 'Fail'
        }

        It 'passes on custom scheme ms-appx://' {
            Mock Get-MgApplication { New-FakeApp -WebUris @('ms-appx://contoso.example.com') }
            $f = & $script:CheckPath
            $f.Status | Should -Be 'Pass'
        }

        It 'flags un-parseable strings as offenders' {
            Mock Get-MgApplication { New-FakeApp -WebUris @('not a url') }
            $f = & $script:CheckPath
            $f.Status                                | Should -Be 'Fail'
            $f.Evidence.OffendingUris[0].Reason      | Should -Match 'parse'
        }
    }

    Context 'bucket cases' {
        It 'returns NA when an app has no buckets at all' {
            Mock Get-MgApplication { New-FakeApp -AppId 'app-na' }
            $f = & $script:CheckPath
            $f.Status | Should -Be 'NA'
        }

        It 'evaluates URIs across web, spa, and publicClient' {
            Mock Get-MgApplication {
                New-FakeApp -AppId 'app-mix' `
                    -WebUris          @('https://ok.example.com')      `
                    -SpaUris          @('http://bad-spa.example.com')  `
                    -PublicClientUris @('http://bad-pc.example.com')
            }
            $f = & $script:CheckPath
            $f.Status                              | Should -Be 'Fail'
            $f.Evidence.RedirectUriCount           | Should -Be 3
            $f.Evidence.OffendingUris              | Should -HaveCount 2
        }
    }

    Context 'multi-app iteration' {
        It 'emits one finding per app' {
            Mock Get-MgApplication {
                @(
                    (New-FakeApp -AppId 'a1' -WebUris @('https://a1.example.com'))
                    (New-FakeApp -AppId 'a2' -WebUris @('http://a2.example.com'))
                    (New-FakeApp -AppId 'a3')
                )
            }
            $findings = @(& $script:CheckPath)
            $findings                              | Should -HaveCount 3
            ($findings | Where-Object ObjectId -EQ 'a1').Status | Should -Be 'Pass'
            ($findings | Where-Object ObjectId -EQ 'a2').Status | Should -Be 'Fail'
            ($findings | Where-Object ObjectId -EQ 'a3').Status | Should -Be 'NA'
        }
    }

    Context 'whole-check error path' {
        It "emits one CheckExecution Error when Get-MgApplication itself throws" {
            Mock Get-MgApplication { throw 'simulated graph failure' }
            $findings = @(& $script:CheckPath)
            $findings                              | Should -HaveCount 1
            $findings[0].Status                    | Should -Be 'Error'
            $findings[0].ObjectType                | Should -Be 'CheckExecution'
            $findings[0].Evidence.Message          | Should -Match 'simulated graph failure'
        }
    }

    Context '-RefreshData' {
        It 'discards the cache and fetches fresh apps when set' {
            # Stale cache: a single app that would be Pass (https only).
            $global:EapCache.Applications = @(
                New-FakeApp -AppId 'stale-app' -WebUris @('https://stale.example.com')
            )
            # Fresh response: a single app that would be Fail (http non-localhost).
            Mock Get-MgApplication { New-FakeApp -AppId 'fresh-app' -WebUris @('http://fresh.example.com') }

            $findings = @(& $script:CheckPath -RefreshData)
            $findings              | Should -HaveCount 1
            $findings[0].ObjectId  | Should -Be 'fresh-app'
            $findings[0].Status    | Should -Be 'Fail'
            Should -Invoke Get-MgApplication -Times 1 -Exactly
        }

        It 'reuses the stale cache without -RefreshData (sanity check)' {
            $global:EapCache.Applications = @(
                New-FakeApp -AppId 'stale-app' -WebUris @('https://stale.example.com')
            )
            Mock Get-MgApplication { New-FakeApp -AppId 'fresh-app' -WebUris @('http://fresh.example.com') }

            $findings = @(& $script:CheckPath)
            $findings[0].ObjectId  | Should -Be 'stale-app'
            $findings[0].Status    | Should -Be 'Pass'
            Should -Invoke Get-MgApplication -Times 0 -Exactly
        }
    }
}
