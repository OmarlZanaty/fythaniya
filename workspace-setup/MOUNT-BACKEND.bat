@echo off
title fythaniya backend mount
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mount-backend-fix.ps1"
echo.
echo ============================================================
echo  Finished. The result was also saved to mount-result.txt
echo  You can close this window.
echo ============================================================
pause
