@echo off
rem Double-click to run every quick check of the project (about 10 minutes). Needs nothing else.
rem The window stays open at the end so you can read the PASS / FAIL list.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_all_checks.ps1" %*
echo.
pause
