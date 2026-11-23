# go-no-ts.ps1 — OpenSSH + openp2p + keepawake 引导装机（不装 tailscale，绕开 authkey 配额）
# 用法: powershell -ep bypass -f go-no-ts.ps1 -Node ctyun-19957448031
# 桌面引导: iwr https://fastly.jsdelivr.net/gh/jjohnhee/k/go-no-ts.ps1 -O $env:TEMP\g.ps1; powershell -ep bypass -f $env:TEMP\g.ps1 -Node ctyun-<手机号>
param([Parameter(Mandatory=$true)][string]$Node)
$ErrorActionPreference = 'Continue'
$dir = Join-Path $env:USERPROFILE 'Downloads'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Location $dir
function Log($m) { $l = '[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $m; Write-Host $l; Add-Content -Path (Join-Path $dir 'go-nots.log') -Value $l -Encoding UTF8 }
Log ("=== go-no-ts bootstrap start: node=" + $Node + " ===")
$M = @('https://fastly.jsdelivr.net/gh/jjohnhee/k', 'https://gcore.jsdelivr.net/gh/jjohnhee/k', 'https://testingcf.jsdelivr.net/gh/jjohnhee/k')

# ---------- 1) OpenSSH Server ----------
$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if (-not $sshd) {
  Log 'installing OpenSSH.Server capability...'
  try {
    $r = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop
    Log ('OpenSSH capability OK, needRestart=' + $r.RestartNeeded)
  } catch {
    Log ('capability failed: ' + $_.Exception.Message + ' — portable fallback')
    $zip = Join-Path $dir 'OpenSSH-Win64.zip'
    foreach ($m in $M) { curl.exe -sS -o $zip ($m + '/OpenSSH-Win64.zip'); if ((Test-Path $zip) -and ((Get-Item $zip).Length -gt 4000000)) { Log 'zip OK'; break } }
    if (Test-Path $zip) {
      $tmp = Join-Path $env:TEMP 'openssh-extract'
      if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
      Expand-Archive -Path $zip -DestinationPath $tmp -Force
      $src = Join-Path $tmp 'OpenSSH-Win64'
      & (Join-Path $src 'install-sshd.ps1')
      $acl = Join-Path $src 'FixUserFilePermissions.ps1' -ErrorAction SilentlyContinue
      if (Test-Path $acl) { & $acl -Confirm:$false }
      Copy-Item $src "$env:ProgramData\OpenSSH" -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
  Set-Service ssh-agent -StartupType Automatic -ErrorAction SilentlyContinue
  Start-Service sshd -ErrorAction SilentlyContinue
  Start-Service ssh-agent -ErrorAction SilentlyContinue
  Log 'sshd service configured'
} else { Log 'sshd already installed' }

# ---------- 2) sshadmin 账号 ----------
cmd /c 'net user sshadmin Ctyun@SSH2026 /add /y >nul 2>&1'
cmd /c 'net localgroup Administrators sshadmin /add >nul 2>&1'
Log 'sshadmin account ready'

# ---------- 3) openp2p ----------
$opp = 'C:\openp2p'
New-Item -ItemType Directory -Force -Path $opp | Out-Null
$exe = Join-Path $opp 'openp2p.exe'
if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 4000000) {
  $zipf = Join-Path $opp 'opp.zip'
  foreach ($m in $M) {
    curl.exe -sS -o $zipf ($m + '/openp2p-win.zip')
    if ((Test-Path $zipf) -and ((Get-Item $zipf).Length -gt 4000000)) { Log ('opp exe OK via ' + $m); break }
  }
  if ((Test-Path $zipf) -and ((Get-Item $zipf).Length -gt 4000000)) { Move-Item $zipf $exe -Force } else { Log 'FATAL: opp exe download failed' }
} else { Log 'opp exe already present' }
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
  Start-Sleep -Seconds 4
  $p = Get-Process openp2p -ErrorAction SilentlyContinue
  if ($p) { Log ('openp2p RUNNING pid=' + ($p.Id -join ',')) } else { Log 'openp2p NOT-RUNNING' }
}

# ---------- 4) keepawake ----------
$ka = 'C:\keepawake.ps1'
Set-Content -Path $ka -Value "Add-Type -TypeDefinition `"using System;using System.Runtime.InteropServices;public static class SU{[DllImport(``"kernel32.dll``")]public static extern uint SetThreadExecutionState(uint f);}`"; while(`$true){[SU]::SetThreadExecutionState(0x80000003);Start-Sleep 25}" -Encoding UTF8
schtasks /create /tn keepawake /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\keepawake.ps1" /sc onstart /ru SYSTEM /rl HIGHEST /f 2>$null | Out-Null
schtasks /run /tn keepawake 2>$null | Out-Null
Log 'keepawake on'

# ---------- 5) 完成报告 ----------
$final = Get-Service sshd -ErrorAction SilentlyContinue
Log ('=== DONE: sshd=' + $(if ($final) { $final.Status } else { 'MISSING' }) + ' opp=' + $(if (Get-Process openp2p -ErrorAction SilentlyContinue) { 'RUNNING' } else { 'STOP' }) + ' node=' + $Node + ' ===')
