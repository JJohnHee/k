# go4.ps1 - full bootstrap + explicit tailscale authkey login (verbose)
# self-elevate
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $PSCommandPath) -Verb RunAs
  exit
}
$ErrorActionPreference = 'Continue'
$dir = Join-Path $env:USERPROFILE 'Downloads'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Location $dir
$M = @('https://fastly.jsdelivr.net/gh/jjohnhee/k','https://gcore.jsdelivr.net/gh/jjohnhee/k','https://testingcf.jsdelivr.net/gh/jjohnhee/k')
$Log = Join-Path $dir 'go4.log'
function L($m) { $l = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m; Write-Host $l; Add-Content -Path $Log -Value $l -Encoding UTF8 }
L '=== go4.ps1 bootstrap start (admin) ==='
function Get1($name, $relPath, $minBytes, $tries) {
  $f = Join-Path $dir $name
  for ($i = 1; $i -le $tries; $i++) {
    foreach ($base in $M) {
      if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
      curl.exe -sS -o $f ($base + $relPath)
      if (Test-Path $f) {
        $sz = (Get-Item $f).Length
        if ($sz -gt $minBytes) { L ('OK {0} {1}B via {2}' -f $name, $sz, $base); return $true }
      }
    }
    Start-Sleep -Seconds 3
  }
  L ('FAIL {0}' -f $name); return $false
}
$ok1 = Get1 'install-core45.ps1' '/install-core45.ps1' 10000 4
$ok2 = Get1 'keepawake-loop.ps1' '/keepawake-loop.ps1' 100 4
$ok3 = Get1 'OpenSSH-Win64.zip' '/OpenSSH-Win64.zip' 4000000 3
$msi = Join-Path $dir 'tailscale-setup-1.104.7-amd64.msi'
$ok4 = $false
for ($i = 1; $i -le 4 -and -not $ok4; $i++) {
  if (Test-Path $msi) { Remove-Item $msi -Force -ErrorAction SilentlyContinue }
  curl.exe -sS -o $msi 'https://pkgs.tailscale.com/stable/tailscale-setup-1.104.7-amd64.msi'
  if ((Test-Path $msi) -and ((Get-Item $msi).Length -gt 20000000)) { $ok4 = $true; L ('OK msi {0}B via pkgs' -f (Get-Item $msi).Length) }
}
if (-not $ok1) { L 'FATAL: install-core45.ps1 missing'; Read-Host 'enter'; exit 1 }
L 'Running installer (install-core45.ps1)...'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'install-core45.ps1')
L 'installer done. Now explicit tailscale authkey login...'
foreach ($p in @((Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'), (Join-Path ${env:ProgramFiles(x86)} 'Tailscale\tailscale.exe'))) {
  if (Test-Path $p) { $ts = $p; break }
}
if ($ts) {
  L ("TS-EXE: " + $ts)
  & $ts up --authkey=tskey-auth-kUyTaTvo3a11CNTRL-MWUrXGFQdEdrd4xxDks6FdxP1ZCkerN2 --hostname=ctyun-17367564148 2>&1 | ForEach-Object { L ("TS: " + $_) }
  Start-Sleep -Seconds 8
  $ip = & $ts ip -4 2>$null
  L ("TS-IP: " + $ip)
  if ($ip) { L 'LOGIN-SUCCESS' } else { L 'LOGIN-FAILED'; Read-Host 'enter' }
} else {
  L 'TS-EXE-NOT-FOUND after install'
  Read-Host 'enter'
}
L '=== go4 done ==='
