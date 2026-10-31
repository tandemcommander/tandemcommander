<#
.SYNOPSIS
    Feature 363: a UDF file identifier whose implementation-use length (L_IU) or name length (L_FI) puts its
    name past the ISO plug-in's two-sector folder buffer is a damaged identifier. The folder walk read the name
    there without a bound (up to 64 KB past a stack buffer); now such an identifier is refused like an invalid
    tag ("Invalid UDF Tag ID."), the folder's walk ends and the listing is marked incomplete (feature 330), so a
    whole unpack with "Delete archive after unpacking" keeps the image.

.DESCRIPTION
    Seed (WSL Ubuntu): ud.iso by specs\330-iso-unreadable-folder\probe\mkimg330.sh (genisoimage -udf: ISO 9660 +
    UDF of a/side.txt SIDE, top.txt TOP, zlast/z.txt Z). img363.py (this folder) changes one identifier:
      x_aiu    the root's identifier of folder a: L_IU 0xFFFF
      x_tiu    the root's identifier of top.txt: L_IU 0xFFFF
      x_siu    folder a's identifier of side.txt: L_IU 0xFFFF
      x_aiu4k  the root's identifier of folder a: L_IU 0x1000 (past the 4 KB buffer, inside 64 KB)
      x_afi    the root's identifier of folder a: L_IU 4000, L_FI 255 (the name starts inside, ends past)
    Listing rows: the left panel shows <row>\src, Home, End, Enter (posted) on the image.
      L-AIU, L-AIU4K, L-AFI   PASS = "Invalid UDF Tag ID", the program answers, no bug report
      L-UD        (control) ud.iso: no window
    Unpack rows: Alt+F9 (851), the target field (210) <row>\tgt, "Delete archive after unpacking" (6210)
    checked, OK; exactly the listed files with their content.
      R-AIU, R-AIU4K, R-AFI   "Invalid UDF Tag ID"; the ISO 9660 part's files only (the UDF root's walk ends at
                  folder a), KEPT
      R-TIU       "Invalid UDF Tag ID"; the ISO 9660 part and UDF a/side.txt (the walk ends at top.txt), KEPT
      R-SIU       "Invalid UDF Tag ID"; the ISO 9660 part and UDF top.txt (folder a's walk ends; 330: no later
                  folder is descended after a folder that could not be read), KEPT
      C-UD        (control) ud.iso: every file of both parts, no window, deleted
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does not answer
    within 10 s. Without WSL Ubuntu the rows are NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\362-uniso-udf-folder-no-descs\probe\iso362_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$Specs
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Specs) { $Specs = Join-Path $Here '..\..' }
if (-not $Lib) { $Lib = Join-Path $Specs '098-long-path-overruns\probe\fix_probe_lib.ps1' }
$MkUd = Join-Path $Specs '330-iso-unreadable-folder\probe\mkimg330.sh'
$Py = Join-Path $Here 'img363.py'
. $Lib
$Root = $TempRoot + '\tc363'
$StartDir = $Root + '\start'
$BadTag = 'Invalid UDF Tag ID'

