@echo off
title SSH Kit Downloader v3
cd /d "%~dp0"
net session >nul 2>&1 || (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
echo Cleaning partial files...
del /q install-core.ps1 OpenSSH-Win64.zip tailscale-setup-1.104.7-amd64.msi keepawake-loop.ps1 >nul 2>&1
set JD=https://cdn.jsdelivr.net/gh/JJohnHee/k@main
set /a T=0
:DL_CORE
set /a T+=1
curl -sS -o install-core.ps1 %JD%/install-core.ps1
for %%F in (install-core.ps1) do set S1=%%~zF
if %S1% GTR 10000 goto CORE_OK
del /q install-core.ps1 >nul 2>&1
if %T% lss 6 (timeout /t 3 /nobreak >nul & goto DL_CORE)
:CORE_OK
echo install-core.ps1 %S1%B (try %T%)
set /a T=0
:DL_KEEP
set /a T+=1
curl -sS -o keepawake-loop.ps1 %JD%/keepawake-loop.ps1
for %%F in (keepawake-loop.ps1) do set S2=%%~zF
if %S2% GTR 100 goto KEEP_OK
del /q keepawake-loop.ps1 >nul 2>&1
if %T% lss 6 (timeout /t 3 /nobreak >nul & goto DL_KEEP)
:KEEP_OK
echo keepawake %S2%B (try %T%)
set /a T=0
:DL_ZIP
set /a T+=1
curl -sS -o OpenSSH-Win64.zip %JD%/OpenSSH-Win64.zip
for %%F in (OpenSSH-Win64.zip) do set S3=%%~zF
if %S3% GTR 4000000 goto ZIP_OK
del /q OpenSSH-Win64.zip >nul 2>&1
if %T% lss 6 (timeout /t 5 /nobreak >nul & goto DL_ZIP)
:ZIP_OK
echo openssh zip %S3%B (try %T%)
set /a T=0
:DL_MSI
set /a T+=1
curl -sS -o tailscale-setup-1.104.7-amd64.msi https://pkgs.tailscale.com/stable/tailscale-setup-1.104.7-amd64.msi
for %%F in (tailscale-setup-1.104.7-amd64.msi) do set S4=%%~zF
if %S4% GTR 20000000 goto MSI_OK
del /q tailscale-setup-1.104.7-amd64.msi >nul 2>&1
if %T% lss 5 (timeout /t 8 /nobreak >nul & goto DL_MSI)
:MSI_OK
echo tailscale msi %S4%B (try %T%)
if not exist install-core.ps1 echo FATAL install-core.ps1 missing & goto END
echo All files ready. Running installer...
powershell -NoProfile -ExecutionPolicy Bypass -File install-core.ps1
:END
echo.
echo ============ DONE. See Desktop SSH-Kit-Result.txt ============
pause
