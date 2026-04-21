<#
.SYNOPSIS
    DEPRECATED stub - renamed to talisman.ps1 in TechnicianToolkit v3.0.

.DESCRIPTION
    aegis.ps1 was renamed to talisman.ps1 in TechnicianToolkit v3.0. This stub
    forwards every argument to the new script and prints a one-line deprecation
    warning so technicians notice before their scheduled tasks break. Remove
    pinned references to aegis.ps1 from runbooks, scheduled jobs, and quick-
    launch snippets, then delete this file from your working folder.

.USAGE
    PS C:\> .\aegis.ps1 @args   # forwards to .\talisman.ps1 @args

.NOTES
    Version : 3.0
#>

[CmdletBinding()]
param(
    [switch]$Unattended,
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$ForwardArgs
)

# ===========================
# SHARED MODULE BOOTSTRAP
# ===========================
$TKModulePath = Join-Path $PSScriptRoot 'TechnicianToolkit.psm1'
if (-not (Test-Path $TKModulePath)) {
    $TKModuleUrl = 'https://raw.githubusercontent.com/CursedTechnocrat/TechnicianToolkit/main/TechnicianToolkit.psm1'
    Write-Host "  [*] Shared module TechnicianToolkit.psm1 not found - downloading from GitHub..." -ForegroundColor Magenta
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-RestMethod -Uri $TKModuleUrl -OutFile $TKModulePath -ErrorAction Stop
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($TKModulePath, [ref]$null, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) {
            Remove-Item -Path $TKModulePath -Force -ErrorAction SilentlyContinue
            Write-Host "  [!!] Downloaded module failed syntax validation - file removed." -ForegroundColor Red
            Write-Host "       $($parseErrors[0].Message)" -ForegroundColor Red
            exit 1
        }
        Write-Host "  [+] Module downloaded and verified." -ForegroundColor Green
    } catch {
        Write-Host "  [!!] Could not download TechnicianToolkit.psm1:" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "       Place the module manually next to this script from:" -ForegroundColor Yellow
        Write-Host "       $TKModuleUrl" -ForegroundColor Yellow
        exit 1
    }
}
Import-Module $TKModulePath -Force -ErrorAction Stop

Write-Warning "aegis.ps1 is deprecated. Renamed to talisman.ps1 in TechnicianToolkit v3.0 - update your references. This stub will be removed in a future release."

$target = Join-Path $PSScriptRoot 'talisman.ps1'
if (-not (Test-Path $target)) {
    $targetUrl = 'https://raw.githubusercontent.com/CursedTechnocrat/TechnicianToolkit/main/talisman.ps1'
    Write-Host "  [*] talisman.ps1 not found - downloading from GitHub..." -ForegroundColor Magenta
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-RestMethod -Uri $targetUrl -OutFile $target -ErrorAction Stop
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($target, [ref]$null, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) {
            Remove-Item -Path $target -Force -ErrorAction SilentlyContinue
            Write-Host "  [!!] talisman.ps1 failed syntax validation - file removed." -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "  [!!] Could not download talisman.ps1: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Forward every argument (switch + positional/named remainder) to the renamed script
$fwd = @()
if ($Unattended) { $fwd += '-Unattended' }
if ($ForwardArgs) { $fwd += $ForwardArgs }
& $target @fwd
