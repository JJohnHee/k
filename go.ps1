# go.ps1 - cloudpc kit bootstrap (jsDelivr + pkgs, China-safe)
# self-elevate
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $PSCommandPath) -Verb RunAs
  exit
}
$ErrorActionPreference = 'Continue'
$dir = Join-Path $env:USERPROFILE 'Downloads'
Set-Location $dir
$JD = 'https://cdn.jsdelivr.net/gh/JJohnHee/k@main'
$Log = Join-Path $dir 'go-bootstrap.log'
function L($m) { $l = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m; Write-Host $l; Add-Content -Path $Log -Value $l -Encoding UTF8 }
L '=== go.ps1 bootstrap start (admin) ==='
function Get1($name, $url, $minBytes, $tries) {
  for ($i = 1; $i -le $tries; $i++) {
    $f = Join-Path $dir $name
    if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
    curl.exe -sS -o $f $url
    if (Test-Path $f) {
      $sz = (Get-Item $f).Length
      if ($sz -gt $minBytes) { L ("OK {0} {1}B (try {2})" -f $name, $sz, $i); return $true }
    }
    Start-Sleep -Seconds 3
  }
  L ("FAIL {0} after {1} tries" -f $name, $tries); return $false
}
$ok1 = Get1 'install-core.ps1' "$JD/install-core.ps1" 10000 6
$ok2 = Get1 'keepawake-loop.ps1' "$JD/keepawake-loop.ps1" 100 6
$ok3 = Get1 'OpenSSH-Win64.zip' "$JD/OpenSSH-Win64.zip" 4000000 6
$ok4 = Get1 'tailscale-setup-1.104.7-amd64.msi' 'https://pkgs.tailscale.com/stable/tailscale-setup-1.104.7-amd64.msi' 20000000 5
if ($ok4 -eq $false) {
  L 'pkgs failed, fallback github release'
  $ok4 = Get1 'tailscale-setup-1.104.7-amd64.msi' 'https://github.com/JJohnHee/k/releases/download/k/tailscale-setup-1.104.7-amd64.msi' 20000000 4
}
if (-not $ok1) { L 'FATAL: install-core.ps1 missing'; Read-Host 'press enter to exit'; exit 1 }
L 'All files ready. Running installer...'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'install-core.ps1')
L '=== bootstrap DONE ==='
Read-Host 'press enter to close'
