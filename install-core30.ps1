param(
    [switch]$Check
)

# ================== CONFIG ==================
$SshUser     = 'sshadmin'          # dedicated local SSH account
$SshPass     = 'Ctyun@SSH2026'      # change me if you like
$TsHostname  = 'ctyun-19957025579'        # 逐台更新：ctyun-<手机号前5>（13135735230 / 16607538937 / 18126980057 / 18767553762 / 19331521640 / 13250965273 / 15582823325）
$AuthKey     = 'tskey-auth-kysWXMhN3m11CNTRL-h836cfgfofCCvcsFZjwEgCxsVDYBY44pA'                    # cloudpc-farm-20261120 reusable, exp 2027-02-18
# ============================================

$ErrorActionPreference = 'Continue'
$KitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Log = Join-Path $KitDir 'install-log.txt'
$TsExe = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'

function Log($msg) {
    $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '] ' + $msg
    Write-Host $line
    Add-Content -Path $Log -Value $line -Encoding UTF8
}

# ---------- check mode (read-only) ----------
if ($Check) {
    Write-Host '=== CHECK MODE (read only) ==='
    Write-Host ('OS  : ' + (Get-CimInstance Win32_OperatingSystem).Caption)
    Write-Host ('Arch: ' + $env:PROCESSOR_ARCHITECTURE)
    $s = Get-Service sshd -ErrorAction SilentlyContinue
    Write-Host ('sshd service        : ' + $(if ($s) { $s.Status } else { 'not installed' }))
    try {
        Get-WindowsCapability -Online -Name 'OpenSSH.Server*' -ErrorAction Stop | ForEach-Object {
            Write-Host ('capability          : ' + $_.Name + ' = ' + $_.State)
        }
    } catch { Write-Host ('capability check failed: ' + $_.Exception.Message) }
    Write-Host ('tailscale exe       : ' + $(if (Test-Path $TsExe) { (& $TsExe version 2>$null) } else { 'not installed' }))
    $t = Get-Service Tailscale -ErrorAction SilentlyContinue
    Write-Host ('tailscale service   : ' + $(if ($t) { $t.Status } else { 'not installed' }))
    cmd /c ('net user ' + $SshUser + ' >nul 2>&1') | Out-Null
    Write-Host ('ssh user "' + $SshUser + '": ' + $(if ($LASTEXITCODE -eq 0) { 'exists' } else { 'not exists' }))
    exit 0
}

Log ('=== OpenSSH + Tailscale kit start ===')
Log ('OS: ' + (Get-CimInstance Win32_OperatingSystem).Caption + '  Arch: ' + $env:PROCESSOR_ARCHITECTURE)

# ---------- 1) OpenSSH Server ----------
$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if (-not $sshd) {
    Log 'sshd not found, trying Windows optional capability (needs internet)...'
    try {
        $r = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop
        Log ('capability install OK, restart needed: ' + $r.RestartNeeded)
    } catch {
        Log ('capability install failed: ' + $_.Exception.Message)
        Log 'falling back to bundled portable OpenSSH...'
        $zip = Join-Path $KitDir 'OpenSSH-Win64.zip'
        if (Test-Path $zip) {
            $tmp = Join-Path $env:TEMP 'openssh-kit-extract'
            if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -Path $zip -DestinationPath $tmp -Force
            $src = Join-Path $tmp 'OpenSSH-Win64'
            $dst = Join-Path $env:ProgramFiles 'OpenSSH'
            if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
            Copy-Item (Join-Path $src '*') $dst -Force
            $installSshd = Join-Path $dst 'install-sshd.ps1'
            powershell -NoProfile -ExecutionPolicy Bypass -File $installSshd | Out-Null
            Log 'portable OpenSSH installed'
        } else {
            Log 'ERROR: bundled OpenSSH zip also missing - OpenSSH NOT installed'
        }
    }
} else {
    Log 'sshd already installed'
}

$sshd = Get-Service sshd -ErrorAction SilentlyContinue
if ($sshd) {
    Set-Service sshd -StartupType Automatic
    Start-Service sshd -ErrorAction SilentlyContinue
    Log ('sshd status: ' + (Get-Service sshd).Status)

    $fw1 = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
    $fw2 = Get-NetFirewallRule -Name 'ssh-kit-22-in' -ErrorAction SilentlyContinue
    if (-not $fw1 -and -not $fw2) {
        New-NetFirewallRule -Name 'ssh-kit-22-in' -DisplayName 'OpenSSH Server (port 22, kit)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
        Log 'firewall rule added (TCP 22 in)'
    } else {
        Log 'firewall rule already present'
    }

    $reg = 'HKLM:\SOFTWARE\OpenSSH'
    if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
    New-ItemProperty -Path $reg -Name DefaultShell -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force | Out-Null
    Log 'DefaultShell set to Windows PowerShell'
} else {
    Log 'ERROR: sshd still missing, skipping sshd config'
}

