param(
    [Parameter(Mandatory = $true)][ValidateSet("ru", "en")][string]$Lang
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = $env:GODOT
if (-not $godot) { $godot = Join-Path $root ".tools\godot\Godot_v4.7.2-stable_win64_console.exe" }
if (-not (Test-Path $godot)) { throw "Godot not found at $godot. Set GODOT to the console binary." }

$preset = "Windows " + $Lang.ToUpper()
$outDir = Join-Path $root "build\$Lang\windows"
$exe = Join-Path $outDir "Underline.exe"
$zip = Join-Path $root "build\$Lang\Underline-$Lang-windows.zip"
$playtest = if ($Lang -eq "ru") { "PLAYTEST_RU.md" } else { "PLAYTEST.md" }

New-Item -ItemType Directory -Force $outDir | Out-Null
$gdignore = Join-Path $root "build\.gdignore"
if (-not (Test-Path $gdignore)) { New-Item -ItemType File $gdignore | Out-Null }

if (Test-Path $exe) { Remove-Item $exe -Force }
$ErrorActionPreference = "Continue"
$log = & $godot --headless --path $root --export-release $preset "build/$Lang/windows/Underline.exe" 2>&1 | Out-String
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) {
    $log
    throw "Export of '$preset' failed."
}
$errors = ($log -split "`n") | Where-Object { $_ -match "SCRIPT ERROR|Parse Error" }
if ($errors) {
    $errors
    throw "Export of '$preset' reported script errors."
}

[IO.File]::WriteAllText((Join-Path $outDir "lang.txt"), $Lang)

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
if (Test-Path $zip) { Remove-Item $zip -Force }
$level = [IO.Compression.CompressionLevel]::Optimal
$archive = [IO.Compression.ZipFile]::Open($zip, "Create")
try {
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $exe, "Underline.exe", $level)
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $outDir "lang.txt"), "lang.txt", $level)
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $root $playtest), "PLAYTEST.md", $level)
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $root "CREDITS.md"), "CREDITS.md", $level)
}
finally {
    $archive.Dispose()
}

"exe {0:N1} MB  {1}" -f ((Get-Item $exe).Length / 1MB), $exe
"zip {0:N1} MB  {1}" -f ((Get-Item $zip).Length / 1MB), $zip
