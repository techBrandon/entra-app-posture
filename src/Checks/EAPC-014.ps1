Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Register-EapCheck @{
    Id             = 'EAPC-014'
    ControlIds     = @('MSR-04')
    Title          = 'App registrations have no HTTP (non-localhost) redirect URIs'
    RequiredScopes = @('Application.Read.All')
    Online         = $false
} -ScriptBlock {
    param([Parameter(Mandatory)] $Check)

    Get-MgApplication -All | ForEach-Object {
        $app = $_

        $uris = @()
        foreach ($bucket in $app.Web, $app.Spa, $app.PublicClient) {
            if ($bucket -and $bucket.RedirectUris) {
                $uris += @($bucket.RedirectUris)
            }
        }

        if ($uris.Count -eq 0) {
            New-EapFinding `
                -CheckId $Check.Id `
                -ControlIds $Check.ControlIds `
                -ObjectType 'Application' `
                -ObjectId $app.AppId `
                -ObjectName $app.DisplayName `
                -Status 'NA' `
                -Evidence @{ Reason = 'No redirect URIs configured.' }
            return
        }

        $offenders = foreach ($uri in $uris) {
            $parsed = $null
            if (-not [Uri]::TryCreate($uri, [UriKind]::Absolute, [ref] $parsed)) {
                [PSCustomObject]@{ Uri = $uri; Reason = 'Could not parse as absolute URI.' }
                continue
            }
            if ($parsed.Scheme -eq 'http' -and $parsed.Host.ToLowerInvariant() -ne 'localhost') {
                [PSCustomObject]@{ Uri = $uri; Scheme = $parsed.Scheme; Host = $parsed.Host }
            }
        }
        $offenders = @($offenders)

        $status = if ($offenders.Count -gt 0) { 'Fail' } else { 'Pass' }
        $evidence = @{ RedirectUriCount = $uris.Count }
        if ($offenders.Count -gt 0) { $evidence.OffendingUris = $offenders }

        New-EapFinding `
            -CheckId $Check.Id `
            -ControlIds $Check.ControlIds `
            -ObjectType 'Application' `
            -ObjectId $app.AppId `
            -ObjectName $app.DisplayName `
            -Status $status `
            -Evidence $evidence
    }
}
