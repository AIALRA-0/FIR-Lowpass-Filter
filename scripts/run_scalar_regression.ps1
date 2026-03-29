param(
    [ValidateSet('base', 'pipe')]
    [string]$Dut = 'base',

    [ValidateSet('impulse', 'step', 'random_short')]
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

$buildDir = Join-Path $repo ("build/sim/{0}_{1}" -f $Dut, $Case)
$stageDir = Join-Path $buildDir 'vectors/impulse'
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

switch ($Case) {
    'impulse' {
        Copy-Item (Join-Path $repo 'vectors/impulse/input_scalar.memh') (Join-Path $stageDir 'input_scalar.memh') -Force
        Copy-Item (Join-Path $repo 'vectors/impulse/golden_scalar.memh') (Join-Path $stageDir 'golden_scalar.memh') -Force
    }
    'step' {
        Copy-Item (Join-Path $repo 'vectors/step/input_scalar.memh') (Join-Path $stageDir 'input_scalar.memh') -Force
        Copy-Item (Join-Path $repo 'vectors/step/golden_scalar.memh') (Join-Path $stageDir 'golden_scalar.memh') -Force
    }
    'random_short' {
        @"
from pathlib import Path
import numpy as np
from scripts.regenerate_vectors import load_json, load_selected_coeffs, quantize_signed_frac, round_away_from_zero

root = Path(r"$repo")
spec = load_json(root / "spec" / "spec.json")
coeffs_q, summary = load_selected_coeffs()
coef_width = int(summary["coef_width"])
output_width = int(summary["output_width"])
input_width = int(spec["fixed_point"]["input_width"])
coeff_int = quantize_signed_frac(coeffs_q, coef_width, coef_width - 1)

def decode_memh(path, width, count):
    vals = []
    for line in path.read_text().splitlines()[:count]:
        v = int(line.strip(), 16)
        if v >= 2 ** (width - 1):
            v -= 2 ** width
        vals.append(v)
    return np.array(vals, dtype=np.int64)

def twos_hex(value, width):
    if value < 0:
        value += 1 << width
    digits = (width + 3) // 4
    return f"{value:0{digits}X}"

input_int = decode_memh(root / "vectors" / "random" / "input_scalar.memh", input_width, 1024)
full_conv = np.convolve(input_int.astype(np.float64), coeff_int.astype(np.float64))
rounded = round_away_from_zero(full_conv / float(2 ** (coef_width - 1))).astype(np.int64)
out_min = -(2 ** (output_width - 1))
out_max = 2 ** (output_width - 1) - 1
output_int = np.clip(rounded, out_min, out_max)

stage_dir = root / "build" / "sim" / "${Dut}_${Case}" / "vectors" / "impulse"
stage_dir.mkdir(parents=True, exist_ok=True)
(stage_dir / "input_scalar.memh").write_text("\n".join(twos_hex(int(v), input_width) for v in input_int) + "\n", encoding="ascii")
(stage_dir / "golden_scalar.memh").write_text("\n".join(twos_hex(int(v), output_width) for v in output_int) + "\n", encoding="ascii")
"@ | python -
    }
}

$commonFiles = @(
    '../../../rtl/common/valid_pipe.v',
    '../../../rtl/common/delay_line.v',
    '../../../rtl/common/fir_delay_signed.v',
    '../../../rtl/common/preadd_mult.v',
    '../../../rtl/common/round_sat.v'
)

$topFile = if ($Dut -eq 'pipe') {
    '../../../rtl/fir_pipe_systolic/fir_pipe_systolic.v'
} else {
    '../../../rtl/fir_symm_base/fir_symm_base.v'
}

$xvlogArgs = @('-sv')
if ($Dut -eq 'pipe') {
    $xvlogArgs += @('-d', 'DUT_PIPE')
}
$xvlogArgs += @('-i', '../../../rtl/common')
$xvlogArgs += $commonFiles
$xvlogArgs += @($topFile, '../../../tb/tb_fir_scalar.sv')

Push-Location $buildDir
try {
    & $xvlog @xvlogArgs
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed with code $LASTEXITCODE" }

    & $xelab -debug typical tb_fir_scalar -s tb_fir_scalar_snapshot
    if ($LASTEXITCODE -ne 0) { throw "xelab failed with code $LASTEXITCODE" }

    & $xsim tb_fir_scalar_snapshot -runall
    if ($LASTEXITCODE -ne 0) { throw "xsim failed with code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
