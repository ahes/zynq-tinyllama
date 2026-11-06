param(
    [string]$PortName = 'COM4',
    [int]$BaudRate = 115200,
    [int]$Seconds = 900,
    [string]$LogPath = '',
    [string]$ExpectedBanner = '',
    [string[]]$Inputs = @(),
    [switch]$ExitAfterInputs,
    [switch]$ReturnAfterInputs,
    [switch]$AttachAtPrompt
)

$serial = [System.IO.Ports.SerialPort]::new(
    $PortName, $BaudRate, [System.IO.Ports.Parity]::None, 8,
    [System.IO.Ports.StopBits]::One
)
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.Encoding = [System.Text.Encoding]::UTF8
$serial.ReadTimeout = 250
$writer = $null

try {
    if ($AttachAtPrompt -and $ExpectedBanner -ne '') { throw 'Attach and cold-boot banner modes are mutually exclusive' }
    $serial.Open()
    if ($LogPath -ne '') {
        $writer = [System.IO.StreamWriter]::new(
            $LogPath, $false, [System.Text.UTF8Encoding]::new($false)
        )
        $writer.AutoFlush = $true
    }
    Write-Output "CHAT_UART_STARTED port=$PortName baud=$BaudRate"
    $deadline = (Get-Date).AddSeconds($Seconds)
    $recent = ''
    $bannerSeen = $ExpectedBanner -eq ''
    $inputIndex = 0
    if ($AttachAtPrompt) { $serial.Write(([string][char]8)*512 + "/reset`r") }
    $sentExit = $false
    while ((Get-Date) -lt $deadline) {
        $chunk = $serial.ReadExisting()
        if ($chunk.Length -eq 0) {
            Start-Sleep -Milliseconds 50
            continue
        }
        [Console]::Out.Write($chunk)
        [Console]::Out.Flush()
        if ($null -ne $writer) { $writer.Write($chunk) }
        $recent += $chunk
        if (-not $bannerSeen -and $recent.Contains($ExpectedBanner)) {
            $bannerSeen = $true
            Write-Output "`nCHAT_UART_EXPECTED_BANNER_CONFIRMED"
        }
        if ($recent.Length -gt 128) {
            $recent = $recent.Substring($recent.Length - 128)
        }
        if ($bannerSeen -and $recent -match '(?:^|[\r\n])You> $') {
            $recent = ''
            if ($inputIndex -lt $Inputs.Length) {
                $line = $Inputs[$inputIndex]
                $inputIndex++
            } elseif ($ReturnAfterInputs) {
                Write-Output "`nCHAT_UART_RETURNED_AT_PROMPT"
                return
            } elseif ($ExitAfterInputs) {
                $line = '/exit'
                $sentExit = $true
            } else {
                $line = [Console]::ReadLine()
                if ($null -eq $line) { $line = '/exit' }
                if ($line -eq '/exit') { $sentExit = $true }
            }
            $serial.Write("$line`r")
            if ($sentExit) {
                Start-Sleep -Milliseconds 500
                $tail = $serial.ReadExisting()
                if ($tail.Length -gt 0) {
                    [Console]::Out.Write($tail)
                    if ($null -ne $writer) { $writer.Write($tail) }
                }
                Write-Output "`nCHAT_UART_EXITED"
                break
            }
        }
    }
    if (-not $sentExit) { Write-Output "`nCHAT_UART_TIMEOUT" }
} finally {
    if ($null -ne $writer) { $writer.Dispose() }
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