# ---------- 2) dedicated SSH account ----------
Log ('ensuring local SSH account: ' + $SshUser)
cmd /c ('net user ' + $SshUser + ' ' + $SshPass + ' /add /y >nul 2>&1') | Out-Null
if ($LASTEXITCODE -ne 0) {
    cmd /c ('net user ' + $SshUser + ' ' + $SshPass + ' >nul 2>&1') | Out-Null
    if ($LASTEXITCODE -eq 0) { Log 'user existed, password reset to configured value' }
    else { Log ('ERROR creating user ' + $SshUser) }
}
cmd /c ('net user ' + $SshUser + ' /expires:never /passwordchg:no >nul 2>&1') | Out-Null
cmd /c ('net localgroup Administrators ' + $SshUser + ' /add >nul 2>&1') | Out-Null
Log ('account ready: ' + $SshUser + ' (Administrators)')

# ---------- 2.5) authorized_keys (本机 id_cloudpc + oneyear，装完即全通) ----------
$akFile = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
$pubMain = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+Ke9vs7DxZxQdiijWChKfhyYW0a07JLw9D6iqI252W idmin@DESKTOP-031B2SI'
$pubYear = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHaBRgjNX3NIwcUqIRecCoAjArHL96wNKm8R5X/VsBbX oneyear@opc-t908u'
if (-not (Test-Path $akFile)) { New-Item -ItemType File -Path $akFile -Force | Out-Null }
foreach ($k in @($pubMain, $pubYear)) {
    $fp = ($k.Split(' '))[1]
    $hit = Select-String -Path $akFile -Pattern ([regex]::Escape($fp)) -Quiet -ErrorAction SilentlyContinue
    if (-not $hit) { Add-Content -Path $akFile -Value $k -Encoding ascii }
}
icacls $akFile /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' 2>$null | Out-Null
Log 'authorized_keys deployed (main + oneyear)'

# ---------- 3) Tailscale ----------
if (-not (Test-Path $TsExe)) {
    $arch = $env:PROCESSOR_ARCHITECTURE
    $msi = Join-Path $KitDir 'tailscale-setup-1.104.7-amd64.msi'
    $exe = Join-Path $KitDir 'tailscale-setup-full-1.104.7.exe'
    if ($arch -eq 'AMD64' -and (Test-Path $msi)) {
        Log 'installing Tailscale (MSI silent)...'
        $p = Start-Process msiexec.exe -ArgumentList ('/i "' + $msi + '" /qn /norestart') -Wait -PassThru
        Log ('msiexec exit code: ' + $p.ExitCode)
    } elseif (Test-Path $exe) {
        Log 'installing Tailscale (full setup, silent)...'
        $p = Start-Process $exe -ArgumentList '/quiet', '/norestart' -Wait -PassThru
        Log ('setup exit code: ' + $p.ExitCode)
    } else {
        Log 'ERROR: no Tailscale installer found in kit'
    }
} else {
    Log 'Tailscale already installed'
}

$tsOk = $false
for ($i = 0; $i -lt 30; $i++) {
    if (Test-Path $TsExe) { $tsOk = $true; break }
    Start-Sleep -Seconds 2
}

$tsip = $null
if ($tsOk) {
    $tsd = Get-Service Tailscale -ErrorAction SilentlyContinue
    if ($tsd) {
        Set-Service Tailscale -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service Tailscale -ErrorAction SilentlyContinue
    }
    $tsip = & $TsExe ip -4 2>$null
    if (-not $tsip) {
        if ($AuthKey) {
            Log 'logging in with authkey...'
            & $TsExe up --authkey=$AuthKey --hostname=$TsHostname 2>&1 | Out-Null
            $tsip = & $TsExe ip -4 2>$null
        } else {
            Log 'not logged in - starting browser login (log in with your Tailscale account)...'
            $outF = Join-Path $KitDir 'ts-login-out.txt'
            $errF = Join-Path $KitDir 'ts-login-err.txt'
            $p = Start-Process $TsExe -ArgumentList 'login' -RedirectStandardOutput $outF -RedirectStandardError $errF -WindowStyle Hidden -PassThru
            $url = $null
            for ($i = 0; $i -lt 30; $i++) {
                Start-Sleep -Seconds 1
                $txt = ''
                if (Test-Path $outF) { $txt += (Get-Content $outF -Raw -ErrorAction SilentlyContinue) }
                if (Test-Path $errF) { $txt += (Get-Content $errF -Raw -ErrorAction SilentlyContinue) }
                if ($txt -match 'https://login\.tailscale\.com/a/[0-9a-f]+') { $url = $Matches[0]; break }
            }
            if ($url) {
                Log ('LOGIN URL: ' + $url)
                Start-Process $url
            } else {
                Log 'could not capture login URL; run "tailscale login" manually later'
            }
            Log 'waiting for you to finish login in the browser (up to 4 minutes)...'
            for ($i = 0; $i -lt 120; $i++) {
                Start-Sleep -Seconds 2
                $tsip = & $TsExe ip -4 2>$null
                if ($tsip) { break }
            }
        }
    }
    if ($tsip) {
        & $TsExe set --hostname=$TsHostname 2>$null | Out-Null
        Log ('SUCCESS - Tailscale IPv4: ' + $tsip)
    } else {
        Log 'Tailscale installed but NOT logged in yet; finish browser login, then re-run install.bat'
    }
} else {
    Log 'ERROR: tailscale.exe not found after install'
}

