param(
    [Parameter(Mandatory=$true)][string]$VivadoRoot,
    [string]$PythonCommand = 'python',
    [switch]$Regenerate,
    [string]$SbtCommand = 'sbt'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $root 'build/decode_regression'
$fixture = Join-Path $root 'zynq7035_port/build/round55_dialogue_diagnosis_20261101'
$xvlog = Join-Path $VivadoRoot 'bin/xvlog.bat'
$xelab = Join-Path $VivadoRoot 'bin/xelab.bat'
$xsim = Join-Path $VivadoRoot 'bin/xsim.bat'
$generated = Join-Path $root 'tests/generated'
if($Regenerate) {
    $generated = Join-Path $root 'build/test_rtl'
    New-Item -ItemType Directory -Path $generated -Force | Out-Null
    $previousSimDir = $env:ROUND55_SIM_DIR
    $env:ROUND55_SIM_DIR = $generated.Replace('\','/')
    Push-Location (Join-Path $root 'llama-fpga/scala')
    try {
        & $SbtCommand 'Test / runMain mlp.RepetitionPenaltyHarness' 'Test / runMain mlp.SamplerPolicyHarness' 'Test / runMain mlp.SamplerPolicySmallHarness' 2>&1 |
            Tee-Object -FilePath (Join-Path $root 'build/test_scala_generation.log')
        if($LASTEXITCODE -ne 0) { throw 'Test harness regeneration failed' }
    } finally {
        Pop-Location
        $env:ROUND55_SIM_DIR = $previousSimDir
    }
}
foreach($tool in @($xvlog,$xelab,$xsim)) {
    if(-not (Test-Path -LiteralPath $tool)) { throw "Missing simulator tool: $tool" }
}
New-Item -ItemType Directory -Path (Join-Path $fixture 'sampler_sim') -Force | Out-Null
& $PythonCommand (Join-Path $root 'zynq7035_port/software/round55/prepare_penalty_fixture.py')
if($LASTEXITCODE -ne 0) { throw 'Penalty oracle generation failed' }
& $PythonCommand (Join-Path $root 'zynq7035_port/software/round55/prepare_sampler_fixture.py')
if($LASTEXITCODE -ne 0) { throw 'Sampler oracle generation failed' }
$cases = @(
    @{Name='penalty';Rtl='RepetitionPenaltyHarness.v';Tb='repetition_penalty_tb.sv';Fixture='sampler_sim';Marker='REPETITION_PENALTY_EXHAUSTIVE_PASS count=65536';Small=$false},
    @{Name='full';Rtl='SamplerPolicyHarness.v';Tb='sampler_policy_tb.sv';Fixture='sampler_sim';Marker='SAMPLER_POLICY_PASS vocab=32000 rows=12';Small=$false},
    @{Name='window';Rtl='SamplerPolicySmallHarness.v';Tb='sampler_policy_tb.sv';Fixture='sampler_small_sim';Marker='SAMPLER_POLICY_PASS vocab=64 rows=140';Small=$true}
)
foreach($case in $cases) {
    $dir = Join-Path $out $case.Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $generated $case.Rtl) -Destination $dir
    Copy-Item -LiteralPath (Join-Path $root ('llama-fpga/scala/src/test/resources/' + $case.Tb)) -Destination $dir
    $hexNames = if($case.Name -eq 'penalty') { @('penalty_expected.hex') } else { @('sampler_logits.hex','sampler_expected.hex') }
    foreach($hex in $hexNames) { Copy-Item -LiteralPath (Join-Path (Join-Path $fixture $case.Fixture) $hex) -Destination $dir }
    Push-Location $dir
    try {
        $compile = @('--sv', $case.Rtl, $case.Tb)
        if($case.Small) { $compile += @('-d','SMALL_VOCAB') }
        & $xvlog @compile
        if($LASTEXITCODE -ne 0) { throw ('Compile failed: ' + $case.Name) }
        $top = [IO.Path]::GetFileNameWithoutExtension($case.Tb)
        & $xelab $top -s decode_test --mt 2
        if($LASTEXITCODE -ne 0) { throw ('Elaboration failed: ' + $case.Name) }
        & $xsim decode_test -runall -log simulation.log
        if($LASTEXITCODE -ne 0) { throw ('Simulation failed: ' + $case.Name) }
        $log = Get-Content -LiteralPath simulation.log -Raw
        if($log -match 'Fatal:|Error:' -or -not $log.Contains($case.Marker)) { throw ('Missing PASS: ' + $case.Name) }
        Write-Output ('DECODE_REGRESSION_PASS=' + $case.Name)
    } finally { Pop-Location }
}
Write-Output 'DECODE_REGRESSION=PASS_3_GENERATED_RTL_CASES'
