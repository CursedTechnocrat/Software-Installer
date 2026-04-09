<#
.SYNOPSIS
    W.A.R.P. - Winget Application Rollout Platform
.DESCRIPTION
    Automated software installation and management with SOC compliance tracking
.PARAMETER Mode
    Install, Update, or Both (default: Both)
.PARAMETER SkipOptional
    Skip optional software selection prompt
.NOTES
    Requires Administrator privileges
    Requires Windows Package Manager (winget)
#>

param(
    [ValidateSet("Install", "Update", "Both")]
    [string]$Mode = "Both",

    [switch]$SkipOptional
)

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

$LogDirectory = "C:\The20dir"

$RequiredSoftware = @(
    "Microsoft.Teams",
    "Microsoft.Office",
    "7zip.7zip",
    "Google.Chrome",
    "Zoom.Zoom",
    "Adobe.Acrobat.Reader.32-bit"
)

$OptionalSoftware = @(
    "Zoom.ZoomOutlookPlugin",
    "Mozilla.Firefox",
    "Dell.CommandUpdate"
)

# ─────────────────────────────────────────────────────────────────────────────
# ADMIN CHECK
# ─────────────────────────────────────────────────────────────────────────────

if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: Run as Administrator." -ForegroundColor Red
    exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# COLORS
# ─────────────────────────────────────────────────────────────────────────────

$Colors = @{
    Header  = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error   = 'Red'
    Info    = 'Gray'
    Accent  = 'Blue'
}

# ─────────────────────────────────────────────────────────────────────────────
# BANNER
# ─────────────────────────────────────────────────────────────────────────────

function Show-WarpBanner {
    Write-Host @"
██╗    ██╗ █████╗ ██████╗ ██████╗
██║    ██║██╔══██╗██╔══██╗██╔══██╗
██║ █╗ ██║███████║██████╔╝██████╔╝
██║███╗██║██╔══██║██╔══██╗██╔═══╝
╚███╔███╔╝██║  ██║██║  ██║██║
 ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝
"@ -ForegroundColor $Colors.Accent
    Write-Host "W.A.R.P. - Winget Application Rollout Platform" -ForegroundColor $Colors.Header
    Write-Host ""
}

# ─────────────────────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────────────────────

if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogPath = "$LogDirectory\SoftwareInstall_$Timestamp.log"
$ComplianceLogPath = "$LogDirectory\Compliance_$Timestamp.log"
$Results = @()
$ComplianceResults = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $Line
    Add-Content $LogPath $Line
}

function Write-Compliance {
    param($Package,$Action,$Status,$Version="N/A")
    $Entry = [PSCustomObject]@{
        Timestamp = Get-Date
        User      = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        Computer  = $env:COMPUTERNAME
        Package   = $Package
        Action    = $Action
        Status    = $Status
        Version   = $Version
        Mode      = $Mode
    }
    $ComplianceResults += $Entry
    Add-Content $ComplianceLogPath ($Entry | ConvertTo-Json -Compress)
}

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

function Get-Version($Id) {
    $v = winget list --id $Id -q 2>$null | Select-String '\d+\.\d+(\.\d+)*'
    if ($v) { $v.Matches[0].Value } else { "Unknown" }
}

function Install-Package($Id,$Required=$true) {
    Write-Log "Processing $Id"
    if (winget list --id $Id -q 2>$null) {
        $ver = Get-Version $Id
        Write-Log "$Id already installed" "WARNING"
        Write-Compliance $Id "Skip" "Already Installed" $ver
        return
    }
    winget install --id $Id --accept-package-agreements --accept-source-agreements -q
    if ($LASTEXITCODE -eq 0) {
        $ver = Get-Version $Id
        Write-Log "$Id installed" "SUCCESS"
        Write-Compliance $Id "Install" "Installed" $ver
    } else {
        Write-Log "$Id failed" "ERROR"
        Write-Compliance $Id "Install" "Failed"
    }
}

function Select-Optional {
    if ($SkipOptional) { return @() }
    Write-Host "`nOptional Software:"
    for ($i=0;$i -lt $OptionalSoftware.Count;$i++) {
        Write-Host "$($i+1). $($OptionalSoftware[$i])"
    }
    $sel = Read-Host "Enter numbers (comma-separated) or blank to skip"
    if (-not $sel) { return @() }
    $sel -split ',' | ForEach-Object { $OptionalSoftware[[int]$_ - 1] }
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

Show-WarpBanner

Write-Log "Mode: $Mode | SkipOptional: $SkipOptional"
Write-Compliance "Script" "Start" "Started"

if ($Mode -in @("Install","Both")) {
    foreach ($pkg in $RequiredSoftware) {
        Install-Package $pkg $true
    }
    foreach ($pkg in (Select-Optional)) {
        Install-Package $pkg $false
    }
}

if ($Mode -in @("Update","Both")) {
    Write-Log "Running updates..."
    winget upgrade --all --accept-package-agreements --accept-source-agreements
    Write-Compliance "All" "Update" "Completed"
}

Write-Log "Completed"
Write-Host "`nCompliance entries: $($ComplianceResults.Count)" -ForegroundColor Green
