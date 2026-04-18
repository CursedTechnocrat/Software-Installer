<#
.SYNOPSIS
    A.E.G.I.S. — Azure Environment & Governance Inspection System
    Azure subscription assessment and HTML report generator for PowerShell 5.1+

.DESCRIPTION
    Connects to Azure, enumerates all resources, and produces a styled HTML
    assessment report covering: services in use, SQL database hygiene, VM
    inventory and monitoring gaps, orphaned resources, tag coverage, Azure
    Advisor alerts, and prioritized remediation recommendations.

.USAGE
    PS C:\> .\aegis.ps1
    PS C:\> .\aegis.ps1 -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    PS C:\> .\aegis.ps1 -OutputPath "C:\Reports\azure.html" -NoOpen

.NOTES
    Version  : 1.0
    Requires : Az PowerShell module  (Install-Module Az -Scope CurrentUser)
               Az.Advisor is optional — Advisor alerts will be skipped if absent.

    Tools Available
    ─────────────────────────────────────────────────────────────────
    G.R.I.M.O.I.R.E.       — Technician Toolkit hub and central launcher
    R.U.N.E.P.R.E.S.S.     — Printer driver installation & configuration
    R.E.S.T.O.R.A.T.I.O.N. — Windows Update management
    C.O.N.J.U.R.E.         — Software deployment via winget / Chocolatey
    O.R.A.C.L.E.           — System diagnostics & HTML report generation
    C.O.V.E.N.A.N.T.       — Machine onboarding & Entra ID domain join
    P.H.A.N.T.O.M.         — Profile migration & data transfer
    C.I.P.H.E.R.           — BitLocker drive encryption management
    W.A.R.D.               — User account & local security audit
    A.R.C.H.I.V.E.         — Pre-reimaging profile backup
    S.I.G.I.L.             — Security baseline & policy enforcement
    S.P.E.C.T.E.R.         — Remote machine execution via WinRM
    L.E.Y.L.I.N.E.         — Network diagnostics & remediation
    F.O.R.G.E.             — Driver update detection & installation
    A.E.G.I.S.             — Azure environment & governance inspection

    Color Schema
    ─────────────────────────────────────────
    Cyan     Headers and section dividers
    Magenta  Progress indicators
    Green    Success / complete
    Yellow   Warnings / degraded
    Red      Critical errors
    Gray     Information and details
#>

