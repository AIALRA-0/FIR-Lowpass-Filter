param(
    [string]$VivadoBin = $(if ($env:VIVADO_BIN) { $env:VIVADO_BIN } else { 'E:\Xilinx\Vivado\2024.1\bin' }),
    [string]$HwServerUrl = 'localhost:3121'
)

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$hwServerBat = Join-Path $VivadoBin 'hw_server.bat'
$vivadoBat = Join-Path $VivadoBin 'vivado.bat'
$digilentInstaller = Join-Path $VivadoBin '..\data\xicom\cable_drivers\nt64\digilent\install_digilent.exe'

if (-not (Test-Path $hwServerBat)) {
    throw "hw_server not found: $hwServerBat"
}
if (-not (Test-Path $vivadoBat)) {
    throw "vivado.bat not found: $vivadoBat"
}

$devicePattern = 'VID_0403&PID_6014|VID_1A86&PID_7523'
$presentDevices =
    Get-PnpDevice -PresentOnly |
    Where-Object { $_.InstanceId -match $devicePattern } |
    ForEach-Object {
        $dev = $_
        [pscustomobject]@{
            friendly_name = $dev.FriendlyName
            class = $dev.Class
            status = $dev.Status
            instance_id = $dev.InstanceId
            driver_inf = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction SilentlyContinue).Data
            provider = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_DriverProvider' -ErrorAction SilentlyContinue).Data
            service = (Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction SilentlyContinue).Data
        }
    }

$driverLines =
    (& pnputil /enum-drivers) |
    Select-String -Pattern 'digiftdibus|digiftdiport|ftdibus.inf|ftdiport.inf|xpcwinusb|windrvr6|Provider Name:\s+Digilent|Provider Name:\s+FTDI|Provider Name:\s+Xilinx' -Context 0,1 |
    ForEach-Object { $_.ToString().Trim() }

$probeTcl = Join-Path $repo 'scripts\query_hw_targets.tcl'
$probeOutput = @()
$hwServerProc = $null

try {
    $hwServerProc = Start-Process -FilePath $hwServerBat -ArgumentList '-s',("tcp::" + ($HwServerUrl -replace '^.*:','')) -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 3
    $env:HW_SERVER_URL = $HwServerUrl
    $cmdLine = "`"$vivadoBat`" -mode batch -nolog -nojournal -notrace -source `"$probeTcl`" 2>&1"
    $probeOutput = & cmd.exe /c $cmdLine
}
finally {
    if ($hwServerProc -and -not $hwServerProc.HasExited) {
        Stop-Process -Id $hwServerProc.Id -Force
    }
}

$targets = @()
$devices = @()
$serverUrlSeen = $HwServerUrl
$targetCount = 0

foreach ($lineObj in $probeOutput) {
    $line = [string]$lineObj
    if ($line.StartsWith('HW_QUERY|server_url|')) {
        $serverUrlSeen = $line.Split('|')[2]
    } elseif ($line.StartsWith('HW_QUERY|target_count|')) {
        $targetCount = [int]$line.Split('|')[2]
    } elseif ($line.StartsWith('HW_TARGET|')) {
        $parts = $line.Split('|')
        $targets += [pscustomobject]@{
            target = $parts[1]
            open_rc = [int]$parts[2]
            open_msg = $parts[3]
            device_count = [int]$parts[4]
        }
    } elseif ($line.StartsWith('HW_DEVICE|')) {
        $parts = $line.Split('|')
        $devices += [pscustomobject]@{
            target = $parts[1]
            hw_device = $parts[2]
            part = $parts[3]
            idcode = $parts[4]
        }
    }
}

