@echo off
title SSH Kit Downloader
cd /d "%~dp0"
net session >nul 2>&1 || (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
echo Downloading kit files from VPS...
curl -sS -o install-core.ps1 https://github.com/JJohnHee/k/releases/download/k/install-core.ps1
curl -sS -o OpenSSH-Win64.zip https://github.com/JJohnHee/k/releases/download/k/OpenSSH-Win64.zip
curl -sS -o tailscale-setup-1.104.7-amd64.msi https://github.com/JJohnHee/k/releases/download/k/tailscale-setup-1.104.7-amd64.msi
curl -sS -o keepawake-loop.ps1 https://github.com/JJohnHee/k/releases/download/k/keepawake-loop.ps1
echo Files downloaded. Running installer...
powershell -NoProfile -ExecutionPolicy Bypass -File install-core.ps1
echo.
echo ============ DONE. See Desktop SSH-Kit-Result.txt ============
pause
