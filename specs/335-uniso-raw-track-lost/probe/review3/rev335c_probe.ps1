<#
Review 3 of feature 335: Unpack (Alt+F9) of the whole image with "Delete archive after unpacking" on
images made by gen335c.py (real vcdimager VCD / SVCD output; a hole in a VCD stream; a short damaged
track before a stream). Rows report the extracted files and whether the image was kept.
Built on specs\335-uniso-raw-track-lost\probe\iso335_probe.ps1. MUST run through run_on_hidden_desktop.ps1.
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
$Root = $TempRoot + '\tc335'
$StartDir = $Root + '\start'

function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') + ':' + (New-Object IO.FileInfo($_)).Length } | Sort-Object)
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

# PASS = the image kept exactly when $Kept and no window other than none; files reported as facts
function Unpack-Obs([string]$Case, [string]$Img0, [switch]$Kept) {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + [IO.Path]::GetFileName($Img0); [IO.File]::Copy($Img0, $LP + $img)
    $ccd0 = [IO.Path]::ChangeExtension($Img0, '.ccd'); if ($Img0.EndsWith('.img') -and [IO.File]::Exists($ccd0)) { [IO.File]::Copy($ccd0, $LP + [IO.Path]::ChangeExtension($img, '.ccd')) }
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
        $r = Serve $id 90 @(1, 6)
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $files = @(Tgt-Files $tgt)
        $isKept = [IO.File]::Exists($LP + $img)
        $keep = Join-Path $env:TEMP ('rev335c\keep\' + $Case)
        foreach ($f in [IO.Directory]::GetFiles($LP + $tgt, '*', [IO.SearchOption]::AllDirectories)) { $rel = $f.Substring(($LP + $tgt + '\').Length); $dst = Join-Path $keep $rel; [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dst)); [IO.File]::Copy($f, $dst, $true) }
        $ok = (-not $fatal) -and ($msgs -eq 'no window') -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('files {0}: {1}; image kept: {2} (want {3}); fatal: {4}; windows: {5}' -f $files.Count, (($files | ForEach-Object { Esc $_ }) -join ', '), $isKept, [bool]$Kept, (Tail ([string]$fatal) 200), (Tail $msgs 400))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc335_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("rev335c probe {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    Unpack-Obs 'R-VCD-CCD' "$ImgDir\real_vcd.img"
    Unpack-Obs 'R-SVCD-CCD' "$ImgDir\real_svcd.img"
    Unpack-Obs 'R-VCD-NRG' "$ImgDir\real_vcd.nrg"
    Unpack-Obs 'R-VCD-HOLE' "$ImgDir\real_vcd_hole.img" -Kept
    Unpack-Obs 'X-SHORT' "$ImgDir\short_dmg.nrg" -Kept
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
