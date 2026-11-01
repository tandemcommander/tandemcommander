<#
Feature 366: Unpack (Alt+F9) of the whole image with "Delete archive after unpacking" on the images img366.py
made from real vcdimager 2.0.1 output. Each row compares every extracted file (size, SHA-256) with
expect.json (a Form 2 video file: 2324 bytes of each of its sectors; any other file: as before), checks that
the files expected absent are absent, and the image's fate. Built on 335's review3\rev335c_probe.ps1.
MUST run through tools\run_on_hidden_desktop.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$ImgDir,
    [Parameter(Mandatory = $true)][string]$Lib,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }
. $Lib
$Root = $TempRoot + '\tc366'
$StartDir = $Root + '\start'
$Expect = Get-Content -LiteralPath (Join-Path $ImgDir 'expect.json') -Raw | ConvertFrom-Json

function Sha([string]$Path) {
    $s = [Security.Cryptography.SHA256]::Create()
    $fs = [IO.File]::OpenRead($Path)
    try { return (($s.ComputeHash($fs) | ForEach-Object { $_.ToString('x2') }) -join '') } finally { $fs.Dispose() }
}
function Tgt-Map([string]$Tgt) {
    $m = @{}
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return $m }
    $base = ($LP + $Tgt + '\')
    foreach ($f in [IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories)) {
        $m[$f.Substring($base.Length).Replace('\', '/')] = @((New-Object IO.FileInfo($f)).Length, (Sha $f))
    }
    return $m
}
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}

# $Kept: $true / $false = the image's fate checked; $null = reported only. $Windows: boxes allowed (a read error);
# $Answer: the button ids Serve clicks (173 = Skip of the read-error box).
function Unpack-Row([string]$Case, $Kept, [switch]$Windows, [int[]]$Answer = @(1, 6)) {
    if (-not (Want $Case)) { return }
    $e = $Expect.$Case
    if (-not $e) { Row $Case 'RUN' 'NOT DRIVEN' 'no expectation'; return }
    $img0 = Join-Path $ImgDir $e.image
    if (-not [IO.File]::Exists($img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $img0); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + $e.image; [IO.File]::Copy($img0, $LP + $img)
    $ccd0 = [IO.Path]::ChangeExtension($img0, '.ccd'); if ($img0.EndsWith('.img') -and [IO.File]::Exists($ccd0)) { [IO.File]::Copy($ccd0, $LP + [IO.Path]::ChangeExtension($img, '.ccd')) }
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 851 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Unpack') { throw ("851 opened '{0}', not the Unpack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        Set-Field $dlg 210 $tgt
        $btn = Find-Btn $dlg 6210
        if (-not $btn -or -not [Drv098f]::IsWindowEnabled($btn)) { throw 'the box "Delete archive after unpacking" (6210) is missing or disabled' }
        [void][Drv098f]::Send($btn, 0x00F1, 1, 0, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 90 $Answer
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $got = Tgt-Map $tgt
        $isKept = [IO.File]::Exists($LP + $img)
        $bad = New-Object System.Collections.ArrayList
        foreach ($p in $e.files.PSObject.Properties) {
            $w = $p.Value
            if (-not $got.ContainsKey($p.Name)) { [void]$bad.Add($p.Name + ' missing'); continue }
            $g = $got[$p.Name]
            if ([long]$g[0] -ne [long]$w[0] -or $g[1] -ne $w[1]) { [void]$bad.Add(('{0} {1} bytes {2} (want {3} {4})' -f $p.Name, $g[0], $g[1].Substring(0, 12), $w[0], $w[1].Substring(0, 12))) }
        }
        foreach ($a in @($e.absent)) { if ($a -and $got.ContainsKey($a)) { [void]$bad.Add($a + ' present (want absent)') } }
        foreach ($k in $got.Keys) { if (-not $e.files.PSObject.Properties[$k]) { [void]$bad.Add($k + ' unexpected') } }
        $src = ''
        if ($e.source) {
            $sp = Join-Path (Join-Path $env:TEMP 'rev335c\data') $e.source[1]
            $fp = $LP + $tgt + '\' + $e.source[0].Replace('/', '\')
            if ([IO.File]::Exists($sp) -and [IO.File]::Exists($fp)) {
                $a = [IO.File]::ReadAllBytes($fp); $b = [IO.File]::ReadAllBytes($sp)
                $hexA = [BitConverter]::ToString($a); $hexB = [BitConverter]::ToString($b)
                $src = ('; source {0} ({1} bytes) whole in it: {2}' -f $e.source[1], $b.Length, $hexA.Contains($hexB))
                if (-not $hexA.Contains($hexB)) { [void]$bad.Add($e.source[0] + ' does not contain ' + $e.source[1]) }
            }
        }
        $fateOk = ($null -eq $Kept) -or ($isKept -eq [bool]$Kept)
        $winOk = $Windows -or ($msgs -eq 'no window')
        $ok = (-not $fatal) -and $winOk -and $fateOk -and ($bad.Count -eq 0)
        $files = @($got.Keys | Sort-Object | ForEach-Object { '{0}:{1}' -f $_, $got[$_][0] })
        Row $Case 'RUN' (V $ok) ('files {0}: {1}; mismatches: {2}{3}; image kept: {4} (want {5}); fatal: {6}; windows: {7}' -f $files.Count, ($files -join ', '), $(if ($bad.Count) { $bad -join ' | ' } else { 'none' }), $src, $isKept, $(if ($null -eq $Kept) { 'any' } else { [bool]$Kept }), (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc366_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso366 probe {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    Unpack-Row 'R-VCD-CCD' $false
    Unpack-Row 'R-VCD-NRG' $false
    Unpack-Row 'R-SVCD-CCD' $false
    Unpack-Row 'R-VCD-BIN' $null
    Unpack-Row 'C-MIXED' $false
    Unpack-Row 'C-NOXA' $false
    Unpack-Row 'C-F1SUB' $false
    Unpack-Row 'C-COOKED' $null
    Unpack-Row 'C-CUT' $true -Windows -Answer @(1, 6, 173)
    Unpack-Row 'C-SHORT240' $true
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
