# ================================================================
#  M.A.G.I.C. - Machine Automated Graphical Ink Configurator
#  Version: 2.0 (Standardized Release)
# ================================================================
#  Purpose: Automated printer driver installation and network 
#           printer configuration via command-line interface
# ================================================================

# ===========================
# ADMIN PRIVILEGE CHECK
# ===========================
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not \$IsAdmin) {
    Write-Host "INFO: Restarting script with administrator privileges..." -ForegroundColor Yellow
    $PSExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
    Start-Process -FilePath \$PSExe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"\$PSCommandPath`"" `
        -Verb RunAs
    exit
}

# ===========================
# SCRIPT INITIALIZATION
# ===========================

# Resolve script execution path
if (\$PSCommandPath) {
    \$ScriptPath = Split-Path -Parent $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    \$ScriptPath = Split-Path -Parent \$MyInvocation.MyCommand.Path
}
else {
    \$ScriptPath = Get-Location
}

# Initialize global variables
\$ExtractRoot = Join-Path \$ScriptPath "ExtractedDrivers"
\$InstalledManufacturers = @()
\$InstallationLog = @()

# ===========================
# DISPLAY BANNER
# ===========================

function Show-Banner {
    Clear-Host
    Write-Host @"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║      ███╗   ███╗ █████╗  ██████╗ ██╗ ██████╗            ║
║      ████╗ ████║██╔══██╗██╔════╝ ██║██╔════╝            ║
║      ██╔████╔██║███████║██║  ███╗██║██║                 ║
║      ██║╚██╔╝██║██╔══██║██║   ██║██║██║                 ║
║      ██║ ╚═╝ ██║██║  ██║╚██████╔╝██║╚██████╗            ║
║      ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝ ╚═════╝            ║
║                                                            ║
║   Machine Automated Graphical Ink Configurator            ║
║   Printer Registration & Installation Network Tool        ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

    Write-Host ""
    Write-Host "Script Location: \$ScriptPath" -ForegroundColor Gray
    Write-Host "Execution Time:  \$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
}

# ===========================
# DISPLAY DRIVER PREP INSTRUCTIONS
# ===========================

function Show-DriverPrepInstructions {
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " Step 1: Driver Preparation" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Instructions:" -ForegroundColor Yellow
    Write-Host "  1. Download the printer driver from the manufacturer website" -ForegroundColor White
    Write-Host "  2. Save the file to this location:" -ForegroundColor White
    Write-Host "     \$ScriptPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Supported formats:" -ForegroundColor Yellow
    Write-Host "  • ZIP archives (.zip)" -ForegroundColor White
    Write-Host "  • Executable installers (.exe)" -ForegroundColor White
    Write-Host "  • Windows Installer packages (.msi)" -ForegroundColor White
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# ===========================
# PROMPT USER TO PLACE DRIVER
# ===========================

function Wait-ForDriverFile {
    do {
        Write-Host "Ready to proceed? (Y/N/Q)" -ForegroundColor Yellow
        Write-Host "  Y = Continue with installation" -ForegroundColor Gray
        Write-Host "  N = Go back and check folder" -ForegroundColor Gray
        Write-Host "  Q = Quit" -ForegroundColor Gray
        Write-Host ""

        $response = Read-Host "Enter choice"

        switch ($response.ToUpper()) {
            "Y" {
                return $true
            }
            "N" {
                Write-Host ""
                Show-DriverPrepInstructions
                return Wait-ForDriverFile
            }
            "Q" {
                Write-Host ""
                Write-Host "WARNING: Script terminated by user." -ForegroundColor Yellow
                exit 0
            }
            default {
                Write-Host "Invalid input. Please enter Y, N, or Q." -ForegroundColor Red
                Write-Host ""
                return Wait-ForDriverFile
            }
        }
    } while ($true)
}

# ===========================
# LOCATE DRIVER FILES
# ===========================

function Find-DriverFiles {
    \$DriverFiles = Get-ChildItem -Path \$ScriptPath -File |
                   Where-Object { $_.Extension -match '\.(zip|exe|msi)$' } |
                   Where-Object { \$_.Name -ne \$MyInvocation.ScriptName }

    return $DriverFiles
}

# ===========================
# EXTRACT AND INSTALL ZIP DRIVERS
# ===========================

function Install-ZipDriver {
    param(
        [System.IO.FileInfo]$ZipFile
    )

    $DriverName = [System.IO.Path]::GetFileNameWithoutExtension($ZipFile.Name)
    \$ExtractPath = Join-Path \$ExtractRoot \$DriverName

    Write-Host ""
    Write-Host "Processing ZIP: \$(\$ZipFile.Name)" -ForegroundColor Cyan
    Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor Cyan

    # Clean previous extraction
    if (Test-Path \$ExtractPath) {
        Write-Host "Removing previous extraction directory..." -ForegroundColor Yellow
        try {
            Remove-Item \$ExtractPath -Recurse -Force -ErrorAction Stop
            Write-Host "OK:
