# go3.ps1 - tailscale authkey login + hostname (ctyun-16607)
$ts = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
if (-not (Test-Path $ts)) { Write-Host 'ERR: tailscale.exe not found'; Read-Host 'enter'; exit 1 }
Write-Host 'running: tailscale up --authkey=... --hostname=ctyun-16607'
& $ts up --authkey=tskey-auth-kUyTaTvo3a11CNTRL-MWUrXGFQdEdrd4xxDks6FdxP1ZCkerN2 --hostname=ctyun-16607 --accept-routes=false 2>&1 | ForEach-Object { Write-Host $_ }
Start-Sleep -Seconds 8
$ip = & $ts ip -4 2>$null
Write-Host ("TS-IP: " + $ip)
if ($ip) { Write-Host 'LOGIN-SUCCESS' } else { Write-Host 'LOGIN-FAILED'; Read-Host 'enter' }
