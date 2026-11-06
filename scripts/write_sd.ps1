param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z]$')][string]$DriveLetter,
    [Parameter(Mandatory=$true)][UInt64]$ExpectedDiskSizeBytes
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$verification = Get-Content -LiteralPath (Join-Path $root 'build/package/verification.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if(-not $verification.passed) { throw 'Package verification has not passed' }
$volume = Get-Volume -DriveLetter $DriveLetter
$partition = Get-Partition -DriveLetter $DriveLetter
$disk = Get-Disk -Number $partition.DiskNumber
if($volume.DriveType -ne 'Removable' -or $volume.FileSystem -ne 'FAT32' -or
   $disk.BusType -notin @('USB','SD') -or $disk.Size -ne $ExpectedDiskSizeBytes) {
    throw 'Target card identity/type/filesystem does not match; no write performed'
}
$items = @(
    @{Name='BOOT.BIN';Hash=$verification.boot_sha256},
    @{Name='llm.bin';Hash=$verification.model_sha256},
    @{Name='tkz.bin';Hash=$verification.tokenizer_sha256}
)
foreach($item in $items) {
    $path = Join-Path $root ('assets/sdcard/' + $item.Name)
    if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $item.Hash) { throw ('Source hash mismatch: ' + $item.Name) }
}
$targetRoot = $DriveLetter.ToUpperInvariant() + ':\'
$out = Join-Path $root 'build/board'
New-Item -ItemType Directory -Path $out -Force | Out-Null
foreach($item in $items) {
    $target = Join-Path $targetRoot $item.Name
    if((Test-Path -LiteralPath $target) -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -eq $item.Hash) { continue }
    if($item.Name -eq 'BOOT.BIN' -and (Test-Path -LiteralPath $target)) {
        $backup = Join-Path $out ('sd_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '.BIN')
        Copy-Item -LiteralPath $target -Destination $backup
        if((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath $backup).Hash) { throw 'Previous BOOT backup mismatch' }
    }
    Copy-Item -LiteralPath (Join-Path $root ('assets/sdcard/' + $item.Name)) -Destination $target
    if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $item.Hash) { throw ('Readback mismatch: ' + $item.Name) }
}
$record = [ordered]@{
    passed=$true; boot_sha256=$verification.boot_sha256; model_sha256=$verification.model_sha256;
    tokenizer_sha256=$verification.tokenizer_sha256; disk_number=$disk.Number; disk_size_bytes=$disk.Size;
    drive=$targetRoot; time=(Get-Date -Format o); safe_removal_verified=$false
}
$record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'sd_write_verification.json') -Encoding UTF8
Write-Output 'SD_WRITE_READBACK_PASS; safely eject before moving the card to the powered-off board'
