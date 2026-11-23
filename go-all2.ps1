# comment (ascii only)
# comment (ascii only)
param(
  [Parameter(Mandatory=$true)][string]$Node,
  [string]$AuthKey = 'tskey-auth-kysWXMhN3m11CNTRL-h836cfgfofCCvcsFZjwEgCxsVDYBY44pA'
)
$ErrorActionPreference = 'Continue'
$dir = Join-Path $env:USERPROFILE 'Downloads'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Location $dir
$M = @('https://gcore.jsdelivr.net/gh/jjohnhee/k', 'https://testingcf.jsdelivr.net/gh/jjohnhee/k', 'https://fastly.jsdelivr.net/gh/jjohnhee/k')
function Log($m) { $l = '[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $m; Write-Host $l; Add-Content -Path (Join-Path $dir 'go-all.log') -Value $l -Encoding UTF8 }
Log ("=== go-all start: node=" + $Node + " ===")

# ---------- 1) OpenSSH Server ----------
$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if (-not $sshd) {
  Log 'installing OpenSSH...'
  try {
    $r = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop
    Log ('OpenSSH capability OK')
  } catch {
    Log ('capability failed — official portable fallback')
    $zip = Join-Path $dir 'OpenSSH-Win64.zip'
    foreach ($m in $M) { curl.exe -sS -o $zip ($m + '/OpenSSH-Win64.zip'); if ((Test-Path $zip) -and ((Get-Item $zip).Length -gt 4000000)) { Log 'OpenSSH zip OK'; break } }
    if ((Test-Path $zip) -and ((Get-Item $zip).Length -gt 4000000)) {
      $tmp = Join-Path $env:TEMP 'openssh-extract'
      if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
      Expand-Archive -Path $zip -DestinationPath $tmp -Force
      $src = Join-Path $tmp 'OpenSSH-Win64'
      $pf = Join-Path $env:ProgramFiles 'OpenSSH'
      New-Item -ItemType Directory -Force -Path $pf | Out-Null
      Copy-Item (Join-Path $src '*') $pf -Recurse -Force
      & (Join-Path $src 'install-sshd.ps1') 2>&1 | ForEach-Object { Log ('sshd-install: ' + $_) }
      $fx = Join-Path $src 'FixUserFilePermissions.ps1'
      if (Test-Path $fx) { & $fx -Confirm:$false 2>&1 | ForEach-Object { Log ('acl: ' + $_) } }
    } else { Log 'FATAL: OpenSSH zip download failed' }
  }
  Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
  Start-Service sshd -ErrorAction SilentlyContinue
  Log 'sshd configured'
} else { Log 'sshd already installed' }
cmd /c 'net user sshadmin Ctyun@SSH2026 /add /y >nul 2>&1'
cmd /c 'net localgroup Administrators sshadmin /add >nul 2>&1'
Log 'sshadmin ready'

# comment (ascii only)
$tsExe = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
if (-not (Test-Path $tsExe)) {
  Log 'installing tailscale msi...'
  $msi = Join-Path $dir 'tailscale-setup.msi'
  for ($i = 0; $i -lt 4 -and -not (Test-Path $msi); $i++) {
    curl.exe -sS -o $msi 'https://pkgs.tailscale.com/stable/tailscale-setup-1.104.7-amd64.msi'
    if (-not ((Test-Path $msi) -and ((Get-Item $msi).Length -gt 20000000))) { Start-Sleep 3 }
  }
  if ((Test-Path $msi) -and ((Get-Item $msi).Length -gt 20000000)) {
    msiexec /i $msi /qn /norestart | Out-Null
    Start-Sleep 10
    Log 'tailscale msi installed'
  } else { Log 'FATAL: tailscale msi failed' }
}
if (Test-Path $tsExe) {
  Log 'tailscale up with authkey...'
  & $tsExe up --authkey=$AuthKey --hostname=$Node --reset 2>&1 | ForEach-Object { Log ("TS: " + $_) }
} else { Log 'no tailscale exe' }

# comment (ascii only)
$opp = 'C:\openp2p'
New-Item -ItemType Directory -Force -Path $opp | Out-Null
$exe = Join-Path $opp 'openp2p.exe'
if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 4000000) {
  $zipf = Join-Path $opp 'opp.zip'
  foreach ($m in $M) { curl.exe -sS -o $zipf ($m + '/openp2p-win.zip'); if ((Test-Path $zipf) -and ((Get-Item $zipf).Length -gt 4000000)) { break } }
  if ((Test-Path $zipf) -and ((Get-Item $zipf).Length -gt 4000000)) { Move-Item $zipf $exe -Force }
}
if (Test-Path $exe) {
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
  Set-Content -Path (Join-Path $opp 'config.json') -Value $config -Encoding UTF8
  schtasks /Create /TN openp2p /SC ONSTART /TR "C:\openp2p\openp2p.exe -d" /RU SYSTEM /RL HIGHEST /F | Out-Null
  Get-Process openp2p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  schtasks /Run /TN openp2p | Out-Null
  Start-Sleep 4
  $wd = Join-Path $opp 'watchdog.cmd'
  Set-Content -Path $wd -Value "@echo off`r`ntasklist /FI `"IMAGENAME eq openp2p.exe`" | findstr openp2p >nul 2>&1 || start `"`" /MIN `"C:\openp2p\openp2p.exe`" -d" -Encoding ASCII
  schtasks /Create /TN openp2p-watch /SC MINUTE /MO 5 /TR "C:\openp2p\watchdog.cmd" /RU SYSTEM /RL HIGHEST /F | Out-Null
  schtasks /Run /TN openp2p-watch | Out-Null
  if (Get-Process openp2p -ErrorAction SilentlyContinue) { Log 'openp2p RUNNING + watchdog on' } else { Log 'openp2p NOT-RUNNING' }
}

# ---------- 4) keepawake ----------
$ka = 'C:\keepawake.ps1'
Set-Content -Path $ka -Value "Add-Type -TypeDefinition `"using System;using System.Runtime.InteropServices;public static class SU{[DllImport(``"kernel32.dll``")]public static extern uint SetThreadExecutionState(uint f);}`"; while(`$true){[SU]::SetThreadExecutionState(0x80000003);Start-Sleep 25}" -Encoding UTF8
schtasks /create /tn keepawake /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\keepawake.ps1" /sc onstart /ru SYSTEM /rl HIGHEST /f 2>$null | Out-Null
schtasks /run /tn keepawake 2>$null | Out-Null
Log 'keepawake on'

$final = Get-Service sshd -ErrorAction SilentlyContinue
Log ('=== DONE: sshd=' + $(if ($final) { $final.Status } else { 'MISSING' }) + ' ts=' + $(if (Test-Path $tsExe) { 'installed' } else { 'missing' }) + ' opp=' + $(if (Get-Process openp2p -ErrorAction SilentlyContinue) { 'RUNNING' } else { 'STOP' }) + ' node=' + $Node + ' ===')
