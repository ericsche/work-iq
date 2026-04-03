#Requires -Modules Microsoft.Graph.Applications, Microsoft.Graph.Identity.SignIns

<#
.SYNOPSIS
  Provisions Work IQ MCP Server service principals and grants admin consent
  for the Work IQ CLI in your tenant.

.DESCRIPTION
  Resolves AADSTS650052 ("your organization lacks a service principal")
  by creating the missing service principals for the Work IQ MCP Server
  resources, then granting admin consent for the Work IQ CLI application.

.PARAMETER ConsentOnly
  Skip service principal creation if already provisioned.

.NOTES
  Requires one of: Global Admin, Cloud Application Admin, or Application Admin.
  See https://github.com/microsoft/work-iq/issues/80
#>

param(
    [switch]$ConsentOnly,
    [switch]$UseDeviceCode
)

$ErrorActionPreference = 'Stop'

# App IDs
$WorkIqCliAppId   = 'ba081686-5d24-4bc6-a0d6-d034ecffed87'

# Work IQ MCP Server resource AppIds
$McpServers = @(
    @{ Name = 'Work IQ Tools';              AppId = 'ea9ffc3e-8a23-4a7d-836d-234d7c7565c1' }
    @{ Name = 'mcp_MailTools';              AppId = '16b1878d-62c7-4009-aa25-68989d63bbad' }
    @{ Name = 'mcp_MeServer';              AppId = '147dc821-b413-44c0-8009-1a3098378012' }
    @{ Name = 'mcp_CalendarTools';          AppId = '910333d2-47e9-43ca-981f-6df2f4531ef4' }
    @{ Name = 'mcp_TeamsServer';            AppId = 'ce5029ee-c1d3-45c0-bdcc-efb5a4245687' }
    @{ Name = 'mcp_OneDriveRemoteServer';   AppId = 'b0b2a2bb-6361-4549-a00c-a018417eb8e2' }
    @{ Name = 'mcp_SharePointRemoteServer'; AppId = '292cff14-c0e8-4116-9e3b-99934ae05766' }
    @{ Name = 'mcp_AdminTools';             AppId = '2dbeefeb-6462-48a4-abe6-1c4989699319' }
    @{ Name = 'mcp_WordServer';             AppId = 'c2d0c2b6-8013-4346-9f8b-b81d3b754a29' }
    @{ Name = 'mcp_M365Copilot';            AppId = 'ab7c82de-7946-4454-ac28-70249d17c95e' }
)

# Connect with required scopes
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
$connectParams = @{ Scopes = 'Application.ReadWrite.All','DelegatedPermissionGrant.ReadWrite.All' }
if ($UseDeviceCode) { $connectParams['UseDeviceCode'] = $true }
Connect-MgGraph @connectParams

$context = Get-MgContext
Write-Host "Connected to tenant: $($context.TenantId)" -ForegroundColor Green

# --- Step 1: Provision MCP Server service principals ---
if (-not $ConsentOnly) {
    Write-Host "`nProvisioning MCP Server service principals..." -ForegroundColor Cyan
    foreach ($server in $McpServers) {
        $sp = Get-MgServicePrincipal -Filter "appId eq '$($server.AppId)'" -ErrorAction SilentlyContinue
        if ($sp) {
            Write-Host "  $($server.Name) already exists (Id: $($sp.Id))" -ForegroundColor Green
        } else {
            Write-Host "  Creating $($server.Name)..." -ForegroundColor Yellow
            $sp = New-MgServicePrincipal -AppId $server.AppId
            Write-Host "  Created $($server.Name) (Id: $($sp.Id))" -ForegroundColor Green
        }
    }
}

# --- Step 2: Verify Work IQ CLI service principal ---
Write-Host "`nChecking for Work IQ CLI service principal..." -ForegroundColor Cyan
$cliSp = Get-MgServicePrincipal -Filter "appId eq '$WorkIqCliAppId'" -ErrorAction SilentlyContinue

if (-not $cliSp) {
    Write-Host "Creating Work IQ CLI service principal..." -ForegroundColor Yellow
    $cliSp = New-MgServicePrincipal -AppId $WorkIqCliAppId
    Write-Host "Created successfully (Id: $($cliSp.Id))" -ForegroundColor Green
} else {
    Write-Host "Work IQ CLI service principal exists (Id: $($cliSp.Id))" -ForegroundColor Green
}

# --- Step 3: Grant admin consent for Graph permissions ---
Write-Host "`nGranting admin consent for Microsoft Graph permissions..." -ForegroundColor Cyan
$graphSp = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -Top 1

$graphScopes = 'Sites.Read.All Mail.Read People.Read.All OnlineMeetingTranscript.Read.All Chat.Read ChannelMessage.Read.All ExternalItem.Read.All'

# Check for existing grant
$existingGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$($cliSp.Id)' and resourceId eq '$($graphSp.Id)'" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($existingGrant) {
    Write-Host "Updating existing Graph permission grant..." -ForegroundColor Yellow
    Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $existingGrant.Id -Scope $graphScopes
} else {
    Write-Host "Creating Graph permission grant..." -ForegroundColor Yellow
    New-MgOauth2PermissionGrant -BodyParameter @{
        ClientId    = $cliSp.Id
        ConsentType = 'AllPrincipals'
        ResourceId  = $graphSp.Id
        Scope       = $graphScopes
    }
}
Write-Host "Graph permissions granted." -ForegroundColor Green

# --- Step 4: Grant admin consent for MCP Server permissions ---
foreach ($server in $McpServers) {
    Write-Host "`nGranting admin consent for $($server.Name) permissions..." -ForegroundColor Cyan
    $sp = Get-MgServicePrincipal -Filter "appId eq '$($server.AppId)'"

    $existingGrant = Get-MgOauth2PermissionGrant -Filter "clientId eq '$($cliSp.Id)' and resourceId eq '$($sp.Id)'" -ErrorAction SilentlyContinue | Select-Object -First 1

    # Get the delegated scopes defined on this resource
    $scopes = ($sp.Oauth2PermissionScopes | Select-Object -ExpandProperty Value) -join ' '

    if ($scopes) {
        if ($existingGrant) {
            Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $existingGrant.Id -Scope $scopes
        } else {
            New-MgOauth2PermissionGrant -BodyParameter @{
                ClientId    = $cliSp.Id
                ConsentType = 'AllPrincipals'
                ResourceId  = $sp.Id
                Scope       = $scopes
            }
        }
        Write-Host "  Granted: $scopes" -ForegroundColor Green
    } else {
        Write-Host "  No delegated scopes found - skipping." -ForegroundColor Yellow
    }
}

# --- Done ---
Write-Host "`nWork IQ tenant enablement complete!" -ForegroundColor Green
Write-Host "Users can now authenticate with the Work IQ CLI." -ForegroundColor Cyan

Disconnect-MgGraph
