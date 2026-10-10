# Runs every quick check of the project and prints ONE honest PASS / FAIL list (fix session 2026-10-10).
#
# A check counts as PASS only when ALL of these hold:
#   - it finished before its time limit,
#   - its output contains the tool's own "all good" line (ALL CHECKS PASSED / ALL FILES PARSE),
#   - its output has no "FAIL" line,
#   - neither its output nor its error output contains a SCRIPT ERROR / Parse Error / Identifier not found
#     (several tools print ALL CHECKS PASSED even after a script error aborted a check, so the error text is read too).
# The help check runs twice: in a phone-sized window (headless) and in a real 1280x720 window (the PC layout).
#
# How to run it (no command line needed): double-click run_all_checks.bat in the project folder.
# From a terminal:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_all_checks.ps1
# Only some checks:  ... -Only help,health      (a part of the name is enough)
# Another Godot:     set the GODOT_EXE environment variable, or pass -Godot "C:\path\Godot_console.exe"
# It takes about 10 minutes. The PC-layout help check opens a Godot window for a minute: leave it alone.
# Everything the checks printed is saved in the folder shown at the end (one .txt per check).

param(
	[string]$Godot = "",
	[string]$Only = ""
)

$ErrorActionPreference = "Stop"
$project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# --- Find Godot -------------------------------------------------------------------------------------------
$candidates = @()
if ($Godot -ne "") { $candidates += $Godot }
if ($env:GODOT_EXE) { $candidates += $env:GODOT_EXE }
$candidates += "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$found = Get-ChildItem -Path "$env:USERPROFILE\Downloads" -Recurse -Filter "Godot*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($found) { $candidates += $found.FullName }
$exe = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $exe) {
	Write-Host "Could not find Godot (the *_console.exe). Pass it with -Godot ""C:\path\to\Godot_..._console.exe""." -ForegroundColor Red
	exit 2
}

$outDir = Join-Path $env:TEMP ("llookjbb_checks_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# name, Godot arguments after --path, pass marker, time limit in seconds
$checks = @(
	@{ name = "import (new scripts known)"; args = "--headless --import"; marker = ""; limit = 300 },
	@{ name = "json_check"; args = "--headless -s res://tools/json_check.gd"; marker = "ALL FILES PARSE"; limit = 120 },
	@{ name = "help_check (phone layout)"; args = "--headless -s res://tools/help_check.gd"; marker = "ALL CHECKS PASSED"; limit = 400 },
	@{ name = "help_check (PC layout, window)"; args = "--rendering-driver opengl3 --resolution 1280x720 -s res://tools/help_check.gd"; marker = "ALL CHECKS PASSED"; limit = 400 },
	@{ name = "day_engine_check"; args = "--headless -s res://tools/day_engine_check.gd"; marker = "ALL CHECKS PASSED"; limit = 600 },
	@{ name = "health_check"; args = "--headless -s res://tools/health_check.gd"; marker = "ALL CHECKS PASSED"; limit = 600 },
	@{ name = "form_check"; args = "--headless -s res://tools/form_check.gd"; marker = "ALL CHECKS PASSED"; limit = 600 },
	@{ name = "season_plan_check"; args = "--headless -s res://tools/season_plan_check.gd"; marker = "ALL CHECKS PASSED"; limit = 600 },
	@{ name = "dev_menu_check"; args = "--headless -s res://tools/dev_menu_check.gd"; marker = "ALL CHECKS PASSED"; limit = 600 },
	@{ name = "race_rounds"; args = "--headless -s res://tools/race_rounds.gd"; marker = "ALL CHECKS PASSED"; limit = 900 },
	@{ name = "commentary_check"; args = "--headless -s res://tools/commentary_check.gd -- 24 0"; marker = "ALL CHECKS PASSED"; limit = 600 }
)
if ($Only -ne "") {
	$parts = $Only.Split(",") | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -ne "" }
	$checks = @($checks | Where-Object { $n = $_.name.ToLower(); @($parts | Where-Object { $n.Contains($_) }).Count -gt 0 })
}