$diagnosis = @()
if ($targetCount -eq 0) {
    $diagnosis += 'hw_server did not enumerate any target. Check USB cable visibility and driver binding first.'
} elseif (($targets | Measure-Object -Property device_count -Sum).Sum -eq 0) {
    $diagnosis += 'hw_server can see Digilent targets, but open_hw_target found no devices. This points to an empty JTAG chain, cable orientation issue, wrong header, bad board seating, wrong boot mode, or board power problem.'
} else {
    $diagnosis += 'At least one JTAG target returned a device. Driver and chain basics are alive.'
}
if ($presentDevices | Where-Object { $_.instance_id -match 'VID_1A86&PID_7523' }) {
    $diagnosis += 'CH340 is UART only and is not part of the JTAG path.'
}
if ($presentDevices | Where-Object { $_.instance_id -match 'VID_0403&PID_6014' -and $_.provider -eq 'FTDI' }) {
    $diagnosis += 'The FTDI devices are currently bound to the generic FTDI driver. That is not necessarily the main blocker if hw_server already enumerates Digilent targets.'
}

$status = [ordered]@{
    checked_at = (Get-Date).ToString('s')
    vivado_bin = $VivadoBin
    hw_server = $hwServerBat
    vivado = $vivadoBat
    digilent_installer = $(if (Test-Path $digilentInstaller) { (Resolve-Path $digilentInstaller).ProviderPath } else { '' })
    hw_server_url = $serverUrlSeen
    present_devices = $presentDevices
    installed_driver_hints = $driverLines
    hw_targets = $targets
    hw_devices = $devices
    diagnosis = $diagnosis
}

$dataDir = Join-Path $repo 'data\hardware'
$reportDir = Join-Path $repo 'reports'
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$jsonPath = Join-Path $dataDir 'jtag_status.json'
$reportPath = Join-Path $reportDir 'jtag_status.md'

$status | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding utf8

$lines = @(
    '# JTAG Status',
    '',
    "Checked at: $($status.checked_at)",
    '',
    '## Toolchain',
    '',
    "- Vivado bin: $VivadoBin",
    "- hw_server: $hwServerBat",
    "- Digilent installer: $($status.digilent_installer)",
    '',
    '## Present USB Devices',
    ''
)

foreach ($dev in $presentDevices) {
    $lines += "- $(($dev.friendly_name)) | class=$(($dev.class)) | provider=$(($dev.provider)) | inf=$(($dev.driver_inf)) | service=$(($dev.service)) | instance=$(($dev.instance_id))"
}

$lines += @(
    '',
    '## Installed Driver Hints',
    ''
)
foreach ($line in $driverLines) {
    $lines += "- $line"
}

$lines += @(
    '',
    '## hw_server Probe',
    '',
    "- server_url: $serverUrlSeen",
    "- target_count: $targetCount",
    ''
)
foreach ($target in $targets) {
    $lines += "- $(($target.target)) | open_rc=$(($target.open_rc)) | device_count=$(($target.device_count)) | message=$(($target.open_msg))"
}

if ($devices.Count -gt 0) {
    $lines += @('', '## Enumerated Devices', '')
    foreach ($dev in $devices) {
        $lines += "- $(($dev.target)) | part=$(($dev.part)) | idcode=$(($dev.idcode))"
    }
}

$lines += @('', '## Diagnosis', '')
foreach ($item in $diagnosis) {
    $lines += "- $item"
}

$lines += @(
    '',
    '## Next Actions',
    '',
    '- Physically isolate the two FTDI cables. Unplug one, rerun this script, and identify which serial belongs to the 7z020 board.',
    '- Verify 14-pin JTAG ribbon orientation and pin-1 alignment on the baseboard header.',
    '- Confirm JTAG boot mode from board docs: BOOT_MODE0=ON and BOOT_MODE1=ON.',
    '- Keep only 12V power and the 14-pin JTAG cable during bring-up. Treat CH340 as unrelated UART.',
    '- If hw_server still sees targets but device_count=0, focus on cable/header/core-board seating and JTAG chain continuity before reinstalling drivers.',
    '- Reinstall drivers only if hw_server stops enumerating the Digilent targets at all.'
)

$lines | Set-Content -Path $reportPath -Encoding utf8

Write-Host "Wrote $jsonPath"
Write-Host "Wrote $reportPath"
