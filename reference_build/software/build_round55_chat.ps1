param([string]$VitisRoot = 'D:/Xilinx/Vitis/2021.1', [string]$VivadoRoot = 'D:/Xilinx/Vivado/2021.1', [switch]$CompileOnly)
$ErrorActionPreference = 'Stop'
$portRoot = Split-Path $PSScriptRoot -Parent
$snapshot = Join-Path $portRoot 'build/round52_validated_baseline_20261022'
$out = Join-Path $portRoot 'build/round55_dialogue_diagnosis_20261101'
$source = Join-Path $PSScriptRoot 'round55/main.c'
$bsp = Join-Path $PSScriptRoot 'vitis_workspace/llama7035_platform/export/llama7035_platform/sw/llama7035_platform/standalone_domain'
$app = Join-Path $PSScriptRoot 'vitis_workspace/llama7035_loader'
$toolBin = Join-Path $VitisRoot 'gnu/aarch32/nt/gcc-arm-none-eabi/bin'
$gcc = Join-Path $toolBin 'arm-none-eabi-gcc.exe'
$elf = Join-Path $out 'llama7035_loader_round55_chat128.elf'
$boot = Join-Path $out 'BOOT_round55_dialogue_diagnosis_20261101.BIN'
$bit = Join-Path $out 'llama_zynq7035_round55.bit'
$fsbl = Join-Path $snapshot 'software/zynq7035_fsbl.elf'
$pins = @(
    @{Path=$fsbl;Hash='01F095D3B63BE4A67C0121766D4191C38B16842973E2F405CD2901A7F892C22F'}
)
foreach ($pin in $pins) {
    if ((Get-FileHash -LiteralPath $pin.Path -Algorithm SHA256).Hash -ne $pin.Hash) { throw "Round52 dependency hash mismatch: $($pin.Path)" }
}
New-Item -ItemType Directory -Path $out -Force | Out-Null
# Build directly into Round55; do not clean/rebuild the shared Vitis app or overwrite its ELF.
Copy-Item -LiteralPath $source -Destination (Join-Path $out 'main.c')
Copy-Item -LiteralPath (Join-Path $app 'src/lscript.ld') -Destination (Join-Path $out 'lscript.ld')
Copy-Item -LiteralPath (Join-Path $app 'Debug/Xilinx.spec') -Destination (Join-Path $out 'Xilinx.spec')
$arch = @('-mcpu=cortex-a9','-mfpu=vfpv3','-mfloat-abi=hard')
$compileArgs = @('-DZYNQ7035','-DMAX_DECODE_TOKENS=128','-Wall','-Wextra','-Werror','-O0','-g3','-c','-fmessage-length=0') + $arch + @(
    ('-I' + (Join-Path $bsp 'bspinclude/include')), '-o', (Join-Path $out 'main.o'), (Join-Path $out 'main.c')
)
$buildLog = Join-Path $out 'build.log'
@('Round55 standalone PS build', ('Compiler: ' + $gcc), ('Compile arguments: ' + ($compileArgs -join ' '))) |
    Set-Content -LiteralPath $buildLog -Encoding UTF8
& $gcc @compileArgs 2>&1 | Tee-Object -FilePath $buildLog -Append
if ($LASTEXITCODE -ne 0) { throw 'Round55 ARM compilation failed' }
$linkArgs = $arch + @('-Wl,-build-id=none', ('-specs=' + (Join-Path $out 'Xilinx.spec')),
    '-Wl,-T', ('-Wl,' + (Join-Path $out 'lscript.ld')), ('-Wl,-Map=' + (Join-Path $out 'round55.map')),
    ('-L' + (Join-Path $bsp 'bsplib/lib')), '-o', $elf, (Join-Path $out 'main.o'),
    '-Wl,--start-group,-lxil,-lgcc,-lc,--end-group', '-Wl,--start-group,-lxilffs,-lxil,-lgcc,-lc,--end-group')
('Link arguments: ' + ($linkArgs -join ' ')) | Add-Content -LiteralPath $buildLog -Encoding UTF8
& $gcc @linkArgs 2>&1 | Tee-Object -FilePath $buildLog -Append
if ($LASTEXITCODE -ne 0) { throw 'Round55 ARM link failed' }
& (Join-Path $toolBin 'arm-none-eabi-size.exe') $elf | Tee-Object -FilePath (Join-Path $out 'elf_size.txt')
if ($LASTEXITCODE -ne 0) { throw 'Round55 ELF size inspection failed' }
if ($CompileOnly) {
    (Get-FileHash -LiteralPath $elf -Algorithm SHA256).Hash | Set-Content -LiteralPath ($elf + '.sha256') -Encoding ASCII
    Write-Output "ROUND55_PS_ELF_BUILT=$elf"
    return
}
$hardware = Get-Content -LiteralPath (Join-Path $out 'hardware_hashes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ((Get-FileHash -LiteralPath $bit -Algorithm SHA256).Hash -ne $hardware.bit_sha256) { throw 'Round55 bitstream hash mismatch' }
$bif = Join-Path $out 'round55.bif'
@("the_ROM_image:", '{', ('  [bootloader] "' + $fsbl.Replace('\','/') + '"'),
    ('  "' + $bit.Replace('\','/') + '"'), ('  "' + $elf.Replace('\','/') + '"'), '}') |
    Set-Content -LiteralPath $bif -Encoding ASCII
& (Join-Path $VivadoRoot 'bin/bootgen.bat') -arch zynq -image $bif -o $boot -w on 2>&1 |
    Tee-Object -FilePath (Join-Path $out 'bootgen.log')
if ($LASTEXITCODE -ne 0) { throw 'Round55 Bootgen packaging failed' }
& (Join-Path $VivadoRoot 'bin/bootgen.bat') -arch zynq -read $boot 2>&1 |
    Tee-Object -FilePath (Join-Path $out 'boot_header.log')
if ($LASTEXITCODE -ne 0) { throw 'Round55 boot header inspection failed' }
$manifest = @{}
foreach ($path in @($source,$elf,$boot,$bit,$fsbl,(Join-Path $out 'main.c'),(Join-Path $out 'lscript.ld'),(Join-Path $out 'Xilinx.spec'),$PSCommandPath)) {
    $manifest[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'build_hashes.json') -Encoding UTF8
(Get-FileHash -LiteralPath $boot -Algorithm SHA256).Hash | Set-Content -LiteralPath ($boot + '.sha256') -Encoding ASCII
Write-Output "ROUND55_PACKAGED=$boot"
Write-Output 'BOARD_VALIDATION=PENDING; CURRENT_BASELINE remains Round52'

