# Closed playtest build for itch.io (docs/briefs/cursor_playtest_build.txt). Local only: uploads nothing.
#   powershell -File .tools/export_playtest.ps1
# 1. writes data/build_info.json {version, build: git short hash, date} and puts the committed file back at the end;
# 2. exports the "Windows Playtest" preset as a zip pack and lists what is inside (build/playtest/pack_contents.txt),
#    failing if anything from the exclude list got in;
# 3. exports the release exe with the pack embedded;
# 4. zips Underline.exe, README_RU.txt, README_EN.txt and CREDITS.txt into
#    build/playtest/Underline-<version>-windows.zip.
param([string]$Version = "0.1.0-playtest3")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = $env:GODOT
if (-not $godot) { $godot = Join-Path $root ".tools\godot\Godot_v4.7.2-stable_win64_console.exe" }
if (-not (Test-Path $godot)) { throw "Godot not found at $godot. Set GODOT to the console binary." }

$preset = "Windows Playtest"
$out = Join-Path $root "build\playtest"
$stage = Join-Path $out "Underline"
$exe = Join-Path $stage "Underline.exe"
$pack = Join-Path $out "pack_check.zip"
$zip = Join-Path $out "Underline-$Version-windows.zip"
$infoPath = Join-Path $root "data\build_info.json"
$utf8 = New-Object Text.UTF8Encoding $false
$utf8Bom = New-Object Text.UTF8Encoding $true

function Invoke-Godot([string[]]$GodotArgs) {
    $ErrorActionPreference = "Continue"
    $text = & $godot @GodotArgs 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    $bad = ($text -split "`n") | Where-Object { $_ -match "SCRIPT ERROR|Parse Error" }
    if ($code -ne 0 -or $bad) {
        $text
        throw "Godot $($GodotArgs -join ' ') failed."
    }
}

# Markdown to plain text for Notepad: headings lose their marks and get underlined, bold and code marks go,
# links keep their address, tables become aligned-enough rows.
function ConvertTo-PlainText([string]$Path) {
    $lines = [IO.File]::ReadAllLines($Path, $utf8)
    $outLines = New-Object Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -match '^\s*\|?\s*-{3,}') { continue }
        $text = $line
        $text = [regex]::Replace($text, '\[([^\]]+)\]\(([^)]+)\)', '$1 ($2)')
        $text = $text.Replace('**', '').Replace('`', '')
        if ($text -match '^\s*\|') {
            $cells = $text.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() }
            $text = "  " + ($cells -join "  |  ")
        }
        if ($text -match '^(#+)\s*(.*)$') {
            $level = $Matches[1].Length
            $title = $Matches[2]
            if ($outLines.Count -gt 0 -and $outLines[$outLines.Count - 1] -ne "") { $outLines.Add("") }
            $outLines.Add($title)
            $outLines.Add(($(if ($level -le 1) { "=" } else { "-" })) * [Math]::Max(3, $title.Length))
            continue
        }
        $outLines.Add($text)
    }
    return ($outLines -join "`r`n").TrimEnd() + "`r`n"
}

$committedInfo = [IO.File]::ReadAllText($infoPath, $utf8)
try {
    $hash = (git rev-parse --short HEAD).Trim()
    $dirty = git status --porcelain -- sim ui data project.godot export_presets.cfg
    if ($dirty) { $hash = "$hash-dirty" }
    $date = Get-Date -Format "yyyy-MM-dd"
    $info = [ordered]@{ version = $Version; build = $hash; date = $date } | ConvertTo-Json
    [IO.File]::WriteAllText($infoPath, $info + "`n", $utf8)
    "build_info: $Version $hash $date"

    New-Item -ItemType Directory -Force $stage | Out-Null
    $gdignore = Join-Path $root "build\.gdignore"
    if (-not (Test-Path $gdignore)) { New-Item -ItemType File $gdignore | Out-Null }
    foreach ($old in @($exe, $pack, $zip)) { if (Test-Path $old) { Remove-Item $old -Force } }

    Invoke-Godot @("--headless", "--path", $root, "--export-pack", $preset, $pack)
    $excluded = '^(incoming-art|incoming-audio|shots|docs|\.tools|tools|build|export_templates)/|^assets/figures/residents/|^assets/factions/[^/]*_old|_originals_|\.md$'
    & powershell -NoProfile -File (Join-Path $PSScriptRoot "pack_list.ps1") -Pack $pack -Out (Join-Path $out "pack_contents.txt") -Forbid $excluded
    if ($LASTEXITCODE -ne 0) { throw "Excluded files got into the pack; see build/playtest/pack_contents.txt." }
    "Pack: nothing from the exclude list"
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

    Invoke-Godot @("--headless", "--path", $root, "--export-release", $preset, $exe)
    if (-not (Test-Path $exe)) { throw "No exe at $exe." }
    Get-ChildItem $stage -File | Where-Object { $_.Name -ne "Underline.exe" } | Remove-Item -Force

    [IO.File]::WriteAllText((Join-Path $stage "README_RU.txt"), (ConvertTo-PlainText (Join-Path $root "docs\playtest\TESTER_GUIDE_RU.md")), $utf8Bom)
    [IO.File]::WriteAllText((Join-Path $stage "README_EN.txt"), (ConvertTo-PlainText (Join-Path $root "docs\playtest\TESTER_GUIDE_EN.md")), $utf8Bom)
    [IO.File]::WriteAllText((Join-Path $stage "CREDITS.txt"), (ConvertTo-PlainText (Join-Path $root "CREDITS.md")), $utf8Bom)

    $level = [IO.Compression.CompressionLevel]::Optimal
    $archive = [IO.Compression.ZipFile]::Open($zip, "Create")
    try {
        foreach ($name in @("Underline.exe", "README_RU.txt", "README_EN.txt", "CREDITS.txt")) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $stage $name), $name, $level)
        }
    }
    finally { $archive.Dispose() }
    "exe  {0:N1} MB  {1}" -f ((Get-Item $exe).Length / 1MB), $exe
    "pack {0:N1} MB  {1}" -f ((Get-Item $pack).Length / 1MB), $pack
    "zip  {0:N1} MB  {1}" -f ((Get-Item $zip).Length / 1MB), $zip
}
finally {
    [IO.File]::WriteAllText($infoPath, $committedInfo, $utf8)
}