param(
    [string]$SubscriptionId = '',
    [string]$OutputPath     = "$env:TEMP\azure-assessment-$(Get-Date -Format 'yyyyMMdd-HHmmss').html",
    [switch]$NoOpen
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ─────────────────────────────────────────────────────────────────────────────
# COLOR SCHEMA
# ─────────────────────────────────────────────────────────────────────────────

$C = @{
    Header   = 'Cyan'
    Success  = 'Green'
    Warning  = 'Yellow'
    Error    = 'Red'
    Info     = 'Gray'
    Progress = 'Magenta'
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("  " + ("─" * 62)) -ForegroundColor $C.Header
    Write-Host "  $Title" -ForegroundColor $C.Header
    Write-Host ("  " + ("─" * 62)) -ForegroundColor $C.Header
    Write-Host ""
}

function Write-Step  { param([string]$Msg) Write-Host ("  [*] {0}" -f $Msg) -ForegroundColor $C.Progress }
function Write-Ok    { param([string]$Msg) Write-Host ("  [+] {0}" -f $Msg) -ForegroundColor $C.Success  }
function Write-Warn  { param([string]$Msg) Write-Host ("  [!] {0}" -f $Msg) -ForegroundColor $C.Warning  }
function Write-Fail  { param([string]$Msg) Write-Host ("  [-] {0}" -f $Msg) -ForegroundColor $C.Error    }

function EscHtml([string]$s) {
    if (-not $s) { return '' }
    $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE CHECK
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Get-Module -ListAvailable -Name Az.Accounts -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Fail "Az PowerShell module not found."
    Write-Host "      Install it with: Install-Module Az -Scope CurrentUser -Force" -ForegroundColor $C.Info
    Write-Host ""
    exit 1
}

$hasAdvisor = [bool](Get-Module -ListAvailable -Name Az.Advisor -ErrorAction SilentlyContinue)

# ─────────────────────────────────────────────────────────────────────────────
# BANNER
# ─────────────────────────────────────────────────────────────────────────────

Clear-Host
Write-Host @"

   █████╗ ███████╗ ██████╗ ██╗███████╗
  ██╔══██╗██╔════╝██╔════╝ ██║██╔════╝
  ███████║█████╗  ██║  ███╗██║███████╗
  ██╔══██║██╔══╝  ██║   ██║██║╚════██║
  ██║  ██║███████╗╚██████╔╝██║███████║
  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝╚══════╝

"@ -ForegroundColor Cyan
Write-Host "  A.E.G.I.S. — Azure Environment & Governance Inspection System" -ForegroundColor Cyan
Write-Host "  Azure Subscription Assessment & Report Generator" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# AUTHENTICATION
# ─────────────────────────────────────────────────────────────────────────────

Write-Section "AUTHENTICATION"

$ctx = Get-AzContext -ErrorAction SilentlyContinue
if (-not $ctx) {
    Write-Step "No active Azure session — launching browser login..."
    try {
        Connect-AzAccount -ErrorAction Stop | Out-Null
        $ctx = Get-AzContext -ErrorAction Stop
    } catch {
        Write-Fail "Authentication failed: $_"
        exit 1
    }
}
Write-Ok "Signed in as: $($ctx.Account.Id)"

# Subscription selection
if ($SubscriptionId) {
    try {
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
    } catch {
        Write-Fail "Could not set subscription '$SubscriptionId': $_"
        exit 1
    }
} else {
    $subs = @(Get-AzSubscription -ErrorAction SilentlyContinue)
    if ($subs.Count -gt 1) {
        Write-Host ""
        Write-Host "  Available Subscriptions:" -ForegroundColor $C.Header
        for ($i = 0; $i -lt $subs.Count; $i++) {
            Write-Host ("  [{0}] {1}  ({2})" -f ($i + 1), $subs[$i].Name, $subs[$i].Id) -ForegroundColor $C.Info
        }
        Write-Host ""
        Write-Host -NoNewline "  Select subscription [1-$($subs.Count)]: " -ForegroundColor $C.Header
        $sel = [int](Read-Host).Trim() - 1
        if ($sel -ge 0 -and $sel -lt $subs.Count) {
            Set-AzContext -SubscriptionId $subs[$sel].Id -ErrorAction Stop | Out-Null
        }
    }
}

$ctx     = Get-AzContext
$subName = $ctx.Subscription.Name
$subId   = $ctx.Subscription.Id
Write-Ok "Subscription: $subName  ($subId)"
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# DATA COLLECTION
# ─────────────────────────────────────────────────────────────────────────────

Write-Section "COLLECTING RESOURCE DATA"

Write-Step "All resources (this may take a moment)..."
$allResources = @(Get-AzResource -ErrorAction SilentlyContinue)
Write-Ok "Found $($allResources.Count) resources"

Write-Step "Resource groups..."
$resourceGroups = @(Get-AzResourceGroup -ErrorAction SilentlyContinue)
Write-Ok "Found $($resourceGroups.Count) resource groups"

Write-Step "Virtual machines..."
$vms = @(Get-AzVM -Status -ErrorAction SilentlyContinue)
Write-Ok "Found $($vms.Count) VMs"

Write-Step "Web apps & function apps..."
$webApps = @(Get-AzWebApp -ErrorAction SilentlyContinue)
Write-Ok "Found $($webApps.Count) sites"

Write-Step "App service plans..."
$appServicePlans = @(Get-AzAppServicePlan -ErrorAction SilentlyContinue)
Write-Ok "Found $($appServicePlans.Count) app service plans"

Write-Step "SQL servers & databases..."
$sqlServers   = @(Get-AzSqlServer -ErrorAction SilentlyContinue)
$sqlDatabases = @{}
$totalDbCount = 0
foreach ($srv in $sqlServers) {
    $dbs = @(Get-AzSqlDatabase -ServerName $srv.ServerName `
                -ResourceGroupName $srv.ResourceGroupName `
                -ErrorAction SilentlyContinue |
             Where-Object { $_.DatabaseName -ne 'master' })
    $sqlDatabases[$srv.ServerName] = $dbs
    $totalDbCount += $dbs.Count
}
Write-Ok "Found $($sqlServers.Count) SQL servers, $totalDbCount databases"

Write-Step "Storage accounts..."
$storageAccounts = @(Get-AzStorageAccount -ErrorAction SilentlyContinue)
Write-Ok "Found $($storageAccounts.Count) storage accounts"

Write-Step "Recovery services vaults..."
$recoveryVaults = @(Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue)
Write-Ok "Found $($recoveryVaults.Count) vaults"

Write-Step "Managed disks..."
$allDisks      = @(Get-AzDisk -ErrorAction SilentlyContinue)
$orphanedDisks = @($allDisks | Where-Object { $_.DiskState -eq 'Unattached' })
Write-Ok "Found $($allDisks.Count) disks ($($orphanedDisks.Count) unattached)"

Write-Step "Public IP addresses..."
$publicIPs       = @(Get-AzPublicIpAddress -ErrorAction SilentlyContinue)
$unassociatedIPs = @($publicIPs | Where-Object { -not $_.IpConfiguration })
Write-Ok "Found $($publicIPs.Count) public IPs ($($unassociatedIPs.Count) unassociated)"

$advisorRecs = @()
if ($hasAdvisor) {
    Write-Step "Azure Advisor recommendations..."
    $advisorRecs = @(Get-AzAdvisorRecommendation -ErrorAction SilentlyContinue)
    Write-Ok "Found $($advisorRecs.Count) recommendations"
} else {
    Write-Warn "Az.Advisor not installed — skipping Advisor data.  Run: Install-Module Az.Advisor"
}

Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────

Write-Section "ANALYZING"

# Tag coverage
$taggedCount = ($allResources | Where-Object { $_.Tags -and $_.Tags.Count -gt 0 }).Count
$tagCoverage = if ($allResources.Count -gt 0) { [math]::Round($taggedCount / $allResources.Count * 100) } else { 0 }
$untaggedPct = 100 - $tagCoverage
Write-Step "Tag coverage: $tagCoverage% ($taggedCount / $($allResources.Count) tagged)"

# Advisor counts by impact
$highAdvisor = ($advisorRecs | Where-Object { $_.Impact -eq 'High'   }).Count
$medAdvisor  = ($advisorRecs | Where-Object { $_.Impact -eq 'Medium' }).Count
$lowAdvisor  = ($advisorRecs | Where-Object { $_.Impact -eq 'Low'    }).Count
Write-Step "Advisor alerts: $highAdvisor High, $medAdvisor Medium, $lowAdvisor Low"

# Ad-hoc / date-stamped databases
$adHocPattern = '\d{8}|\d{4}[-_]\d{2}[-_]\d{2}|backup|copy|_old|_temp|restore'
$adHocDbs = @()
foreach ($srv in $sqlServers) {
    $adHocDbs += @($sqlDatabases[$srv.ServerName] | Where-Object { $_.DatabaseName -imatch $adHocPattern })
}
Write-Step "Ad-hoc / date-stamped databases: $($adHocDbs.Count)"

# Regions
$regions = @($allResources | Select-Object -ExpandProperty Location -Unique | Where-Object { $_ } | Sort-Object)
Write-Step "Regions in use: $($regions -join ', ')"

# VMs without extensions (use allResources to avoid per-VM API calls)
$extResources = $allResources | Where-Object { $_.ResourceType -eq 'Microsoft.Compute/virtualMachines/extensions' }
$vmsWithExts  = $extResources | ForEach-Object { ($_.ResourceId -split '/')[8] } | Select-Object -Unique
$vmsWithoutMon = @($vms | Where-Object { $vmsWithExts -notcontains $_.Name } | Select-Object -ExpandProperty Name)
Write-Step "VMs without any extensions: $($vmsWithoutMon.Count)"

# Auto-named / timestamp app service plans
$suspectPlans = @($appServicePlans | Where-Object { $_.Name -match 'ASP-[A-Za-z0-9]+-[a-f0-9]{4,}$|Plan\d{12,}$|\d{14}' })
Write-Step "Auto-generated/timestamp plan names: $($suspectPlans.Count)"

Write-Ok "Analysis complete"
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# BUILD HTML SECTIONS
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Generating HTML report..."

# ── Services section ──────────────────────────────────────────────────────────

$serviceItems = [System.Text.StringBuilder]::new()

if ($vms.Count -gt 0) {
    $names = (($vms | Select-Object -ExpandProperty Name) | ForEach-Object { EscHtml $_ }) -join ', '
    [void]$serviceItems.Append("<div class='service-item'><div class='svc-name'>Virtual Machines ($($vms.Count))</div><div class='svc-type'>Microsoft.Compute/virtualMachines</div><div class='svc-note'>$names</div></div>`n")
}
if ($webApps.Count -gt 0) {
    $names = (($webApps | Select-Object -ExpandProperty Name) | ForEach-Object { EscHtml $_ }) -join ', '
    [void]$serviceItems.Append("<div class='service-item'><div class='svc-name'>App Service / Functions ($($webApps.Count) sites)</div><div class='svc-type'>Microsoft.Web/sites</div><div class='svc-note'>$names</div></div>`n")
}
if ($sqlServers.Count -gt 0) {
    $names = (($sqlServers | Select-Object -ExpandProperty ServerName) | ForEach-Object { EscHtml $_ }) -join ', '
    [void]$serviceItems.Append("<div class='service-item'><div class='svc-name'>Azure SQL ($($sqlServers.Count) servers, $totalDbCount databases)</div><div class='svc-type'>Microsoft.Sql/servers</div><div class='svc-note'>$names</div></div>`n")
}
if ($storageAccounts.Count -gt 0) {
    $names = (($storageAccounts | Select-Object -ExpandProperty StorageAccountName) | ForEach-Object { EscHtml $_ }) -join ', '
    [void]$serviceItems.Append("<div class='service-item'><div class='svc-name'>Storage Accounts ($($storageAccounts.Count))</div><div class='svc-type'>Microsoft.Storage/storageAccounts</div><div class='svc-note'>$names</div></div>`n")
}
if ($recoveryVaults.Count -gt 0) {
    $names = (($recoveryVaults | Select-Object -ExpandProperty Name) | ForEach-Object { EscHtml $_ }) -join ', '
    [void]$serviceItems.Append("<div class='service-item'><div class='svc-name'>Recovery Services Vaults ($($recoveryVaults.Count))</div><div class='svc-type'>Microsoft.RecoveryServices/vaults</div><div class='svc-note'>$names</div></div>`n")
}
if ($appServicePlans.Count -gt 0) {
    $names = (($appServicePlans | Select-Object -ExpandProperty Name) | ForEach-Object { EscHtml $_ }) -join ', '
    [void]$serviceItems.Append("<div class='service-item'><div class='svc-name'>App Service Plans ($($appServicePlans.Count))</div><div class='svc-type'>Microsoft.Web/serverfarms</div><div class='svc-note'>$names</div></div>`n")
}

$extraTypes = [ordered]@{
    'Microsoft.DataFactory/factories'                = 'Azure Data Factory'
    'Microsoft.Logic/workflows'                      = 'Logic Apps'
    'Microsoft.KeyVault/vaults'                      = 'Azure Key Vault'
    'Microsoft.Network/virtualNetworkGateways'       = 'VPN / ExpressRoute Gateways'
    'Microsoft.Network/bastionHosts'                 = 'Azure Bastion'
    'Microsoft.AppConfiguration/configurationStores' = 'App Configuration'
    'Microsoft.Web/staticSites'                      = 'Static Web Apps'
    'Microsoft.Network/privateEndpoints'             = 'Private Endpoints'
    'Microsoft.ContainerRegistry/registries'         = 'Container Registry'
    'Microsoft.ContainerService/managedClusters'     = 'AKS Clusters'
    'Microsoft.ApiManagement/service'                = 'API Management'
    'Microsoft.Cdn/profiles'                         = 'Azure CDN'
    'Microsoft.SaaS/resources'                       = 'SaaS Resources'
}
foreach ($type in $extraTypes.Keys) {
    $matched = @($allResources | Where-Object { $_.ResourceType -ieq $type })
    if ($matched.Count -gt 0) {
        $names = ($matched | ForEach-Object { EscHtml $_.Name }) -join ', '
        [void]$serviceItems.Append("<div class='service-item'><div class='svc-name'>$($extraTypes[$type]) ($($matched.Count))</div><div class='svc-type'>$type</div><div class='svc-note'>$names</div></div>`n")
    }
}

# ── VM table ─────────────────────────────────────────────────────────────────

$vmRows = [System.Text.StringBuilder]::new()
foreach ($vm in $vms) {
    $power   = if ($vm.PowerState) { EscHtml ($vm.PowerState -replace 'VM ','') } else { 'Unknown' }
    $size    = EscHtml $vm.HardwareProfile.VmSize
    $rg      = EscHtml $vm.ResourceGroupName
    $loc     = EscHtml $vm.Location
    $monPill = if ($vmsWithoutMon -contains $vm.Name) { "<span class='pill orphan'>None</span>" } else { "<span class='pill full'>Deployed</span>" }
    [void]$vmRows.Append("<tr><td><strong>$(EscHtml $vm.Name)</strong></td><td>$rg</td><td>$loc</td><td>$size</td><td>$power</td><td>$monPill</td></tr>`n")
}
$vmSection = ''
if ($vms.Count -gt 0) {
    $vmSection = @"
<div class="card">
  <div class="card-header">
    <div class="icon" style="background:#e1ecf7">🖥️</div>
    <h2>Virtual Machine Inventory</h2>
    <span class="section-num">Section 3</span>
  </div>
  <div class="card-body">
    <table class="status-table">
      <thead><tr><th>VM Name</th><th>Resource Group</th><th>Location</th><th>Size</th><th>Power State</th><th>Extensions</th></tr></thead>
      <tbody>$($vmRows.ToString())</tbody>
    </table>
  </div>
</div>
"@
}

# ── SQL database table ────────────────────────────────────────────────────────

$dbRows = [System.Text.StringBuilder]::new()
foreach ($srv in $sqlServers) {
    $dbs = $sqlDatabases[$srv.ServerName]
    if (-not $dbs) { continue }
    foreach ($db in ($dbs | Sort-Object DatabaseName)) {
        $isAdHoc = $db.DatabaseName -imatch $adHocPattern
        $pill    = if ($isAdHoc) { "<span class='pill partial'>Ad-hoc / Backup</span>" } else { "<span class='pill full'>Active</span>" }
        [void]$dbRows.Append("<tr><td>$(EscHtml $db.DatabaseName)</td><td>$(EscHtml $srv.ServerName)</td><td>$(EscHtml $db.SkuName)</td><td>$pill</td></tr>`n")
    }
}
$dbSection = ''
if ($totalDbCount -gt 0) {
    $dbSection = @"
<div class="card">
  <div class="card-header">
    <div class="icon" style="background:#fff4ce">🗄️</div>
    <h2>SQL Database Inventory</h2>
    <span class="section-num">Section 4</span>
  </div>
  <div class="card-body">
    <table class="status-table">
      <thead><tr><th>Database Name</th><th>Server</th><th>SKU / Tier</th><th>Classification</th></tr></thead>
      <tbody>$($dbRows.ToString())</tbody>
    </table>
  </div>
</div>
"@
}

# ── Advisor table ─────────────────────────────────────────────────────────────

$advisorSection = ''
if ($advisorRecs.Count -gt 0) {
    $advisorRows = [System.Text.StringBuilder]::new()
    foreach ($rec in ($advisorRecs | Sort-Object -Property @{E={switch($_.Impact){'High'{0}'Medium'{1}default{2}}}},Category | Select-Object -First 50)) {
        $impactClass = switch ($rec.Impact) { 'High' { 'orphan' } 'Medium' { 'partial' } default { 'full' } }
        $problem     = EscHtml ($rec.ShortDescription.Problem)
        $resName     = EscHtml (($rec.ResourceId -split '/')[-1])
        $cat         = EscHtml $rec.Category
        [void]$advisorRows.Append("<tr><td>$problem</td><td>$cat</td><td><span class='pill $impactClass'>$(EscHtml $rec.Impact)</span></td><td>$resName</td></tr>`n")
    }
    $advisorSection = @"
<div class="card">
  <div class="card-header">
    <div class="icon" style="background:#fde7e9">⚡</div>
    <h2>Azure Advisor Recommendations</h2>
    <span class="section-num">Section 5</span>
  </div>
  <div class="card-body">
    <table class="status-table">
      <thead><tr><th>Recommendation</th><th>Category</th><th>Impact</th><th>Resource</th></tr></thead>
      <tbody>$($advisorRows.ToString())</tbody>
    </table>
  </div>
</div>
"@
}

# ── Issues ────────────────────────────────────────────────────────────────────

$issues = [System.Collections.Generic.List[hashtable]]::new()

if ($highAdvisor -gt 0) {
    $issues.Add(@{ Sev='high'; Title="$highAdvisor Unresolved High-Impact Advisor Alerts"
        Body="Azure Advisor is flagging $highAdvisor High-severity and $medAdvisor Medium-severity issues based on live telemetry. These represent Microsoft's own assessment of availability, security, performance, and cost risk in this subscription." })
}
if ($untaggedPct -gt 50) {
    $issues.Add(@{ Sev='high'; Title="~$untaggedPct% of Resources Have No Tags ($taggedCount of $($allResources.Count) tagged)"
        Body="Without tags for Environment, Owner, Application, and CostCenter there is no ability to filter costs by workload, identify resource owners, or enforce lifecycle policies. This makes chargeback, audits, and incident response significantly harder." })
}
if ($adHocDbs.Count -gt 3) {
    $sample = (($adHocDbs | Select-Object -First 5 | Select-Object -ExpandProperty DatabaseName) | ForEach-Object { EscHtml $_ }) -join ', '
    $issues.Add(@{ Sev='high'; Title="$($adHocDbs.Count) Ad-Hoc / Date-Stamped Databases Detected"
        Body="Databases matching backup/copy/date patterns: $sample$(if($adHocDbs.Count -gt 5){', and more'}). Manual copies indicate no formal backup strategy — each incurs its own Azure cost and creates risk of accidentally modifying the wrong database." })
}
if ($vmsWithoutMon.Count -gt 0) {
    $vmList = ($vmsWithoutMon | ForEach-Object { EscHtml $_ }) -join ', '
    $issues.Add(@{ Sev='high'; Title="$($vmsWithoutMon.Count) VMs Have No Extensions Deployed"
        Body="The following VMs have no Azure VM extensions: $vmList. Without diagnostics agents or Log Analytics, there is no telemetry to diagnose performance issues or failures on these machines." })
}
if ($regions.Count -gt 2) {
    $regionList = ($regions | ForEach-Object { EscHtml $_ }) -join ', '
    $issues.Add(@{ Sev='med'; Title="Resources Spread Across $($regions.Count) Regions"
        Body="Resources detected in: $regionList. Cross-region communication adds latency and egress costs. Verify whether the multi-region spread is intentional (geo-redundancy) or the result of unplanned deployments." })
}
if ($appServicePlans.Count -gt 2) {
    $planList = (($appServicePlans | Select-Object -ExpandProperty Name) | ForEach-Object { EscHtml $_ }) -join ', '
    $issues.Add(@{ Sev='med'; Title="$($appServicePlans.Count) App Service Plans — Verify Active Use"
        Body="Plans found: $planList. Multiple plans may indicate trial-and-error deployments that were never cleaned up. Each plan incurs cost even when idle or lightly loaded." })
}
if ($recoveryVaults.Count -gt 1) {
    $vaultList = (($recoveryVaults | Select-Object -ExpandProperty Name) | ForEach-Object { EscHtml $_ }) -join ', '
    $issues.Add(@{ Sev='med'; Title="$($recoveryVaults.Count) Recovery Vaults — Ownership Unclear"
        Body="Multiple vaults exist: $vaultList. It is not clear which vault is actively protecting which resources. Duplicate vaults increase support complexity and make it harder to verify recoverability." })
}
if ($orphanedDisks.Count -gt 0) {
    $diskList = ($orphanedDisks | ForEach-Object { "$(EscHtml $_.Name) ($($_.DiskSizeGB) GB)" }) -join ', '
    $issues.Add(@{ Sev='low'; Title="$($orphanedDisks.Count) Unattached Managed Disk(s)"
        Body="The following disks are not attached to any VM and are being billed at idle: $diskList. Snapshot if needed, then delete." })
}
if ($unassociatedIPs.Count -gt 0) {
    $ipList = (($unassociatedIPs | Select-Object -ExpandProperty Name) | ForEach-Object { EscHtml $_ }) -join ', '
    $issues.Add(@{ Sev='low'; Title="$($unassociatedIPs.Count) Unassociated Public IP Address(es)"
        Body="Public IPs not assigned to any resource: $ipList. Static public IPs incur a charge when unassociated — delete if no longer needed." })
}
if ($issues.Count -eq 0) {
    $issues.Add(@{ Sev='low'; Title="No Major Issues Detected"
        Body="No significant governance or operational issues were automatically detected. Continue monitoring Azure Advisor and maintain tagging discipline." })
}

$issueHtml = [System.Text.StringBuilder]::new()
foreach ($issue in $issues) {
    $sevLabel = switch ($issue.Sev) { 'high' { 'High' } 'med' { 'Med' } default { 'Low' } }
    [void]$issueHtml.Append("<div class='issue'><div class='sev $($issue.Sev)'>$sevLabel</div><div class='body'><strong>$(EscHtml $issue.Title)</strong><p>$($issue.Body)</p></div></div>`n")
}

# ── Recommendations ───────────────────────────────────────────────────────────

$recs = [System.Collections.Generic.List[hashtable]]::new()

if ($untaggedPct -gt 20) {
    $recs.Add(@{ P='immediate'; L='Immediate'; Title='Implement a Tagging Policy'
        Body="Apply mandatory tags — at minimum <em>Environment</em>, <em>Application</em>, <em>Owner</em>, and <em>CostCenter</em> — to all resources. Use Azure Policy to enforce tags on new resources. Currently only $tagCoverage% of resources are tagged." })
}
if ($highAdvisor -gt 0) {
    $recs.Add(@{ P='immediate'; L='Immediate'; Title="Resolve $highAdvisor High-Impact Advisor Alerts"
        Body="Review the full Advisor recommendation list in the Azure Portal and work through High-severity items first. These represent Microsoft's direct assessment of risk in the live environment." })
}
if ($adHocDbs.Count -gt 3) {
    $recs.Add(@{ P='immediate'; L='Immediate'; Title='Replace Ad-Hoc Database Copies with Native Backups'
        Body="Audit the $($adHocDbs.Count) date-stamped databases, archive any still-needed data, and delete the rest. Use Azure SQL automated backups and point-in-time restore — this is safer and already included in the SQL service cost." })
}
if ($appServicePlans.Count -gt 2) {
    $recs.Add(@{ P='short'; L='Short-Term'; Title='Consolidate App Service Plans'
        Body="Determine which plan is hosting production workloads and migrate all apps onto one or two appropriately-sized plans. Remove plans with auto-generated or timestamp names. This reduces cost and simplifies scaling." })
}
if ($vmsWithoutMon.Count -gt 0) {
    $vmList = ($vmsWithoutMon | ForEach-Object { EscHtml $_ }) -join ', '
    $recs.Add(@{ P='short'; L='Short-Term'; Title='Deploy Monitoring Extensions to All VMs'
        Body="Deploy the Azure Monitor Agent to: $vmList. Configure basic CPU, disk, and memory alerts and connect to a central Log Analytics workspace." })
}
if ($orphanedDisks.Count -gt 0 -or $unassociatedIPs.Count -gt 0) {
    $recs.Add(@{ P='short'; L='Short-Term'; Title='Remove Orphaned Resources'
        Body="Delete $($orphanedDisks.Count) unattached managed disk(s) and $($unassociatedIPs.Count) unassociated public IP(s). These resources are incurring ongoing cost with no operational value." })
}
if ($recoveryVaults.Count -gt 1) {
    $vaultList = (($recoveryVaults | Select-Object -ExpandProperty Name) | ForEach-Object { EscHtml $_ }) -join ', '
    $recs.Add(@{ P='short'; L='Short-Term'; Title='Consolidate Backup Vaults'
        Body="Document which vault ($vaultList) is protecting which resources. Consolidate to a single vault where possible, and test at least one restore to confirm recoverability." })
}
if ($regions.Count -gt 2) {
    $regionList = ($regions | ForEach-Object { EscHtml $_ }) -join ', '
    $recs.Add(@{ P='medium'; L='Medium-Term'; Title='Evaluate Region Consolidation'
        Body="Resources currently span $($regions.Count) regions ($regionList). If the multi-region spread is not providing intentional geo-redundancy, consolidating to a primary region eliminates cross-region egress costs and simplifies network topology." })
}
$recs.Add(@{ P='long'; L='Long-Term'; Title='Formalize Dev / Test / Prod Environment Boundaries'
    Body='Establish separate resource groups or subscriptions with naming conventions and Azure Policy enforcement for each environment tier. This prevents test resources from being created in production groups and enables clean cost reporting per environment.' })

$recHtml = [System.Text.StringBuilder]::new()
foreach ($rec in $recs) {
    [void]$recHtml.Append("<div class='rec'><div class='priority $($rec.P)'>$(EscHtml $rec.L)</div><div class='body'><strong>$(EscHtml $rec.Title)</strong><p>$($rec.Body)</p></div></div>`n")
}

# ─────────────────────────────────────────────────────────────────────────────
# ASSEMBLE HTML
# ─────────────────────────────────────────────────────────────────────────────

$reportDate  = Get-Date -Format "MMMM d, yyyy"
$orgName     = EscHtml $subName
$subIdEsc    = EscHtml $subId
$regionList  = ($regions | ForEach-Object { EscHtml $_ }) -join ', '

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Azure Environment Assessment — $orgName</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Segoe UI', system-ui, sans-serif; background: #f0f2f5; color: #1a1a2e; line-height: 1.6; }
    header { background: linear-gradient(135deg, #0f3460 0%, #16213e 100%); color: #fff; padding: 48px 64px 40px; }
    header .label { font-size: 11px; letter-spacing: 3px; text-transform: uppercase; color: #6db8f7; margin-bottom: 10px; }
    header h1 { font-size: 32px; font-weight: 700; margin-bottom: 6px; }
    header .subtitle { font-size: 15px; color: #a8c4e0; }
    .meta { margin-top: 24px; display: flex; gap: 32px; font-size: 13px; color: #a8c4e0; flex-wrap: wrap; }
    .meta span strong { color: #fff; }
    main { max-width: 1100px; margin: 0 auto; padding: 48px 32px; display: flex; flex-direction: column; gap: 40px; }
    .card { background: #fff; border-radius: 10px; box-shadow: 0 2px 12px rgba(0,0,0,.07); overflow: hidden; }
    .card-header { display: flex; align-items: center; gap: 14px; padding: 20px 28px; border-bottom: 1px solid #e8edf3; }
    .card-header .icon { width: 36px; height: 36px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 18px; flex-shrink: 0; }
    .card-header h2 { font-size: 17px; font-weight: 700; color: #0f3460; }
    .card-header .section-num { margin-left: auto; font-size: 11px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; color: #9aa8bb; }
    .card-body { padding: 24px 28px; }
    .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 16px; }
    .stat-box { background: #f5f7fa; border-radius: 8px; padding: 18px 20px; border-left: 4px solid #0078d4; }
    .stat-box.green  { border-color: #107c10; }
    .stat-box.yellow { border-color: #c7a000; }
    .stat-box.red    { border-color: #d13438; }
    .stat-box.blue   { border-color: #0078d4; }
    .stat-box .num   { font-size: 30px; font-weight: 800; color: #0f3460; }
    .stat-box .lbl   { font-size: 12px; color: #5c6b7a; margin-top: 2px; }
    .service-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 14px; }
    .service-item { background: #f5f7fa; border-radius: 8px; padding: 14px 18px; border-left: 4px solid #0078d4; }
    .service-item .svc-name { font-weight: 700; font-size: 14px; color: #0f3460; }
    .service-item .svc-type { font-size: 11px; color: #6b7c93; margin-top: 2px; font-family: monospace; }
    .service-item .svc-note { font-size: 13px; color: #3a4a5c; margin-top: 6px; word-break: break-word; }
    .status-table { width: 100%; border-collapse: collapse; font-size: 13.5px; }
    .status-table th { background: #0f3460; color: #fff; padding: 10px 14px; text-align: left; font-size: 12px; font-weight: 600; letter-spacing: .5px; }
    .status-table td { padding: 10px 14px; border-bottom: 1px solid #e8edf3; vertical-align: top; }
    .status-table tr:last-child td { border-bottom: none; }
    .status-table tr:nth-child(even) td { background: #f9fbfd; }
    .pill { display: inline-block; padding: 2px 10px; border-radius: 10px; font-size: 11px; font-weight: 700; }
    .pill.full    { background: #dff6dd; color: #107c10; }
    .pill.partial { background: #fff4ce; color: #7a5800; }
    .pill.orphan  { background: #fde7e9; color: #a4262c; }
    .pill.unknown { background: #e8edf3; color: #5c6b7a; }
    .issue-list { display: flex; flex-direction: column; gap: 12px; }
    .issue { display: flex; gap: 14px; padding: 14px 16px; border-radius: 8px; background: #f5f7fa; }
    .issue .sev { width: 52px; flex-shrink: 0; font-size: 10px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; padding: 3px 0; text-align: center; border-radius: 6px; align-self: flex-start; }
    .issue .sev.high { background: #fde7e9; color: #a4262c; }
    .issue .sev.med  { background: #fff4ce; color: #7a5800; }
    .issue .sev.low  { background: #dff6dd; color: #107c10; }
    .issue .body strong { font-size: 14px; color: #0f3460; display: block; margin-bottom: 3px; }
    .issue .body p { font-size: 13px; color: #3a4a5c; }
    .rec-list { display: flex; flex-direction: column; gap: 10px; }
    .rec { display: flex; gap: 14px; align-items: flex-start; padding: 14px 16px; border-radius: 8px; background: #f5f7fa; }
    .rec .priority { width: 80px; flex-shrink: 0; font-size: 10px; font-weight: 800; text-transform: uppercase; letter-spacing: 1px; padding: 3px 0; text-align: center; border-radius: 6px; }
    .rec .priority.immediate { background: #fde7e9; color: #a4262c; }
    .rec .priority.short     { background: #fff4ce; color: #7a5800; }
    .rec .priority.medium    { background: #cce4f7; color: #004e8c; }
    .rec .priority.long      { background: #e8edf3; color: #3a4a5c; }
    .rec .body strong { font-size: 14px; color: #0f3460; display: block; margin-bottom: 3px; }
    .rec .body p { font-size: 13px; color: #3a4a5c; }
    footer { background: #0f3460; color: #6b8cae; text-align: center; padding: 24px; font-size: 12px; }
  </style>
</head>
<body>

<header>
  <div class="label">Confidential — Internal Use Only</div>
  <h1>Azure Environment Assessment</h1>
  <div class="subtitle">$orgName — Cloud Infrastructure Review</div>
  <div class="meta">
    <span><strong>Report Date:</strong> $reportDate</span>
    <span><strong>Subscription:</strong> $orgName</span>
    <span><strong>Subscription ID:</strong> $subIdEsc</span>
    <span><strong>Total Resources:</strong> $($allResources.Count)</span>
    <span><strong>Region(s):</strong> $regionList</span>
  </div>
</header>

<main>

  <!-- Executive Summary -->
  <div class="card">
    <div class="card-header">
      <div class="icon" style="background:#e1ecf7">📊</div>
      <h2>Executive Summary</h2>
      <span class="section-num">Overview</span>
    </div>
    <div class="card-body">
      <div class="summary-grid">
        <div class="stat-box blue"><div class="num">$($vms.Count)</div><div class="lbl">Virtual Machines</div></div>
        <div class="stat-box blue"><div class="num">$($webApps.Count)</div><div class="lbl">Web Apps &amp; Functions</div></div>
        <div class="stat-box blue"><div class="num">$($sqlServers.Count)</div><div class="lbl">SQL Servers</div></div>
        <div class="stat-box yellow"><div class="num">$totalDbCount</div><div class="lbl">SQL Databases (incl. copies)</div></div>
        <div class="stat-box red"><div class="num">$highAdvisor</div><div class="lbl">High-Impact Advisor Alerts</div></div>
        <div class="stat-box red"><div class="num">~$untaggedPct%</div><div class="lbl">Resources Without Tags</div></div>
        <div class="stat-box blue"><div class="num">$($allResources.Count)</div><div class="lbl">Total Resources</div></div>
        <div class="stat-box $(if($orphanedDisks.Count -gt 0){'yellow'}else{'green'})"><div class="num">$($orphanedDisks.Count)</div><div class="lbl">Unattached Disks</div></div>
      </div>
      <p style="margin-top:20px; font-size:14px; color:#3a4a5c;">
        This assessment covers the <strong>$orgName</strong> Azure subscription with $($allResources.Count) resources
        across $($resourceGroups.Count) resource groups and $($regions.Count) region(s).
        The environment has $highAdvisor high-impact Advisor alerts, $($adHocDbs.Count) ad-hoc database copies
        to review, and approximately $untaggedPct% of resources without tags — limiting cost visibility and governance.
      </p>
    </div>
  </div>

  <!-- Section 1: Services in Use -->
  <div class="card">
    <div class="card-header">
      <div class="icon" style="background:#e1ecf7">☁️</div>
      <h2>Azure Services Currently in Use</h2>
      <span class="section-num">Section 1</span>
    </div>
    <div class="card-body">
      <div class="service-grid">
        $($serviceItems.ToString())
      </div>
    </div>
  </div>

  <!-- Section 2: Issues -->
  <div class="card">
    <div class="card-header">
      <div class="icon" style="background:#fde7e9">🔴</div>
      <h2>Operational Limitations &amp; Issues</h2>
      <span class="section-num">Section 2</span>
    </div>
    <div class="card-body">
      <div class="issue-list">
        $($issueHtml.ToString())
      </div>
    </div>
  </div>

  $vmSection

  $dbSection

  $advisorSection

  <!-- Recommendations -->
  <div class="card">
    <div class="card-header">
      <div class="icon" style="background:#dff6dd">✅</div>
      <h2>Recommended Improvements</h2>
      <span class="section-num">Recommendations</span>
    </div>
    <div class="card-body">
      <div class="rec-list">
        $($recHtml.ToString())
      </div>
    </div>
  </div>

</main>

<footer>
  Azure Environment Assessment &mdash; $orgName &mdash; $reportDate &mdash; Confidential &mdash; Generated by A.E.G.I.S.
</footer>

</body>
</html>
"@

# ─────────────────────────────────────────────────────────────────────────────
# OUTPUT
# ─────────────────────────────────────────────────────────────────────────────

$html | Out-File -FilePath $OutputPath -Encoding UTF8 -Force

Write-Host ("  " + ("─" * 62)) -ForegroundColor $C.Header
Write-Host ""
Write-Ok "Report saved: $OutputPath"

if (-not $NoOpen) {
    Write-Step "Opening in default browser..."
    Start-Process $OutputPath
}

Write-Host ""
if ($PSCommandPath) { Remove-Item -Path $PSCommandPath -Force -ErrorAction SilentlyContinue }
