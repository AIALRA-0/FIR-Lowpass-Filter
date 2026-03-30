param(
    [ValidateSet('fir_pipe_systolic', 'vendor_fir_ip', 'all')]
    [string]$Arch = 'all',
    [string]$ComPort = 'COM9',
    [int]$MaxAttempts = 2,
    [switch]$ForceHardwareBuild,
    [switch]$ForceAppBuild,
    [string]$VivadoBin = $(if ($env:VIVADO_BIN) { $env:VIVADO_BIN } else { 'E:\Xilinx\Vivado\2024.1\bin' }),
    [string]$XsctBin = $(if ($env:XSCT_BIN) { $env:XSCT_BIN } else { 'E:\Xilinx\Vitis\2024.1\bin\xsct.bat' }),
    [string]$PythonExe = $(if ($env:PYTHON_EXE) { $env:PYTHON_EXE } else { 'python' })
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath

$archMeta = @{
    fir_pipe_systolic = @{
        system_top = 'zu4ev_fir_pipe_systolic_top'
        build_tcl = Join-Path $repo 'vivado\tcl\zu4ev\build_zu4ev_system.tcl'
        xsa = Join-Path $repo 'build\zu4ev_system\zu4ev_fir_pipe_systolic_top\zu4ev_fir_pipe_systolic_top.xsa'
        arch_id = 1
    }
    vendor_fir_ip = @{
        system_top = 'zu4ev_fir_vendor_top'
        build_tcl = Join-Path $repo 'vivado\tcl\zu4ev\build_vendor_system.tcl'
        xsa = Join-Path $repo 'build\zu4ev_system\zu4ev_fir_vendor_top\zu4ev_fir_vendor_top.xsa'
        arch_id = 5
    }
}

function Invoke-Preflight {
    if (-not (Get-Command $PythonExe -ErrorAction SilentlyContinue)) {
        throw "Python executable not found: $PythonExe"
    }
    if (-not (Test-Path (Join-Path $VivadoBin 'vivado.bat'))) {
        throw "Vivado not found under $VivadoBin"
    }
    if (-not (Test-Path $XsctBin)) {
        throw "XSCT not found: $XsctBin"
    }
    $portNames = [System.IO.Ports.SerialPort]::GetPortNames()
    if ($portNames -notcontains $ComPort) {
        throw "$ComPort is not present. Keep the CP210x UART connected."
    }
    & (Join-Path $repo 'scripts\check_jtag_stack.ps1') -VivadoBin $VivadoBin | Out-Host
    $jtagJson = Join-Path $repo 'data\hardware\jtag_status.json'
    if (-not (Test-Path $jtagJson)) {
        throw "Missing JTAG status JSON: $jtagJson"
    }
    $jtag = Get-Content -Raw $jtagJson | ConvertFrom-Json
    $hasZu4 = @($jtag.hw_devices | Where-Object { $_.part -eq 'xczu4' }).Count -gt 0
    if (-not $hasZu4) {
        throw "Preflight failure: check_jtag_stack did not see xczu4."
    }
}

function Invoke-HardwareBuild([string]$targetArch) {
    $meta = $archMeta[$targetArch]
    if ((-not $ForceHardwareBuild) -and (Test-Path $meta.xsa)) {
        return
    }
    $vivadoBat = Join-Path $VivadoBin 'vivado.bat'
    $logDir = Join-Path $repo 'build\closure_logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $logPath = Join-Path $logDir "$targetArch-vivado.log"
    if ($targetArch -eq 'fir_pipe_systolic') {
        $env:SYSTEM_TOP = $meta.system_top
    }
    try {
        & $vivadoBat -mode batch -nolog -nojournal -notrace -source $meta.build_tcl 2>&1 | Tee-Object -FilePath $logPath | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Vivado system build failed for $targetArch. See $logPath"
        }
    } finally {
        Remove-Item Env:\SYSTEM_TOP -ErrorAction SilentlyContinue
    }
}

