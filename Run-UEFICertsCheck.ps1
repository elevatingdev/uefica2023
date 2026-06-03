if (Test-Path -Path (Join-Path $PSScriptRoot "Get-UEFICertificate.ps1")) {
    $scriptPath = Join-Path $PSScriptRoot "Get-UEFICertificate.ps1"
}
else {
    Install-Script -Name Get-UEFICertificate -Scope CurrentUser
}

$certTypes = @("KEK", "DB", "PK")
foreach ($certType in $certTypes) {
    & $scriptPath -Type $certType
}