function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }
function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { try { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) } catch { return '<none>' } }
function Find-Btn([IntPtr]$Dlg, [int]$CtlId) {
    return (@([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Button' -and [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1)
}
function Set-Field([IntPtr]$Dlg, [int]$CtlId, [string]$Text) {
    $f = Find-Ctl $Dlg $CtlId
    if ($f -eq [IntPtr]::Zero) { throw "field $CtlId not found" }
    [void][Drv098f]::SetText($f, $Text, 5000)
    if ([Drv098f]::GetText($f, 5000) -cne $Text) { throw "field $CtlId did not take the text" }
}
function Check-Files([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $low = @($files | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @($Want.Keys | Where-Object { $low -notcontains $_.ToLowerInvariant() })
    $bad = @($Want.Keys | Where-Object { $low -contains $_.ToLowerInvariant() } | Where-Object {
            $k = $_.ToLowerInvariant(); $real = @($files | Where-Object { $_.ToLowerInvariant() -eq $k })[0]
            $Want[$_] -ne $null -and (Content $Tgt $real) -cne $Want[$_] })
    $ok = ($files.Count -eq $Want.Count -and $missing.Count -eq 0 -and $bad.Count -eq 0)
    $f = ('files {0}: {1}' -f $files.Count, ((@($files | ForEach-Object { Esc $_ })) -join ', '))
    if ($missing.Count) { $f += ('; missing: ' + ($missing -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ($bad -join ', ')) }
    return @($ok, $f)
}
# $Rx: the windows' text as a regex; '' = no window at all
function Windows-Ok([string]$Msgs, [string]$Rx) {
    if ($Rx) { return ($Msgs -match $Rx) }
    return ($Msgs -eq 'no window')
}

# Unpack (Alt+F9) of the whole image into tgt with "Delete archive after unpacking"; $Kept = the image must be
# kept (damaged), else deleted (control)
function Unpack-Row([string]$Case, [string]$Img0, [string]$Name, $WantFiles, [switch]$Kept, [string]$Rx = '') {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; $tgt = $d + '\tgt'; NewDir ($d + '\src'); NewDir $tgt
    $img = $d + '\src\' + $Name; [IO.File]::Copy($Img0, $LP + $img)
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
        [void][Drv098f]::Send($btn, 0x00F1, 1, 0, 5000)   # BM_SETCHECK BST_CHECKED
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 60 @(1, 6)
        $msgs = Msgs $r
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Files $tgt $WantFiles
        $isKept = [IO.File]::Exists($LP + $img)
        $winOk = Windows-Ok $msgs $Rx
        $ok = $c[0] -and (-not $fatal) -and (-not $r.TimedOut) -and $winOk -and ($isKept -eq [bool]$Kept)
        Row $Case 'RUN' (V $ok) ('{0}; files ok: {1}; image kept: {2} (want {3}); windows ok ({4}): {5}; timed out: {6}; fatal: {7}; windows: {8}' -f $c[1], $c[0], $isKept, [bool]$Kept, $(if ($Rx) { '"' + $Rx + '"' } else { 'none' }), $winOk, $r.TimedOut, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# Enter on the image (posted, so a box inside the listing does not block the probe)
function List-Row([string]$Case, [string]$Img0, [string]$Name, [string]$Rx = '') {
    if (-not (Want $Case)) { return }
    if (-not [IO.File]::Exists($Img0)) { Row $Case 'RUN' 'NOT DRIVEN' ('no image ' + $Img0); return }
    $d = $Root + '\' + $Case; NewDir ($d + '\src')
    $img = $d + '\src\' + $Name; [IO.File]::Copy($Img0, $LP + $img)
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $img.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $img) }
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $l = Get-LeftList $id
        [void][Drv098f]::PostMessageW($l, 0x0100, [IntPtr]0x0D, [IntPtr]1)
        [void][Drv098f]::PostMessageW($l, 0x0101, [IntPtr]0x0D, [IntPtr]0xC0000001L)
        Start-Sleep -Milliseconds 800
        $r = Serve $id 60 @(1, 6)
        $msgs = Msgs $r
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $alive = Test-Alive $id
        End-Row $Case $id $fatal $before; $id = 0
        $winOk = Windows-Ok $msgs $Rx
        $ok = $alive -and (-not $r.Died) -and (-not $fatal) -and (-not $r.TimedOut) -and $winOk
        Row $Case 'RUN' (V $ok) ('alive: {0}; windows ok ({1}): {2}; timed out: {3}; fatal: {4}; windows: {5}' -f $alive, $(if ($Rx) { '"' + $Rx + '"' } else { 'none' }), $winOk, $r.TimedOut, (Tail ([string]$fatal) 300), (Tail $msgs 500))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc363_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso363_probe (feature 363) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath $MkUd) (WslPath $s) 2>&1
    $made = @()
    if ([IO.File]::Exists("$s\ud.iso")) {
        foreach ($k in @('aiu', 'tiu', 'siu', 'aiu4k', 'afi')) { $made += & python -I $Py $k "$s\ud.iso" "$s\x_$k.bin" 2>&1 }
    }
    $ErrorActionPreference = $old
    Out ("seeds: {0}" -f ((@([IO.Directory]::GetFiles($s, '*.*') | ForEach-Object { [IO.Path]::GetFileName($_) + '=' + ([IO.FileInfo]$_).Length }) | Sort-Object) -join ','))
    foreach ($m in $made) { Out ('img363: ' + "$m") }
    if (-not [IO.File]::Exists("$s\ud.iso")) { Out ('mkimg330.sh: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    Out ''

    $udAll = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/a/side.txt' = 'SIDE'; 'UDF (TC330)/top.txt' = 'TOP'; 'UDF (TC330)/zlast/z.txt' = 'Z' }
    $udIso = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z' }
    $udA = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/a/side.txt' = 'SIDE' }
    $udTop = [ordered]@{ 'ISO (TC330)/a/side.txt' = 'SIDE'; 'ISO (TC330)/top.txt' = 'TOP'; 'ISO (TC330)/zlast/z.txt' = 'Z'
        'UDF (TC330)/top.txt' = 'TOP' }

    List-Row 'L-AIU' "$s\x_aiu.bin" 'aiu.iso' $BadTag
    List-Row 'L-AIU4K' "$s\x_aiu4k.bin" 'aiu4k.iso' $BadTag
    List-Row 'L-AFI' "$s\x_afi.bin" 'afi.iso' $BadTag
    List-Row 'L-UD' "$s\ud.iso" 'ud.iso'
    Unpack-Row 'R-AIU' "$s\x_aiu.bin" 'aiu.iso' $udIso -Kept -Rx $BadTag
    Unpack-Row 'R-TIU' "$s\x_tiu.bin" 'tiu.iso' $udA -Kept -Rx $BadTag
    Unpack-Row 'R-SIU' "$s\x_siu.bin" 'siu.iso' $udTop -Kept -Rx $BadTag
    Unpack-Row 'R-AIU4K' "$s\x_aiu4k.bin" 'aiu4k.iso' $udIso -Kept -Rx $BadTag
    Unpack-Row 'R-AFI' "$s\x_afi.bin" 'afi.iso' $udIso -Kept -Rx $BadTag
    Unpack-Row 'C-UD' "$s\ud.iso" 'ud.iso' $udAll
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
