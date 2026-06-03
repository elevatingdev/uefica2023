Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot' -Name 'AvailableUpdates' -Value 0x5944
Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'
