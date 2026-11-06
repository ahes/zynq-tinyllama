param([string]$PortName = 'COM4', [int]$Seconds = 14400, [string]$PythonCommand = 'python')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$package = Get-Content -LiteralPath (Join-Path $root 'build/package/verification.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$sd = Get-Content -LiteralPath (Join-Path $root 'build/board/sd_write_verification.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if(-not $package.passed -or -not $sd.passed -or -not $sd.safe_removal_verified -or $sd.boot_sha256 -ne $package.boot_sha256) {
    throw 'New package SD write/readback and safe removal evidence is required'
}
$out = Join-Path $root 'build/board'
$log = Join-Path $out ('uart_reproduced_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
$inputs = @(Get-Content -LiteralPath (Join-Path $root 'evidence/round55/uart_board_20261101_210346.log.inputs.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
$inputs | ConvertTo-Json | Set-Content -LiteralPath ($log + '.inputs.json') -Encoding UTF8
@{boot_sha256=$package.boot_sha256;sd_readback_sha256=$sd.boot_sha256;port=$PortName;log=[IO.Path]::GetFileName($log);cold_start_capture_required=$true} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'capture_identity.json') -Encoding UTF8
Write-Output "REPRO_BOARD_LOG=$log; cold-power the board after CHAT_UART_STARTED"
& (Join-Path $root 'zynq7035_port/software/round55/chat_uart.ps1') -PortName $PortName -Seconds $Seconds -LogPath $log `
    -ExpectedBanner 'Build: round55 chat128 repetition penalty 1.125 20261101' -Inputs $inputs -ReturnAfterInputs
& $PythonCommand (Join-Path $root 'zynq7035_port/software/round55/analyze_board.py') $log
if($LASTEXITCODE -ne 0) { throw 'Reproduced board capture failed control/DMA checks' }
Write-Output "REPRO_COLD_BOARD_CONTROL_PASS=$log; content quality remains separately reviewed"
