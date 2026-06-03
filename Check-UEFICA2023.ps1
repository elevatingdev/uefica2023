<#
.SYNOPSIS
    Checks Secure Boot status and UEFI 2023 certificates update progress.

.DESCRIPTION
    This script verifies Secure Boot configuration and monitors the UEFI 2023 certificates
    update process by checking registry values and analyzing System event logs. It displays
    progression events and identifies potential issues requiring troubleshooting.

.PARAMETER DaysBack
    Number of days to search back in the event log. Default is 90 days.

.PARAMETER MaxEvents
    Maximum number of events to retrieve per Event ID. Default is 1.

.PARAMETER ResultOnly
    If specified, only the overall device status will be displayed without detailed event information.

.EXAMPLE
    .\Check-UEFICA2023.ps1
    Runs the script with default parameters (90 days back, 1 max event).

.EXAMPLE
    .\Check-UEFICA2023.ps1 -DaysBack 30 -MaxEvents 5
    Searches the last 30 days and retrieves up to 5 events per Event ID.

.EXAMPLE
    .\Check-UEFICA2023.ps1 -ResultOnly
    Displays only the overall device status without detailed event information.

.NOTES
    Requires: Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateRange(1, 730)]
    [int]$DaysBack = 90,

    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$MaxEvents = 1,

    [Parameter()]
    [switch]$ResultOnly
)

function Test-Administrator {
    <#
    .SYNOPSIS
        Checks if the script is running with administrator privileges.

    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Warning "Unable to determine administrator status: $_"
        return $false
    }
}

function Get-SecureBootStatus {
    <#
    .SYNOPSIS
        Tests if Secure Boot is supported and enabled.

    .OUTPUTS
        System.String - Returns $true, $false, or a string indicating status.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $status = Confirm-SecureBootUEFI -ErrorAction Stop
        Write-Verbose "Secure Boot status: $status"
    }
    catch {
        Write-Warning "Unable to determine Secure Boot status: $_"
        $status = "Not Supported or Unable to Determine"
    }
    return $status
}

function Get-RegistryUEFICA2023Status {
    <#
    .SYNOPSIS
        Retrieves the UEFI CA 2023 update status from the registry.

    .OUTPUTS
        System.String - Returns 'Updated', 'NotStarted', 'InProgress', or an error message.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"

    try {
        if (-not (Test-Path $regPath)) {
            Write-Verbose "Registry path not found: $regPath"
            return "Not Available - Registry Path Not Found"
        }
        $status = (Get-ItemProperty -Path $regPath -ErrorAction Stop)."UEFICA2023Status"
        Write-Verbose "UEFI CA 2023 status from registry: $status"
    }
    catch {
        Write-Warning "Unable to determine UEFI CA 2023 status: $_"
        $status = "Not Available or Unable to Determine"
    }
    return $status
}

function Get-EventLogEvents {
    <#
    .SYNOPSIS
        Retrieves events from the specified event log based on given Event IDs and time range.

    .PARAMETER DaysBack
        Number of days to search back in the event log.

    .PARAMETER MaxEvents
        Maximum number of events to retrieve per Event ID.

    .PARAMETER LogName
        Name of the event log to search.

    .PARAMETER EventIDs
        Array of Event IDs to search for.

    .OUTPUTS
        System.Collections.Hashtable - Returns a hashtable with Event IDs as keys and event entries as values.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [int]$DaysBack,
        [int]$MaxEvents,
        [string]$LogName,
        [int[]]$EventIDs
    )
    [hashtable]$events = @{}

    $startDate = (Get-Date).AddDays(-$DaysBack)
    foreach ($eventID in $EventIDs) {
        try {
            $entries = Get-WinEvent -FilterHashtable @{
                LogName   = $LogName
                ID        = $eventID
                StartTime = $startDate
            } -MaxEvents $MaxEvents -ErrorAction Stop

            if ($entries.Count -gt 0) {
                $events[$eventID] = $entries
                Write-Verbose "Found $($entries.Count) event(s) for ID $eventID in the last $DaysBack days."
            }
            else {
                Write-Verbose "No events found for ID $eventID in the last $DaysBack days."
                $events[$eventID] = @() # Store empty array if no events found
            }
        }
        catch {
            Write-Verbose "Unable to retrieve events for Event ID ${eventID}: $_"
            $events[$eventID] = @() # Store empty array if no events found or error occurs
        }
    }

    return $events
}


# Initialize script variables
$checkmark = [char]0x2714
$crossmark = [char]0x2716
$hostname = $env:COMPUTERNAME
[hashtable]$eventToSearch = @{
    LogName = "System"
    IDs     = @{
        1032 = "The Secure Boot update <event type> was not applied due to a known incompatibility with the current BitLocker configuration"
        1034 = "Secure Boot Dbx update applied successfully"
        1036 = "Secure Boot Db update applied successfully"
        1043 = "Secure Boot KEK update applied successfully"
        1044 = "Secure Boot DB update to install Microsoft Option ROM UEFI CA 2023 certificate applied successfully"
        1045 = "Secure Boot DB update to install Microsoft UEFI CA 2023 certificate applied successfully"
        1795 = "The system firmware returned an error <firmware error code> when attempting to update a Secure Boot variable <DB, DBX, or KEK>"
        1796 = "The Secure Boot update failed to update <event type> with error <error code>"
        1797 = "The Secure Boot update failed as the Windows UEFI CA 2023 certificate is not present in Db"
        1798 = "The Secure Boot Dbx update failed as boot manager is not signed with the Windows UEFI CA 2023 certificate"
        1799 = "Boot manager signed by Windows UEFI CA 2023 is installed"
        1800 = "A reboot is required before installing the Secure Boot update"
        1801 = "Secure Boot certificates have been updated but are not yet applied to the device firmware"
        1802 = "The Secure Boot update <event type> was blocked due to a known firmware issue on the device. Check with your device vendor for a firmware update that addresses the issue"
        1803 = "A PK-signed Key Exchange Key (KEK) cannot be found for this device"
        1808 = "This device has updated Secure Boot CA/keys and been fully updated"
    }
} # UEFI CA 2023 related events selected from https://support.microsoft.com/en-us/topic/secure-boot-db-and-dbx-variable-update-events-37e47cf8-608b-4a87-8175-bdead630eb69

