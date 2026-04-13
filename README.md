# Technician Toolkit

> A PowerShell-based toolkit for IT technicians to automate common system administration tasks.

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

| Tool | Full Name | Purpose |
|------|-----------|---------|
| **M.A.G.I.C.** | Machine Automated Graphical Ink Configurator | Printer driver installation and network printer configuration |
| **U.P.K.E.E.P.** | Update Package Keeping Everything Efficiently Prepared | Automated Windows Update management and maintenance |
| **W.A.R.P.** | Winget Application Rollout Platform | Software deployment and SOC compliance tracking |

---

### M.A.G.I.C.

Automates printer driver extraction, installation, and network printer configuration via a command-line interface.

- Supports ZIP, EXE, and MSI driver formats
- Handles automatic driver extraction and installation
- Configures network printers post-install
- Generates installation logs

---

### U.P.K.E.E.P.

Automates Windows Update detection, installation, and reboot handling with minimal user intervention.

- Disables sleep/display timeout for the duration of the run; restores monitor timeout on exit
- Ensures NuGet provider and PSWindowsUpdate module are installed and current
- Installs available updates (drivers excluded), no forced reboot
- Checks reboot status and prompts only when required
- 30-second reboot countdown with Escape key cancel

---

### W.A.R.P.

Manages software deployment using the Windows Package Manager (winget) with compliance tracking.

- Installs required and optional software packages
- Tracks installation status for SOC compliance
- Generates detailed installation and compliance reports

---

## Requirements

| Requirement | Notes |
|-------------|-------|
| Windows PowerShell 5.1+ | All tools |
| Administrator privileges | All tools |
| Internet connectivity | All tools |
| Windows Package Manager (winget) | W.A.R.P. only |

---

## Installation

1. Clone or download this repository
2. Extract files to your desired location
3. Open PowerShell as Administrator
4. Navigate to the toolkit directory

```powershell
cd C:\Path\To\Toolkit
```

---

## Usage

```powershell
# Printer driver installation and configuration
.\M.A.G.I.C.ps1

# Windows Update management
.\Upkeep.ps1

# Software deployment (install required + optional packages)
.\W.A.R.P.ps1 -Mode Both
```

---

## Configuration

Each script exposes configurable variables at the top of the file.

| Tool | Configurable Options |
|------|----------------------|
| **M.A.G.I.C.** | Driver file locations, installation paths |
| **U.P.K.E.E.P.** | Power settings, update preferences |
| **W.A.R.P.** | Log directory, required/optional software lists |

---

## Logging

All tools write logs automatically.

| Tool | Log Location |
|------|--------------|
| **M.A.G.I.C.** | Script directory |
| **U.P.K.E.E.P.** | `%TEMP%\UPKEEP_<timestamp>.log` |
| **W.A.R.P.** | Configured log directory |

---

## Contributing

Contributions are welcome. Please ensure all additions maintain:

- Consistent formatting and naming conventions
- Comprehensive error handling
- Detailed logging
- Clear user prompts and feedback

---

## Disclaimer

These scripts modify system settings and may install software or updates that require a reboot. Save all work before running. Use at your own risk.

---

## License

[Add license information here]
