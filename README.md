# Check-UEFICA2023.ps1

PowerShell script to validate Secure Boot and check progress of the Windows UEFI CA 2023 certificate update on a device.

It combines:

- Secure Boot status checks
- Registry status from `UEFICA2023Status`
- System event log analysis for update progression and troubleshooting events
- A final overall device status summary

## What This Script Checks

1. Whether Secure Boot is enabled.
2. Registry status at:
	 - `HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing`
	 - value: `UEFICA2023Status`
3. Relevant System event IDs for expected update progression and known failure/block conditions.
4. Whether the device appears fully updated (based on both registry state and Event ID `1808`).

## Requirements

- Windows device with PowerShell.
- Administrator privileges.
- Access to System event logs.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `-DaysBack` | `int` | `90` | Number of days back to search in the System event log. Valid range: `1-730`. |
| `-MaxEvents` | `int` | `1` | Maximum number of events to return per Event ID. Valid range: `1-100`. |
| `-ResultOnly` | `switch` | `False` | Shows only final overall status without detailed event sections. |

## Usage

Run from an elevated PowerShell session:

```powershell
.\Check-UEFICA2023.ps1
```

Search last 30 days and return up to 5 events per ID:

```powershell
.\Check-UEFICA2023.ps1 -DaysBack 30 -MaxEvents 5
```

Show only the final status line:

```powershell
.\Check-UEFICA2023.ps1 -ResultOnly
```

## Output Sections

When `-ResultOnly` is not used, output includes:

- Secure Boot status
- Registry status for UEFI CA 2023
- Progression Events
- Troubleshoot Events
- Overall Device Status

Final status uses:

- ✅ device appears fully updated
- ❌ device may not be fully updated

## Progression Event IDs

The script tracks expected progression using these event IDs:

- `1801`, `1036`, `1044`, `1045`, `1043`, `1800`, `1799`, `1808`

Event `1808` indicates the device has been fully updated.

## Troubleshoot Event IDs

The script also checks for known issue events, including:

- `1032`, `1795`, `1796`, `1797`, `1798`, `1802`, `1803`

These may indicate firmware, BitLocker, signing, or compatibility problems that block completion.

## Exit Behavior

- If not run as Administrator, the script writes an error and exits with code `1`.

## Notes

- A registry status of `Updated` without Event `1808` may still indicate incomplete rollout state.
- Event visibility depends on log retention and selected `-DaysBack` window.
- Event descriptions are based on Microsoft Secure Boot update documentation.

## Quick Interpretation

- Best-case result:
	- Secure Boot enabled
	- `UEFICA2023Status` is `Updated`
	- Event `1808` present
- Needs attention:
	- Missing progression events
	- Presence of troubleshoot events
	- Final output says device may not be fully updated

## Reference

- [Secure Boot playbook for certificates expiring in 2026](https://techcommunity.microsoft.com/blog/windows-itpro-blog/secure-boot-playbook-for-certificates-expiring-in-2026/4469235)
- [Registry key updates for Secure Boot: Windows devices with IT-managed updates - Microsoft Support](https://support.microsoft.com/en-us/topic/registry-key-updates-for-secure-boot-windows-devices-with-it-managed-updates-a7be69c9-4634-42e1-9ca1-df06f43f360d)
- [Secure Boot troubleshooting guide - Microsoft Support](https://support.microsoft.com/en-us/topic/secure-boot-troubleshooting-guide-5d1bf6b4-7972-455a-a421-0184f1e1ed7d)
- [Secure Boot DB and DBX variable update events - Microsoft Support](https://support.microsoft.com/en-us/topic/secure-boot-db-and-dbx-variable-update-events-37e47cf8-608b-4a87-8175-bdead630eb69)
- [Act now: Secure Boot certificates expire in June 2026 - Windows IT Pro Blog](https://techcommunity.microsoft.com/blog/windows-itpro-blog/act-now-secure-boot-certificates-expire-in-june-2026/4426856)