# ---------- 3.5) OpenP2P (one-key installer, account token embedded) ----------
$oppExe = $null
$oppCand = @(
    (Join-Path $env:ProgramFiles 'OpenP2P\opp.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'OpenP2P\opp.exe')
)
foreach ($p in $oppCand) { if (Test-Path $p) { $oppExe = $p; break } }
if (-not $oppExe -and -not (Get-Process opp -ErrorAction SilentlyContinue)) {
    $oppSetup = Join-Path $KitDir 'openp2p64-api.openp2p.cn-1268210438431465255-setup3.25.14.exe'
    if (Test-Path $oppSetup) {
        Log 'installing OpenP2P (one-key, token embedded)...'
        $p2 = Start-Process $oppSetup -ArgumentList '/S' -Wait -PassThru
        Log ('OpenP2P setup exit code: ' + $p2.ExitCode)
        if ($p2.ExitCode -ne 0) {
            Log 'NOTE: silent flag may be unsupported - if a GUI installer opened, finish it manually'
        }
        Start-Sleep -Seconds 3
        if (Get-Process opp -ErrorAction SilentlyContinue) { Log 'OpenP2P client is running' }
        else { Log 'WARNING: opp.exe not running after install' }
    } else {
        Log 'OpenP2P installer not found in kit, skipped'
    }
} else {
    Log 'OpenP2P already installed/running'
}

# ---------- 3.6) keepawake（防闲置：云电脑 ~1h 无活动自动关机） ----------
$kaPs1 = Join-Path ('C:\Users\' + $SshUser) 'keepawake-loop.ps1'
if (-not (Test-Path $kaPs1)) {
    $kaSrc = Join-Path $KitDir 'keepawake-loop.ps1'
    if (Test-Path $kaSrc) { Copy-Item $kaSrc $kaPs1 -Force; Log 'keepawake-loop.ps1 deployed' }
    else { Log 'keepawake-loop.ps1 not in kit, skip' }
}
if (Test-Path $kaPs1) {
    $kaName = 'keepawake-' + $TsHostname
    $kaExist = schtasks /query /tn $kaName 2>$null
    if (-not $kaExist) {
        schtasks /create /tn $kaName /tr ('powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ' + $kaPs1) /sc onstart /ru system /rl highest /f 2>$null | Out-Null
        Log ('keepawake task created: ' + $kaName + ' (onstart)')
    }
    schtasks /run /tn $kaName 2>$null | Out-Null
    Log 'keepawake task started'
}

# ---------- 4) summary ----------
$s = Get-Service sshd -ErrorAction SilentlyContinue
$summary = @(
    '==============================================',
    ' OpenSSH + Tailscale kit - result',
    (' Time    : ' + (Get-Date)),
    (' Computer: ' + $env:COMPUTERNAME),
    (' sshd    : ' + $(if ($s) { (Get-Service sshd).Status + ' (auto start)' } else { 'FAILED' })),
    (' Account : ' + $SshUser + '  Password: ' + $SshPass),
    (' Tailscale IP: ' + $(if ($tsip) { $tsip } else { '(not logged in yet - finish browser login)' })),
    (' OpenP2P  : ' + $(if (Get-Process opp -ErrorAction SilentlyContinue) { 'running (check console.openp2p.cn/device)' } else { 'not running' })),
    '----------------------------------------------',
    (' Connect from another tailnet machine with:'),
    ('   ssh ' + $SshUser + '@' + $(if ($tsip) { $tsip } else { '<tailscale-ip>' })),
    '=============================================='
)
$summary | ForEach-Object { Write-Host $_ }
$desk = [Environment]::GetFolderPath('Desktop')
$summary | Out-File -FilePath (Join-Path $desk 'SSH-Kit-Result.txt') -Encoding UTF8
$summary | Out-File -FilePath (Join-Path $KitDir 'SSH-Kit-Result.txt') -Encoding UTF8
Log '=== kit finished ==='
