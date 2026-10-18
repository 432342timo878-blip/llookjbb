@echo off
rem Double-click to run every check of the project (about 15 minutes). Needs nothing else.
rem A quicker run for use while working (about 6 minutes): run_all_checks.bat -Quick   (from a terminal, or a shortcut with -Quick).
rem The window stays open at the end so you can read the PASS / FAIL list.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_all_checks.ps1" %*
echo.
pause
