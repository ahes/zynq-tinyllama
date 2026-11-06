param(
    [ValidateSet('All','RTL','Hardware','Software','Model','Package')][string]$Stage = 'All',
    [string]$VivadoRoot = $env:XILINX_VIVADO,
    [string]$VitisRoot = $env:XILINX_VITIS,
    [string]$SbtCommand = 'sbt',
    [string]$ModelPython = 'python',
    [string]$PythonCommand = 'python',
    [switch]$DownloadModel
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Path (Join-Path $root 'build') -Force | Out-Null
function Run-Step([string]$Executable, [string[]]$Arguments, [string]$Log) {
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments 2>&1 | Tee-Object -FilePath (Join-Path $root ('build/' + $Log))
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $oldPreference }
    if($code -ne 0) { throw "Build command failed; see build/$Log" }
}
Push-Location $root
try {
    if($Stage -in @('All','RTL')) {
        $names = @('EDGELLM_TARGET','EDGELLM_DIAG_MLP','EDGELLM_MLP_SCALE_SHIFT','EDGELLM_REPETITION_PENALTY')
        $saved = @{}
        foreach($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
        try {
            $env:EDGELLM_TARGET='zynq7035'; $env:EDGELLM_DIAG_MLP='1'
            $env:EDGELLM_MLP_SCALE_SHIFT='4'; $env:EDGELLM_REPETITION_PENALTY='1'
            Push-Location (Join-Path $root 'llama-fpga/scala')
            try { Run-Step $SbtCommand @('runMain top.EdgeLLMInst') 'scala_generation.log' }
            finally { Pop-Location }
        } finally {
            foreach($name in $names) { [Environment]::SetEnvironmentVariable($name,$saved[$name]) }
        }
        Run-Step $PythonCommand @('scripts/compare_rtl.py') 'rtl_comparison.log'
    }
    if($Stage -in @('All','Hardware')) {
        if(-not $VivadoRoot) { throw 'Provide -VivadoRoot (Vivado 2021.1)' }
        Run-Step (Join-Path $VivadoRoot 'bin/vivado.bat') @('-mode','batch','-nojournal','-nolog','-source','hardware/build.tcl') 'hardware_build.log'
    }
    if($Stage -in @('All','Software')) {
        if(-not $VitisRoot) { throw 'Provide -VitisRoot (Vitis 2021.1)' }
        Run-Step (Join-Path $VitisRoot 'bin/xsct.bat') @('scripts/build_software.tcl') 'software_build.log'
    }
    if($Stage -in @('All','Model')) {
        $modelArgs = @('-u','scripts/rebuild_model.py')
        if($DownloadModel) { $modelArgs += '--download' }
        Run-Step $ModelPython $modelArgs 'model_build.log'
    }
    if($Stage -in @('All','Package')) {
        if(-not $VivadoRoot) { throw 'Provide -VivadoRoot (Vivado 2021.1)' }
        Run-Step $PythonCommand @('scripts/package_boot.py','--bootgen',(Join-Path $VivadoRoot 'bin/bootgen.bat')) 'package.log'
    }
} finally { Pop-Location }
Write-Output "REPRO_BUILD_STAGE_COMPLETE=$Stage; cold board validation is a separate physical step"
