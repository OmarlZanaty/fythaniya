@echo off
title fythaniya ssh diagnostic
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnose-ssh.ps1"
echo.
echo ============================================================
echo  Finished. Result also saved to diagnose-result.txt
echo  You can close this window.
echo ============================================================
pause
