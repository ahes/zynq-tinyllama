param([Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z]$')][string]$DriveLetter)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$recordPath = Join-Path $root 'build/board/sd_write_verification.json'
$record = Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 | ConvertFrom-Json
$letter = $DriveLetter.ToUpperInvariant()
if(-not $record.passed -or $record.drive -ne ($letter + ':\')) { throw 'No matching verified SD write' }
if((Get-FileHash -LiteralPath ($letter + ':\BOOT.BIN')).Hash -ne $record.boot_sha256) { throw 'Card BOOT hash changed' }
$shell = New-Object -ComObject Shell.Application
$item = $shell.Namespace(17).ParseName($letter + ':')
$ejectName = -join [char[]]@(0x5F39,0x51FA)
$verbs = @($item.Verbs() | Where-Object { $_.Name -match ($ejectName + '|Eject') })
if($verbs.Count -ne 1) { throw 'Cannot uniquely identify safe eject action' }
$verbs[0].DoIt()
$deadline = (Get-Date).AddSeconds(45)
do {
    Start-Sleep -Seconds 2
    $visible = Test-Path -LiteralPath ($letter + ':\BOOT.BIN')
    $logical = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='" + $letter + ":'")
    if(-not $visible -and ($null -eq $logical -or -not $logical.Size)) {
        $record.safe_removal_verified = $true
        $record | ConvertTo-Json | Set-Content -LiteralPath $recordPath -Encoding UTF8
        Write-Output 'SD_SAFE_REMOVAL_VERIFIED'
        return
    }
} while((Get-Date) -lt $deadline)
throw 'Safe eject not confirmed; leave card connected'
