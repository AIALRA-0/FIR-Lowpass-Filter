param(
    [ValidateSet('fir_symm_base', 'fir_pipe_systolic', 'fir_l2_polyphase', 'fir_l3_polyphase', 'fir_l3_pipe', 'all')]
    [string]$Top = 'all'
)

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$vivadoBin = if ($env:VIVADO_BIN) { $env:VIVADO_BIN } else { 'E:\Xilinx\Vivado\2024.1\bin' }
$vivado = Join-Path $vivadoBin 'vivado.bat'

if (-not (Test-Path $vivado)) {
    throw "Vivado executable not found: $vivado"
}

$tops = if ($Top -eq 'all') {
    @('fir_symm_base', 'fir_pipe_systolic', 'fir_l2_polyphase', 'fir_l3_polyphase', 'fir_l3_pipe')
} else {
    @($Top)
}

$stageRoot = Join-Path $env:TEMP 'fir_impl_stage'
if (Test-Path $stageRoot) {
    Remove-Item -Recurse -Force $stageRoot
}
New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null
Copy-Item (Join-Path $repo 'rtl') (Join-Path $stageRoot 'rtl') -Recurse -Force
Copy-Item (Join-Path $repo 'vivado') (Join-Path $stageRoot 'vivado') -Recurse -Force

$scriptPath = Join-Path $stageRoot 'vivado/tcl/synth_one.tcl'
$repoBuild = Join-Path $repo 'build/vivado'
New-Item -ItemType Directory -Force -Path $repoBuild | Out-Null
$failures = @()

foreach ($topName in $tops) {
    Write-Host "=== Running staged Vivado implementation for $topName ==="
    $env:TOP = $topName
    $env:FIR_REPO_ROOT = $stageRoot
    $stageBuild = Join-Path $stageRoot ("build/vivado/{0}" -f $topName)
    New-Item -ItemType Directory -Force -Path $stageBuild | Out-Null
    $logPath = Join-Path $stageBuild 'vivado.log'
    $jouPath = Join-Path $stageBuild 'vivado.jou'
    & $vivado -mode batch -source $scriptPath -log $logPath -journal $jouPath
    $repoTopBuild = Join-Path $repoBuild $topName
    if (Test-Path $repoTopBuild) {
        Remove-Item -Recurse -Force $repoTopBuild
    }
    if (Test-Path $stageBuild) {
        Copy-Item $stageBuild $repoTopBuild -Recurse -Force
    }
    if ($LASTEXITCODE -ne 0) {
        $failures += $topName
        Write-Warning "Vivado failed for $topName with code $LASTEXITCODE"
    }
}

Push-Location $repo
try {
    python scripts/collect_impl_results.py
    if ($LASTEXITCODE -ne 0) {
        throw "collect_impl_results.py failed with code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

if ($failures.Count -gt 0) {
    throw ("Vivado implementation failed for: " + ($failures -join ', '))
}
