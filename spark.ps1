<#
.SYNOPSIS
    S.P.A.R.K - Software Package & Resource Kit
    Automated Package Manager Setup & Installation

.DESCRIPTION
    Installs core and optional MSP software packages using Winget (primary)
    or Chocolatey (fallback). Designed for fully unattended use in RMM tools,
    Kaseya LiveConnect, and Task Scheduler. All optional package selections
    are parameter-driven — no interactive prompts.

.PARAMETER InstallDellCommandUpdate
    Install Dell Command Update. (Optional - 8/9 companies)

.PARAMETER InstallZoomOutlookPlugin
    Install the Zoom Outlook Plugin. (Optional - Company 7 only)

.PARAMETER InstallDellCommand
    Install Dell Command Suite. (Optional - Company 3 only; different from Dell Command Update)

.PARAMETER LogPath
    Path for the installation log CSV.
    Default: C:\ProgramData\SPARK\install_log.csv

.EXAMPLE
    .\SPARK.ps1
    Installs core software (Edge, 7-zip, Adobe Reader, Zoom Client, Office 365).

.EXAMPLE
    .\SPARK.ps1 -InstallDellCommandUpdate
    Installs core software plus Dell Command Update (most companies).

.EXAMPLE
    .\SPARK.ps1 -InstallDellCommandUpdate -InstallZoomOutlookPlugin
    Installs core software, Dell Command Update, and Zoom Outlook Plugin (Company 7).

.EXAMPLE
    .\SPARK.ps1 -InstallDellCommand
    Installs core software and Dell Command Suite (Company 3 only).

.EXAMPLE
    .\SPARK.ps1 -InstallDellCommandUpdate -LogPath "D:\Logs\spark.csv"
    Installs core + Dell Command Update, logging to custom path.
#>

param(
    [switch]$InstallDellCommandUpdate,
    [switch]$InstallZoomOutlookPlugin,
    [switch]$InstallDellCommand,
    [string]$LogPath = "C:\ProgramData\SPARK\install_log.csv"
)
