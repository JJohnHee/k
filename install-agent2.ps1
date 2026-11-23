# install-agent2.ps1 - clawsos daemon installer, all files from jsdelivr
param([string]$NodeName = $env:COMPUTERNAME)
$ErrorActionPreference = 'Continue'
$dir = 'C:\piagent'
$ws = 'C:\clawsos_ws'
New-Item -ItemType Directory -Force -Path $dir, $ws | Out-Null
$M = @('https://testingcf.jsdelivr.net/gh/jjohnhee/k', 'https://gcore.jsdelivr.net/gh/jjohnhee/k', 'https://fastly.jsdelivr.net/gh/jjohnhee/k')
function GetF($name, $minMB) {
  $f = Join-Path $dir $name
  foreach ($m in $M) {
    curl.exe -sS -o $f ($m + '/' + $name)
    if ((Test-Path $f) -and ((Get-Item $f).Length -gt ($minMB * 1MB))) { return $true }
  }
  return $false
}
# 1) daemon package 15MB
$pkgOk = (Test-Path 'C:\clawsos-daemon\dist\index.mjs')
if (-not $pkgOk) {
  if (GetF 'daemon-pkg.zip' 14) {
    Expand-Archive -Path (Join-Path $dir 'daemon-pkg.zip') -DestinationPath 'C:\clawsos-daemon' -Force
    $pkgOk = Test-Path 'C:\clawsos-daemon\dist\index.mjs'
  }
}
# 2) node (two parts, binary concat)
$nodeOk = $false
if (-not (Test-Path (Join-Path $dir 'node.exe'))) {
  $p1 = Join-Path $dir 'node.zip.part-aa'
  $p2 = Join-Path $dir 'node.zip.part-ab'
  $ok1 = (Test-Path $p1) -or (GetF 'node.zip.part-aa' 16)
  $ok2 = (Test-Path $p2) -or (GetF 'node.zip.part-ab' 15)
  if ($ok1 -and $ok2) {
    cmd /c ('copy /b "' + $p1 + '"+"' + $p2 + '" "' + (Join-Path $dir 'node.zip') + '"') | Out-Null
    if (Test-Path (Join-Path $dir 'node.zip')) { Expand-Archive -Path (Join-Path $dir 'node.zip') -DestinationPath $dir -Force }
  }
}
if (Test-Path (Join-Path $dir 'node.exe')) { $nodeOk = ((& (Join-Path $dir 'node.exe') --version 2>$null) -match 'v\d') }
# 3) bat + tasks
$bat = "@echo off`r`nset CLAWSGO_API_URL=http://100.94.124.54:8778`r`nset CLAWSGO_DEVICE_TOKEN=clawsgo-device-d63fd189-5828-4fa0-ac25-ec29d733a887`r`nset CLAWSGO_WORKSPACE_ROOT=C:/clawsos_ws`r`nC:\piagent\node.exe C:\clawsos-daemon\dist\index.mjs"
Set-Content -Path 'C:\clawsos-daemon\start-daemon.bat' -Value $bat -Encoding ASCII
$wd = "$dir\watchdog.cmd"
Set-Content -Path $wd -Value "@echo off`r`ntasklist /FI `"IMAGENAME eq node.exe`" | findstr node >nul 2>&1 || start `"`" /MIN C:\clawsos-daemon\start-daemon.bat" -Encoding ASCII
schtasks /Create /TN clawsos-daemon /SC ONSTART /TR "C:\clawsos-daemon\start-daemon.bat" /RU SYSTEM /RL HIGHEST /F | Out-Null
schtasks /Create /TN clawsos-watch /SC MINUTE /MO 3 /TR $wd /RU SYSTEM /RL HIGHEST /F | Out-Null
Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$dir*" } | Stop-Process -Force -ErrorAction SilentlyContinue
schtasks /Run /TN clawsos-daemon | Out-Null
Start-Sleep -Seconds 6
$running = Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$dir*" }
if ($pkgOk -and $nodeOk -and $running) { Write-Output ('AGENT-OK node=' + $running.ProcessId) }
elseif ($pkgOk -and $nodeOk) { Write-Output 'AGENT-INSTALLED-NOT-RUNNING' }
else { Write-Output ('AGENT-FAIL pkg=' + $pkgOk + ' node=' + $nodeOk) }