# Lists a Godot pack exported as zip (--export-pack <preset> x.zip): files, size by source folder (imported files
# are charged to the source they came from, read from the .import entries) and any path matching -Forbid.
#   powershell -File .tools/pack_list.ps1 -Pack build/playtest/pack_check.zip [-Out list.txt] [-Forbid <regex>]
# Exit code 1 when something matches -Forbid.
param(
    [Parameter(Mandatory = $true)][string]$Pack,
    [string]$Out = "",
    [string]$Forbid = ""
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $Pack))
$rows = @()
$source = @{}
try {
    foreach ($entry in $zip.Entries) {
        $rows += [pscustomobject]@{ Name = $entry.FullName; Size = $entry.Length }
        if ($entry.FullName -match '\.(import|remap)$') {
            $reader = New-Object IO.StreamReader($entry.Open())
            $text = $reader.ReadToEnd()
            $reader.Dispose()
            $from = $entry.FullName -replace '\.(import|remap)$', ''
            foreach ($m in [regex]::Matches($text, 'res://(\.godot/[^"]+)')) { $source[$m.Groups[1].Value] = $from }
        }
    }
}
finally { $zip.Dispose() }

function Get-Folder([string]$path) {
    $parts = $path.Split('/')
    if ($parts.Count -gt 2) { return $parts[0] + '/' + $parts[1] }
    return $parts[0]
}

$lines = New-Object Collections.Generic.List[string]
$total = ($rows | Measure-Object Size -Sum).Sum
$lines.Add(("{0}: {1} files, {2:N1} MB unpacked, {3:N1} MB on disk" -f (Split-Path $Pack -Leaf), $rows.Count, ($total / 1MB), ((Get-Item $Pack).Length / 1MB)))
$lines.Add("")
$lines.Add("By source folder (MB, files):")
$rows | ForEach-Object {
    $origin = if ($source.ContainsKey($_.Name)) { $source[$_.Name] } else { $_.Name }
    [pscustomobject]@{ Folder = (Get-Folder $origin); Size = $_.Size }
} | Group-Object Folder | Sort-Object { -($_.Group | Measure-Object Size -Sum).Sum } | ForEach-Object {
    $lines.Add(("  {0,8:N2}  {1,5}  {2}" -f (($_.Group | Measure-Object Size -Sum).Sum / 1MB), $_.Count, $_.Name))
}
$bad = @()
if ($Forbid -ne "") {
    $bad = @($rows | Where-Object {
        $origin = if ($source.ContainsKey($_.Name)) { $source[$_.Name] } else { $_.Name }
        $_.Name -match $Forbid -or $origin -match $Forbid
    })
    $lines.Add("")
    $lines.Add(("Excluded paths found: {0}" -f $bad.Count))
    $bad | Select-Object -First 30 | ForEach-Object { $lines.Add("  LEAK " + $_.Name) }
}
$lines.Add("")
$lines.Add("Files:")
$rows | Sort-Object Name | ForEach-Object {
    $origin = if ($source.ContainsKey($_.Name)) { "  <- " + $source[$_.Name] } else { "" }
    $lines.Add(("  {0,10}  {1}{2}" -f $_.Size, $_.Name, $origin))
}
if ($Out -ne "") { [IO.File]::WriteAllLines($Out, $lines, (New-Object Text.UTF8Encoding $false)) }
$end = $lines.IndexOf("Files:")
$lines | Select-Object -First $end
if ($bad.Count -gt 0) { exit 1 }
