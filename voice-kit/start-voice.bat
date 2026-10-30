@echo off
rem Night of Frights - starts the narrator generator and keeps this window open
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate-voice.ps1"
echo.
echo If you see an error above, take a screenshot and send it to Claude.
pause
