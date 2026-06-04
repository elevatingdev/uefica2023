try {
    $uefiCA2023Status = Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' -Name 'UEFICA2023Status'
    $availableUpdates = Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot' -Name 'AvailableUpdates'
}
catch {
    Write-Error "`nAn error to get UEFI CA 2023 status or Available Updates value: $_"
    exit 1
}

if ($uefiCA2023Status -eq 'NotStarted' -and $availableUpdates -eq 0x0) {
    Write-Host "`nInitiating the update process ..."
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot' -Name 'AvailableUpdates' -Value 0x5944
}

Write-Host "`nStarting secure boot update task ..."
Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'