function Invoke-ClosureRun([string]$targetArch) {
    $meta = $archMeta[$targetArch]
    Invoke-HardwareBuild $targetArch

    $buildInfoPath = Join-Path (Join-Path (Join-Path 'C:\codex_stage\zu4ev_closure' $targetArch) 'artifacts') 'build_info.json'
    if ($ForceAppBuild -or -not (Test-Path $buildInfoPath)) {
        $buildArgs = @{
            XsaPath = $meta.xsa
            Arch = $targetArch
            XsctBin = $XsctBin
        }
        if ($ForceHardwareBuild) {
            $buildArgs.ForcePlatformRegen = $true
        }
        & (Join-Path $repo 'scripts\build_zu4ev_app.ps1') @buildArgs | Out-Host
    }
    if (-not (Test-Path $buildInfoPath)) {
        throw "Missing build info after app build: $buildInfoPath"
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $runDir = Join-Path $repo "data\board_runs\$targetArch\$timestamp"
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    $uartLog = Join-Path $runDir 'uart.log'
    $uartJson = Join-Path $runDir 'uart.json'

    $captureJob = Start-Job -ScriptBlock {
        param($pythonExe, $repoRoot, $portName, $logPath, $jsonPath)
        & $pythonExe (Join-Path $repoRoot 'scripts\capture_uart.py') '--port' $portName '--log' $logPath '--json' $jsonPath
        exit $LASTEXITCODE
    } -ArgumentList $PythonExe, $repo, $ComPort, $uartLog, $uartJson

    Start-Sleep -Seconds 2
    try {
        & (Join-Path $repo 'scripts\program_zu4ev.ps1') -BuildInfoPath $buildInfoPath -VivadoBin $VivadoBin -XsctBin $XsctBin | Out-Host
        Wait-Job -Job $captureJob -Timeout 240 | Out-Null
        Receive-Job -Job $captureJob -Keep | Out-Host
        if ($captureJob.State -ne 'Completed') {
            throw "UART capture job did not complete cleanly for $targetArch"
        }
    } finally {
        if ($captureJob) {
            if ($captureJob.State -eq 'Running') {
                Stop-Job -Job $captureJob
            }
            Receive-Job -Job $captureJob -ErrorAction SilentlyContinue | Out-Null
            Remove-Job -Job $captureJob -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path $uartJson)) {
        throw "UART capture did not produce $uartJson"
    }

    $result = Get-Content -Raw $uartJson | ConvertFrom-Json
    if (-not $result.passed) {
        $failureClass = if ($result.failure_class) { [string]$result.failure_class } else { 'unknown_failure' }
        throw "Board run failed for $targetArch ($failureClass). See $runDir"
    }

    Write-Host "PASS $targetArch ($runDir)"
}

Invoke-Preflight

$targets = if ($Arch -eq 'all') { @('fir_pipe_systolic', 'vendor_fir_ip') } else { @($Arch) }
foreach ($targetArch in $targets) {
    $attempt = 1
    $passed = $false
    while (($attempt -le $MaxAttempts) -and (-not $passed)) {
        try {
            Invoke-ClosureRun $targetArch
            $passed = $true
        } catch {
            if ($attempt -ge $MaxAttempts) {
                throw
            }
            Start-Sleep -Seconds 3
        }
        $attempt += 1
    }
}

Push-Location $repo
try {
    & $PythonExe 'scripts/collect_board_results.py'
    if ($LASTEXITCODE -ne 0) {
        throw "collect_board_results.py failed with code $LASTEXITCODE"
    }
    & $PythonExe 'scripts/collect_board_stability.py'
    if ($LASTEXITCODE -ne 0) {
        throw "collect_board_stability.py failed with code $LASTEXITCODE"
    }
    & $PythonExe 'scripts/collect_impl_results.py'
    if ($LASTEXITCODE -ne 0) {
        throw "collect_impl_results.py failed with code $LASTEXITCODE"
    }
    & $PythonExe 'scripts/collect_analysis_metrics.py'
    if ($LASTEXITCODE -ne 0) {
        throw "collect_analysis_metrics.py failed with code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