$errorPattern = "SCRIPT ERROR|Parse Error|Identifier not found|Could not find type|Compile Error|Invalid call|Invalid access"
$results = @()
Write-Host ""
Write-Host "Running $($checks.Count) checks with $exe" -ForegroundColor Cyan
Write-Host "Project: $project"
Write-Host ""

foreach ($c in $checks) {
	$safe = ($c.name -replace "[^A-Za-z0-9]+", "_").Trim("_")
	$out = Join-Path $outDir "$safe.txt"
	$err = Join-Path $outDir "$safe.err.txt"
	$started = Get-Date
	$p = Start-Process -FilePath $exe -ArgumentList "--path `"$project`" $($c.args)" -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -NoNewWindow
	$null = $p.Handle
	$timedOut = $false
	if (-not $p.WaitForExit($c.limit * 1000)) {
		$timedOut = $true
		Stop-Process -Id $p.Id -Force   # (only the process this script started)
	}
	$secs = [int]((Get-Date) - $started).TotalSeconds
	$text = if (Test-Path $out) { Get-Content $out -Raw -Encoding UTF8 } else { "" }
	$errText = if (Test-Path $err) { Get-Content $err -Raw -Encoding UTF8 } else { "" }
	if ($null -eq $text) { $text = "" }
	if ($null -eq $errText) { $errText = "" }
	$why = @()
	if ($timedOut) { $why += "did not finish in $($c.limit) s" }
	if ($c.marker -ne "" -and -not $text.Contains($c.marker)) { $why += "the line '$($c.marker)' is missing" }
	$failLines = @($text -split "`r?`n" | Where-Object { $_ -match "^\s*FAIL" -or $_ -match "CHECK\(S\) FAILED|SOME CHECKS FAILED|FILES FAILED|PROBLEMS" })
	if ($failLines.Count -gt 0) { $why += "$($failLines.Count) failed check line(s), e.g. " + $failLines[0].Trim() }
	$errLines = @(($text + "`n" + $errText) -split "`r?`n" | Where-Object { $_ -match $errorPattern })
	if ($errLines.Count -gt 0) { $why += "script error: " + $errLines[0].Trim() }
	if ($p.HasExited -and $p.ExitCode -ne 0 -and $p.ExitCode -ne $null -and -not $timedOut) { $why += "Godot exit code $($p.ExitCode)" }
	$ok = $why.Count -eq 0
	$results += [pscustomobject]@{ Name = $c.name; Ok = $ok; Seconds = $secs; Why = ($why -join "; ") }
	if ($ok) {
		Write-Host ("[PASS] {0}  ({1} s)" -f $c.name, $secs) -ForegroundColor Green
	} else {
		Write-Host ("[FAIL] {0}  ({1} s)" -f $c.name, $secs) -ForegroundColor Red
		Write-Host ("       " + ($why -join "; ")) -ForegroundColor Red
	}
}

$failed = @($results | Where-Object { -not $_.Ok })
Write-Host ""
Write-Host "================ SUMMARY ================"
foreach ($r in $results) {
	if ($r.Ok) { Write-Host ("PASS  {0}" -f $r.Name) -ForegroundColor Green }
	else { Write-Host ("FAIL  {0}  - {1}" -f $r.Name, $r.Why) -ForegroundColor Red }
}
Write-Host ""
if ($failed.Count -eq 0) {
	Write-Host "ALL $($results.Count) CHECKS PASSED" -ForegroundColor Green
} else {
	Write-Host "$($failed.Count) OF $($results.Count) CHECKS FAILED" -ForegroundColor Red
}
Write-Host "Full output of every check: $outDir"
$results | ForEach-Object { "{0}`t{1}`t{2} s`t{3}" -f ($(if ($_.Ok) { "PASS" } else { "FAIL" })), $_.Name, $_.Seconds, $_.Why } | Set-Content -Path (Join-Path $outDir "summary.txt") -Encoding ascii
if ($failed.Count -gt 0) { exit 1 }
exit 0

