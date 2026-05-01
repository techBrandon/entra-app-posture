Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Register-EapCheck @{
    Id             = 'EAPC-001'
    ControlIds     = @('MSR-01')
    Title          = 'Users cannot register applications'
    RequiredScopes = @('Policy.Read.All')
    Online         = $false
} -ScriptBlock {
    param([Parameter(Mandatory)] $Check)

    $tenantId = (Get-MgContext).TenantId
    $policy = Get-MgPolicyAuthorizationPolicy
    $allowed = $policy.DefaultUserRolePermissions.AllowedToCreateApps

    $status = if ($allowed) { 'Fail' } else { 'Pass' }

    New-EapFinding `
        -CheckId $Check.Id `
        -ControlIds $Check.ControlIds `
        -ObjectType 'Tenant' `
        -ObjectId $tenantId `
        -ObjectName $tenantId `
        -Status $status `
        -Evidence @{ AllowedToCreateApps = [bool] $allowed }
}
