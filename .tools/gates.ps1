# Runs every gate headless in parallel and prints one line per gate; exit code 1 if any gate fails.
#   powershell -File .tools/gates.ps1
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$godot = ".tools/godot/Godot_v4.7.2-stable_win64_console.exe"
$gates = "bot_run", "check_balance", "check_audience", "check_save", "check_network", "check_slice", "check_portraits", "check_playtest"
New-Item -ItemType Directory -Force build/gates | Out-Null
$procs = @{}
foreach ($gate in $gates) {
	$procs[$gate] = Start-Process $godot -ArgumentList "--headless", "--path", ".", "-s", "res://sim/$gate.gd" -NoNewWindow -PassThru `
		-RedirectStandardOutput "build/gates/$gate.txt" -RedirectStandardError "build/gates/$gate.err.txt"
	$null = $procs[$gate].Handle
}
$bad = 0
foreach ($gate in $gates) {
	$p = $procs[$gate]
	if (-not $p.WaitForExit(900000)) {
		$p.Kill()
		Write-Output ("{0,-16} TIMEOUT" -f $gate)
		$bad++
		continue
	}
	$p.WaitForExit()
	$out = Get-Content "build/gates/$gate.txt"
	$fails = @($out | Select-String -CaseSensitive -Pattern "^FAIL|FAILED|SCRIPT ERROR|Parse Error")
	$errs = @(Get-Content "build/gates/$gate.err.txt" | Select-String -CaseSensitive -Pattern "SCRIPT ERROR|Parse Error")
	$last = ($out | Where-Object { $_ -ne "" } | Select-Object -Last 1)
	if ($p.ExitCode -ne 0 -or $fails.Count -gt 0 -or $errs.Count -gt 0) {
		$bad++
		Write-Output ("{0,-16} FAIL exit {1}: {2}" -f $gate, $p.ExitCode, (($fails + $errs | Select-Object -First 3) -join " | "))
	} else {
		Write-Output ("{0,-16} ok   {1}" -f $gate, $last)
	}
}
if ($bad -gt 0) { exit 1 }
exit 0
