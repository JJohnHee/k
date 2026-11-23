# comment (ascii only)
# comment (ascii only)
param(
  [Parameter(Mandatory=$true)][string]$Node,
  [string]$TsHost = $Node,
  [string]$AuthKey = 'tskey-auth-kysWXMhN3m11CNTRL-h836cfgfofCCvcsFZjwEgCxsVDYBY44pA'
)
$ErrorActionPreference = 'Continue'
$opp = 'C:\openp2p'
$exe = Join-Path $opp 'openp2p.exe'
function Log($m) { Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }

# comment (ascii only)
if (-not (Test-Path $exe)) { Log 'FATAL: openp2p.exe not found'; exit 1 }

# comment (ascii only)
$cfg = Join-Path $opp 'config.json'
if (Test-Path $cfg) {
  $json = Get-Content $cfg -Raw | ConvertFrom-Json
  if ($json.network.Node -ne $Node) {
    $json.network.Node = $Node
    $json | ConvertTo-Json -Depth 6 | Set-Content $cfg -Encoding UTF8
    Log ("config Node -> " + $Node)
  } else { Log 'config Node OK' }
}

# comment (ascii only)
Get-Process openp2p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
schtasks /End /TN openp2p 2>$null | Out-Null
schtasks /Run /TN openp2p | Out-Null
Start-Sleep -Seconds 5
$p = Get-Process openp2p -ErrorAction SilentlyContinue
if ($p) { Log ("openp2p RUNNING pid=" + ($p.Id -join ',')) } else { Log 'openp2p still not running' }

# comment (ascii only)
$wd = 'C:\openp2p\watchdog.cmd'
Set-Content -Path $wd -Value "@echo off`r`ntasklist /FI `"IMAGENAME eq openp2p.exe`" | findstr openp2p >nul 2>&1 || start `"`" /MIN `"C:\openp2p\openp2p.exe`" -d" -Encoding ASCII
schtasks /Create /TN openp2p-watch /SC MINUTE /MO 5 /TR "C:\openp2p\watchdog.cmd" /RU SYSTEM /RL HIGHEST /F | Out-Null
schtasks /Run /TN openp2p-watch | Out-Null
Log 'watchdog task on (every 5 min)'

# comment (ascii only)
$tsExe = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
if (Test-Path $tsExe) {
  Log 'tailscale found, up with new authkey...'
  & $tsExe up --authkey=$AuthKey --hostname=$TsHost --reset 2>&1 | ForEach-Object { Log ("TS: " + $_) }
  Start-Sleep -Seconds 5
  $tsStatus = (& $tsExe status -peers=false 2>&1 | Select-Object -First 3) -join ' | '
  Log ("TS status: " + $tsStatus)
} else { Log 'no tailscale installed' }

Log '=== fix-opp DONE ==='
