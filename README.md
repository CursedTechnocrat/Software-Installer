```markdown
# Technician Toolkit

A comprehensive PowerShell-based toolkit for IT technicians to automate common system administration tasks.

## Tools Included

### M.A.G.I.C. (Machine Automated Graphical Ink Configurator)
Automated printer driver installation and network printer configuration via command-line interface.

**Features:**
- Automatic driver extraction and installation
- Support for ZIP, EXE, and MSI formats
- Network printer configuration
- Installation logging

### U.P.K.E.E.P. (Update Package Keeping Everything Efficiently Prepared)
Automated Windows Update & Maintenance Tool

**Features:**
- System sleep configuration management
- PSWindowsUpdate module installation and management
- Automated Windows update detection and installation
- Intelligent reboot detection
- User-friendly reboot countdown with cancel option

### W.A.R.P. (Winget Application Rollout Platform)
Automated software installation and management with SOC compliance tracking.

**Features:**
- Required and optional software installation
- Winget package manager integration
- Update management
- Compliance logging and tracking
- Detailed installation reports

## Requirements

- Windows PowerShell 5.1 or later
- Administrator privileges
- Internet connectivity
- Windows Package Manager (winget) for W.A.R.P.

## Installation

1. Clone or download this repository
2. Extract files to desired location
3. Open PowerShell as Administrator
4. Navigate to the toolkit directory
5. Run desired script

## Usage

### M.A.G.I.C.
```powershell
.\M.A.G.I.C.ps1
```

### U.P.K.E.E.P.
```powershell
.\Upkeep.ps1
```

### W.A.R.P.
```powershell
.\W.A.R.P.ps1 -Mode Both
```

## Configuration

Each script includes configurable variables at the top:

- **M.A.G.I.C.**: Driver file locations and installation paths
- **U.P.K.E.E.P.**: Power settings and update preferences
- **W.A.R.P.**: Log directory, required/optional software lists

## Logging

All tools generate comprehensive logs:

- **M.A.G.I.C.**: Installation logs in script directory
- **U.P.K.E.E.P.**: Update logs with timestamps
- **W.A.R.P.**: Detailed installation and compliance logs in configured directory

## Support

For issues or questions:
1. Check the troubleshooting section in each script
2. Review log files for error details
3. Ensure you're running as Administrator
4. Verify system requirements are met

## Disclaimer

These scripts modify system settings and may install updates/software that require a system reboot. Ensure all unsaved work is backed up before running. Use at your own risk.

## License

[Add your license information here]

## Contributing

Contributions are welcome! Please ensure scripts maintain:
- Consistent formatting and naming conventions
- Comprehensive error handling
- Detailed logging capabilities
- Clear user prompts and feedback

---

**Technician Toolkit** - Making system administration easier, one script at a time.
```
