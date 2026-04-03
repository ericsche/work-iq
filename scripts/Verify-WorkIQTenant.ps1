Import-Module Microsoft.Graph.Applications
Import-Module Microsoft.Graph.Identity.SignIns
Connect-MgGraph -Scopes 'Application.Read.All' -NoWelcome

# Verify Work IQ Tools SP exists
Write-Host "`n--- Work IQ Tools SP ---" -ForegroundColor Cyan
$toolsSp = Get-MgServicePrincipal -Filter "appId eq 'ea9ffc3e-8a23-4a7d-836d-234d7c7565c1'"
if ($toolsSp) {
    Write-Host "Found: $($toolsSp.DisplayName) (Id: $($toolsSp.Id))" -ForegroundColor Green
} else {
    Write-Host "NOT FOUND" -ForegroundColor Red
}

# Verify Work IQ CLI SP exists
Write-Host "`n--- Work IQ CLI SP ---" -ForegroundColor Cyan
$cliSp = Get-MgServicePrincipal -Filter "appId eq 'ba081686-5d24-4bc6-a0d6-d034ecffed87'"
if ($cliSp) {
    Write-Host "Found: $($cliSp.DisplayName) (Id: $($cliSp.Id))" -ForegroundColor Green
} else {
    Write-Host "NOT FOUND" -ForegroundColor Red
}

# Verify permission grants
Write-Host "`n--- Permission Grants for CLI ---" -ForegroundColor Cyan
$grants = Get-MgOauth2PermissionGrant -Filter "clientId eq '$($cliSp.Id)'" | Select-Object -First 10
foreach ($g in $grants) {
    $resource = Get-MgServicePrincipal -ServicePrincipalId $g.ResourceId
    Write-Host "`nResource: $($resource.DisplayName)" -ForegroundColor Yellow
    Write-Host "Scopes: $($g.Scope)"
}

Write-Host "`n--- Done ---" -ForegroundColor Green
Disconnect-MgGraph