# Expected progression steps from https://support.microsoft.com/en-us/topic/secure-boot-troubleshooting-guide-5d1bf6b4-7972-455a-a421-0184f1e1ed7d#bkmk_expected_progression_availableupdates
# Event ID 1808 indicates that the device is fully updated
# Any missing event before Event ID 1808 may indicate the issue
$eventUpdateProgressionIDs = @(1801, 1036, 1044, 1045, 1043, 1800, 1799, 1808)

# Information only events
$eventInformationIDs = @(1034)

# Troubleshooting events
$eventTroubleshootIDs = $eventToSearch["IDs"].Keys | Where-Object { $_ -notin $eventUpdateProgressionIDs } | Where-Object { $_ -notin $eventInformationIDs } | Sort-Object

# Verify administrator privileges
if (-not (Test-Administrator)) {
    Write-Error "This script requires administrator privileges. Please run as Administrator."
    exit 1
}

# 1. Get Secure Boot status
$secureBootStatus = Get-SecureBootStatus

# 2. Get UEFI CA 2023 certificate status from registry
$uefiCA2023Status = Get-RegistryUEFICA2023Status

# 3. Get UEFI CA 2023 Event Log IDs
$events = Get-EventLogEvents -DaysBack $DaysBack -MaxEvents $MaxEvents -LogName $eventToSearch["LogName"] -EventIDs $eventToSearch["IDs"].Keys

if (-not $ResultOnly) {
    Write-Host "--- Secure Boot status and UEFI 2023 certificates update status ---" -ForegroundColor Cyan
    # 1. Show Secure Boot status
    if ($secureBootStatus -eq $true) {
        Write-Host "${hostname}: Secure Boot is supported and is enabled" -ForegroundColor Green
    }
    elseif ($secureBootStatus -eq $false) {
        Write-Host "${hostname}: Secure Boot is supported and is disabled" -ForegroundColor Yellow
    }
    else {
        Write-Host "${hostname}: Secure Boot is not supported or unable to determine" -ForegroundColor Red
    }

    # 2. Show UEFI 2023 certificates update status from registry
    if ($uefiCA2023Status -eq "Updated") {
        Write-Host "${hostname}: UEFI 2023 certificates update has completed" -ForegroundColor Green
    }
    elseif ($uefiCA2023Status -eq "NotStarted") {
        Write-Host "${hostname}: UEFI 2023 certificates update has not yet run" -ForegroundColor Yellow
    }
    elseif ($uefiCA2023Status -eq "InProgress") {
        Write-Host "${hostname}: UEFI 2023 certificates update is actively in progress" -ForegroundColor Yellow
    }
    else {
        Write-Host "${hostname}: UEFI 2023 certificates update status is not available or unable to determine" -ForegroundColor Red
    }

    # 4. Show progression steps events
    Write-Host "`n--- Progression Events ---" -ForegroundColor Cyan
    foreach ($eventID in $eventUpdateProgressionIDs) {
        $entries = $events[$eventID]
        if ($entries.Count -gt 0) {
            Write-Host "${hostname}: [$eventID]: $($eventToSearch["IDs"][$eventID])" -ForegroundColor Green
            Write-Host "  - Total Events Found in last $DaysBack days: $($entries.Count)"
            Write-Host "  - Latest Event Time: $($entries[0].TimeCreated)"
            foreach ($entry in $entries) {
                Write-Host "    - Time: $($entry.TimeCreated)"
            }
        }
        else {
            Write-Host "${hostname}: [$eventID]: $($eventToSearch["IDs"][$eventID])" -ForegroundColor Red
            Write-Host "  - No events found in the last $DaysBack days"
        }
    }

    # 5. Show troubleshoot events
    Write-Host "`n--- Troubleshoot Events ---" -ForegroundColor Red
    foreach ($eventID in $eventTroubleshootIDs) {
        $entries = $events[$eventID]
        if ($entries.Count -gt 0) {
            Write-Host "${hostname}: [$eventID]: $($eventToSearch["IDs"][$eventID])" -ForegroundColor Yellow
            Write-Host "  - Total Events Found in last $DaysBack days: $($entries.Count)"
            Write-Host "  - Latest Event Time: $($entries[0].TimeCreated)"
            foreach ($entry in $entries) {
                Write-Host "    - Time: $($entry.TimeCreated)"
            }
        }
        else {
            Write-Host "${hostname}: [$eventID]: $($eventToSearch["IDs"][$eventID])" -ForegroundColor Yellow
            Write-Host "  - No events found in the last $DaysBack days"
        }
    }
}

# 6. Show the device overall status based on registry and event logs
if (-not $ResultOnly) { Write-Host "`n--- Overall Device Status ---" -ForegroundColor Cyan }
if ($uefiCA2023Status -eq "Updated" -and $events[1808].Count -gt 0) {
    Write-Host "$checkmark $hostname is fully updated with UEFI Secure Boot certificate 2023`n" -ForegroundColor Green
}
else {
    Write-Host "$crossmark $hostname may not be fully updated. Check the progression or troubleshoot events`n" -ForegroundColor Yellow
}
