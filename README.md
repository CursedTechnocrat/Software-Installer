# Technician Toolkit

> A PowerShell-based toolkit for IT technicians to automate common system administration tasks — forged in the arcane arts of automation.

---

## Table of Contents

- [Tools Overview](#tools-overview)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Logging](#logging)
- [Contributing](#contributing)
- [Disclaimer](#disclaimer)

---

## Tools Overview

| Script | Acronym | Purpose |
|--------|---------|---------|
| **grimoire.ps1** | **G.R.I.M.O.I.R.E.** — General Repository for Integrated Management and Orchestration of IT Resources & Executables | Central hub launcher — run all tools from one interactive menu |
| **runepress.ps1** | **R.U.N.E.P.R.E.S.S.** — Remote Utility for Networked Equipment — Printer Registration, Extraction & Silent Setup | Printer driver installation and network printer configuration |
| **restoration.ps1** | **R.E.S.T.O.R.A.T.I.O.N.** — Renews Every System Through Orderly Rite — Automating The Installation Of New updates | Automated Windows Update management and maintenance |
| **conjure.ps1** | **C.O.N.J.U.R.E.** — Centrally Orchestrates Network-Joined Updates, Rollouts & Executables | Software deployment via Windows Package Manager or Chocolatey |
| **oracle.ps1** | **O.R.A.C.L.E.** — Observes, Reports & Audits Computer Logs & Environments | System diagnostics, health assessment, and HTML report generation |
| **covenant.ps1** | **C.O.V.E.N.A.N.T.** — Configures Onboarding Via Entra — Network, Accounts, Naming & Timezone | Machine onboarding, Entra ID domain join, and new device setup |

---

### G.R.I.M.O.I.R.E.

The central hub for the Technician Toolkit. Presents an interactive numbered menu to launch any of the five tools without navigating the file system. After a tool completes, control returns to the GRIMOIRE menu automatically.

- Auto-elevates to Administrator on first launch if not already elevated
- Validates that each script file exists before attempting to launch it
- Returns to the hub menu after each tool finishes or errors out
- All five tools remain independently runnable without the hub

---

### R.U.N.E.P.R.E.S.S.

Automates printer driver extraction, installation, and network printer configuration via a command-line interface.

- Supports ZIP, EXE, and MSI driver formats
- Handles automatic driver extraction and INF-based installation via pnputil
- Configures network printers via IP (TCP/IP port) or UNC path post-install
- Generates a timestamped installation log (CSV) in the script directory

---

### R.E.S.T.O.R.A.T.I.O.N.

Automates Windows Update detection, installation, and reboot handling with minimal user intervention.

- Disables sleep and display timeout for the duration of the run; restores settings on exit
- Ensures NuGet provider and PSWindowsUpdate module are installed and current
- Installs available updates (drivers excluded) with no forced reboot
- Checks reboot status and prompts only when required
- 30-second reboot countdown with Escape key cancel

---

### C.O.N.J.U.R.E.

Manages software deployment using the Windows Package Manager (winget) or Chocolatey.

- Supports both winget and Chocolatey package managers (user selectable at runtime)
- Installs required and optional software packages defined at the top of the script
- Upgrade-all mode for keeping existing packages current
- Tracks and displays installation status per package

**Default required packages:** Microsoft Teams, Microsoft 365, 7-Zip, Google Chrome, Adobe Acrobat Reader, Zoom

**Default optional packages:** Zoom Outlook Plugin, Mozilla Firefox, Dell Command Update

---

### O.R.A.C.L.E.

Audits the current state of a Windows machine and exports a formatted HTML report to the Desktop.

- Hardware inventory: CPU, RAM, disk usage with visual bar charts, model and serial number
- OS details: version, build, architecture, install date, activation status
- Network configuration: all active adapters with IP, MAC, gateway, and DNS
- System health: uptime, last reboot time, battery status (laptops)
- Pending Windows Update scan (read-only, no installation)
- Installed software list sourced from registry
- Recent event log errors and critical events (last 24 hours)
- Dark-themed HTML report with color-coded indicators and status badges

---

### C.O.V.E.N.A.N.T.

Guides a technician through the full setup of a new Windows machine.

- Pre-flight check of current domain and Entra ID join status
- Optional computer rename with hostname validation
- Entra ID (Azure AD) domain join — UPN and password entered securely in the terminal
- Network drive mapping — repeatable, supports per-share credentials and persistent mapping
- Local administrator account creation (or password reset if account exists)
- Timezone configuration with common presets or manual entry
- Action summary with 30-second reboot countdown and Escape to cancel

---

## Requirements

| Requirement | Notes |
|-------------|-------|
| Windows PowerShell 5.1+ | All scripts |
| Administrator privileges | All scripts (auto-elevation on `grimoire.ps1` and `runepress.ps1`) |
| Internet connectivity | All scripts |
| Windows Package Manager (winget) | `conjure.ps1` (Chocolatey supported as alternative) |
| PSWindowsUpdate module | `restoration.ps1` (auto-installed if missing) |
| Entra ID account with device join permissions | `covenant.ps1` |

---

## Installation

1. Clone or download this repository
2. Extract all files into the same folder
3. Open PowerShell as Administrator
4. Navigate to the toolkit directory

```powershell
cd C:\Path\To\Toolkit
```

---

## Usage

### Recommended: Launch via GRIMOIRE (hub)

```powershell
.\grimoire.ps1
```

Select a tool by number. Control returns to the menu when the tool finishes.

### Or run tools directly

```powershell
.\runepress.ps1     # Printer driver installation and configuration
.\restoration.ps1   # Windows Update management
.\conjure.ps1       # Software deployment via winget or Chocolatey
.\oracle.ps1        # System diagnostics and HTML health report
.\covenant.ps1      # New machine onboarding and Entra ID domain join
```

All scripts must be run as Administrator.

---

## Configuration

Only `conjure.ps1` exposes configurable variables at the top of the file. All other scripts collect their inputs interactively at runtime.

| Script | Configurable Variables |
|--------|------------------------|
| **grimoire.ps1** | None — tool list is defined in the `$Tools` array in the script |
| **runepress.ps1** | `$ExtractRoot` — driver extraction staging folder (defaults to `.\ExtractedDrivers`) |
| **restoration.ps1** | None — power settings are detected and restored automatically |
| **conjure.ps1** | `$RequiredSoftware` / `$RequiredSoftwareChoco` — required package IDs; `$OptionalSoftware` / `$OptionalSoftwareChoco` — optional package IDs; `$PackageManager` — default manager (`winget` or `choco`) |
| **oracle.ps1** | `$ReportOutputPath` — folder where the HTML report is saved (defaults to `%USERPROFILE%\Desktop`; accepts any local or UNC path) |
| **covenant.ps1** | None — all settings entered interactively at each step |

---

## Logging

| Script | Log Output |
|--------|------------|
| **grimoire.ps1** | No log file — hub activity is visible on-screen only |
| **runepress.ps1** | Script directory — `RUNEPRESS_InstallLog_<timestamp>.csv` |
| **restoration.ps1** | `%TEMP%\RESTORATION_<timestamp>.log` (PowerShell transcript of the full session) |
| **conjure.ps1** | Console — per-package status table printed at completion |
| **oracle.ps1** | `$ReportOutputPath` — `ORACLE_<timestamp>.html` (defaults to Desktop; configurable) |
| **covenant.ps1** | Console — action summary printed at completion |

---

## Contributing

Contributions are welcome. Please ensure all additions maintain:

- Consistent formatting and naming conventions
- The standard `<# .SYNOPSIS / .DESCRIPTION / .USAGE / .NOTES #>` header block
- Comprehensive error handling
- Detailed logging and user feedback
- Administrator privilege checks

---

## Disclaimer

These scripts modify system settings and may install software, updates, or change domain membership in ways that require a reboot. Save all work before running. Use at your own risk.

---

## License

[Add license information here]
