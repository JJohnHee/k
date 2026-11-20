# go.ps1 - cloudpc kit bootstrap v2 (mirror chain, China-safe)
# self-elevate
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $PSCommandPath) -Verb RunAs
  exit
}
$ErrorActionPreference = 'Continue'
$dir = Join-Path $env:USERPROFILE 'Downloads'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Set-Location $dir
$M = @('https://fastly.jsdelivr.net/gh/jjohnhee/k','https://gcore.jsdelivr.net/gh/jjohnhee/k','https://testingcf.jsdelivr.net/gh/jjohnhee/k','https://cdn.jsdelivr.net/gh/jjohnhee/k')
$Log = Join-Path $dir 'go-bootstrap.log'
function L($m) { $l = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m; Write-Host $l; Add-Content -Path $Log -Value $l -Encoding UTF8 }
L '=== go.ps1 v2 bootstrap start (admin) ==='
function Get1($name, $relPath, $minBytes, $tries) {
  $f = Join-Path $dir $name
  for ($i = 1; $i -le $tries; $i++) {
    foreach ($base in $M) {
      if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
      curl.exe -sS -o $f ($base + $relPath)
      if (Test-Path $f) {
        $sz = (Get-Item $f).Length
        if ($sz -gt $minBytes) { L ('OK {0} {1}B via {2} (try {3})' -f $name, $sz, $base, $i); return $true }
      }
    }
    Start-Sleep -Seconds 3
  }
  L ('FAIL {0} after {1} tries' -f $name, $tries); return $false
}
$ok1 = Get1 'install-core.ps1' '/install-core.ps1' 10000 4
$ok2 = Get1 'keepawake-loop.ps1' '/keepawake-loop.ps1' 100 4
$ok3 = Get1 'OpenSSH-Win64.zip' '/OpenSSH-Win64.zip' 4000000 3
$msi = Join-Path $dir 'tailscale-setup-1.104.7-amd64.msi'
$ok4 = $false
for ($i = 1; $i -le 4 -and -not $ok4; $i++) {
  if (Test-Path $msi) { Remove-Item $msi -Force -ErrorAction SilentlyContinue }
  curl.exe -sS -o $msi 'https://pkgs.tailscale.com/stable/tailscale-setup-1.104.7-amd64.msi'
  if ((Test-Path $msi) -and ((Get-Item $msi).Length -gt 20000000)) { $ok4 = $true; L ('OK msi {0}B via pkgs (try {1})' -f (Get-Item $msi).Length, $i) }
}
if (-not $ok4) {
  for ($i = 1; $i -le 3 -and -not $ok4; $i++) {
    if (Test-Path $msi) { Remove-Item $msi -Force -ErrorAction SilentlyContinue }
    curl.exe -sS -L -o $msi 'https://github.com/JJohnHee/k/releases/download/k/tailscale-setup-1.104.7-amd64.msi'
    if ((Test-Path $msi) -and ((Get-Item $msi).Length -gt 20000000)) { $ok4 = $true; L ('OK msi {0}B via github (try {1})' -f (Get-Item $msi).Length, $i) }
  }
}
if (-not $ok1) { L 'FATAL: install-core.ps1 missing'; Read-Host 'press enter to exit'; exit 1 }
L 'All files ready. Running installer...'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'install-core.ps1')
L '=== bootstrap DONE ==='
Read-Host 'press enter to close'
