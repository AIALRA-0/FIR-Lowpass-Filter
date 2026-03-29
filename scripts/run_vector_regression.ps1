param(
    [ValidateSet('l2', 'l3', 'l3_pipe')]
    [string]$Dut = 'l2',

    [ValidateSet('impulse', 'step', 'random_short', 'lane_alignment')]
    [string]$Case = 'impulse'
)

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$vivadoBin = if ($env:VIVADO_BIN) { $env:VIVADO_BIN } else { 'E:\Xilinx\Vivado\2024.1\bin' }
$xvlog = Join-Path $vivadoBin 'xvlog.bat'
$xelab = Join-Path $vivadoBin 'xelab.bat'
$xsim = Join-Path $vivadoBin 'xsim.bat'

if (-not (Test-Path $xvlog)) {
    throw "Vivado xvlog not found: $xvlog"
}

$caseFolder = switch ($Case) {
    'lane_alignment' {
        if ($Dut -eq 'l2') { 'lane_alignment_l2' } else { 'lane_alignment_l3' }
    }
    default { $Case }
}

$laneTag = if ($Dut -eq 'l2') { 'l2' } else { 'l3' }
$buildDir = Join-Path $repo ("build/sim/{0}_{1}" -f $Dut, $Case)
$stageDir = Join-Path $buildDir 'vectors/impulse'
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

$caseDir = Join-Path $repo ("vectors/{0}" -f $caseFolder)
$inputSrc = Join-Path $caseDir ("input_{0}.memh" -f $laneTag)
$goldenSrc = Join-Path $caseDir ("golden_{0}.memh" -f $laneTag)
Copy-Item $inputSrc (Join-Path $stageDir ("input_{0}.memh" -f $laneTag)) -Force
Copy-Item $goldenSrc (Join-Path $stageDir ("golden_{0}.memh" -f $laneTag)) -Force

$commonFiles = @(
    '../../../rtl/common/valid_pipe.v',
    '../../../rtl/common/delay_line.v',
    '../../../rtl/common/fir_delay_signed.v',
    '../../../rtl/common/preadd_mult.v',
    '../../../rtl/common/round_sat.v',
    '../../../rtl/common/fir_branch_core_symm.v',
    '../../../rtl/common/fir_branch_core_full.v'
)

$topFile = switch ($Dut) {
    'l2' { '../../../rtl/fir_l2_polyphase/fir_l2_polyphase.v' }
    'l3' { '../../../rtl/fir_l3_polyphase/fir_l3_polyphase.v' }
    'l3_pipe' { '../../../rtl/fir_l3_pipe/fir_l3_pipe.v' }
}

$xvlogArgs = @('-sv')
switch ($Dut) {
    'l3' { $xvlogArgs += @('-d', 'DUT_L3') }
    'l3_pipe' { $xvlogArgs += @('-d', 'DUT_L3_PIPE') }
}
$xvlogArgs += @('-i', '../../../rtl/common')
$xvlogArgs += $commonFiles
$xvlogArgs += @($topFile, '../../../tb/tb_fir_vector.sv')

Push-Location $buildDir
try {
    & $xvlog @xvlogArgs
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with code $LASTEXITCODE" }

    & $xelab -debug typical tb_fir_vector -s tb_fir_vector_snapshot
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with code $LASTEXITCODE" }

    & $xsim tb_fir_vector_snapshot -runall
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
