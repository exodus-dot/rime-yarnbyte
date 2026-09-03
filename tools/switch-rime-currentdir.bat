@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-rime-currentdir.ps1"
if errorlevel 1 pause
endlocal
