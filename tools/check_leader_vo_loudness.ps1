# Leader voice loudness gate: every lead_*.ogg in assets/audio/vo within 0.5 dB of -23 LUFS integrated, true peak
# at or below -2.5 dBTP, spread at most 1 dB per faction and overall. Exit code 1 on any miss.
#   powershell -File tools\check_leader_vo_loudness.ps1
param([double]$Target = -23.0, [double]$Window = 0.5, [double]$Peak = -2.5, [double]$Spread = 1.0)
$root = Split-Path -Parent $PSScriptRoot
$ff = Join-Path $root '.tools\ffmpeg\ffmpeg-9.0.2-essentials_build\bin\ffmpeg.exe'
$factions = 'depot', 'directorate', 'synod', 'exchange', 'black_flag'
$bad = @()
$rows = foreach ($f in Get-ChildItem (Join-Path $root 'assets\audio\vo') -Filter 'lead_*.ogg' -File) {
    $o = & $ff -hide_banner -nostats -i $f.FullName -af ebur128=peak=true -f null - 2>&1 | Out-String
    $i = [regex]::Matches($o, 'I:\s+(-?[\d.]+) LUFS')
    $p = [regex]::Matches($o, 'Peak:\s+(-?[\d.]+) dBFS')
    if ($i.Count -eq 0) { $bad += "$($f.Name) did not decode"; continue }
    $row = [pscustomobject]@{
        File = $f.Name
        Faction = $factions | Where-Object { $f.Name.StartsWith("lead_${_}_") } | Select-Object -First 1
        LUFS = [double]$i[$i.Count - 1].Groups[1].Value
        TP = [double]$p[$p.Count - 1].Groups[1].Value
    }
    if ([math]::Abs($row.LUFS - $Target) -gt $Window) { $bad += "{0} at {1:N1} LUFS" -f $row.File, $row.LUFS }
    if ($row.TP -gt $Peak) { $bad += "{0} peaks at {1:N1} dBTP" -f $row.File, $row.TP }
    $row
}
if ($rows.Count -ne 110) { $bad += "found $($rows.Count) leader files, expected 110" }
foreach ($group in @($factions | ForEach-Object { , @($_, @($rows | Where-Object Faction -eq $_)) }) + , @('all', @($rows))) {
    $set = @($group[1] | Sort-Object LUFS)
    if ($set.Count -eq 0) { $bad += "no files for $($group[0])"; continue }
    $range = $set[-1].LUFS - $set[0].LUFS
    "{0,-12} n={1,3}  min {2,6:N1}  median {3,6:N1}  max {4,6:N1}  spread {5,4:N1} dB  max TP {6,5:N1}" -f $group[0], $set.Count, $set[0].LUFS, $set[[int][math]::Floor($set.Count / 2)].LUFS, $set[-1].LUFS, $range, ($set | Measure-Object TP -Maximum).Maximum
    if ($range -gt $Spread) { $bad += "{0} spread {1:N1} dB" -f $group[0], $range }
}
if ($bad.Count -gt 0) { $bad | ForEach-Object { "FAIL $_" }; 'LEADER VO LOUDNESS FAILED'; exit 1 }
'LEADER VO LOUDNESS OK'
