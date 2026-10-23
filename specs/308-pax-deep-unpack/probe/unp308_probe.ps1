<#
.SYNOPSIS
    Feature 308 probe (backlog item whole-archive-unpack-of-a-pax-tar-skips-deep-members-and-may): an
    extraction of a PAX tar extracts every member a file system takes, also those deeper than the
    panel listing holds; a member no file system takes fails the whole unpack, so "Delete archive
    after unpacking" keeps the archive.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\src\t.tar (t.deb) made by Python's
    tarfile through mkunp308.py (next to this script, PAX format) and an empty <row>\tgt.
    DEEP = ten folders of 29 letters (a*29/b*29/.../j*29, folder part 299 bytes; the listing holds 255).
    The deep tree: a*29/top.txt, DEEP/f01..f30.txt, CJK(90)/c.txt (folder part 270 bytes), the folder
    CJK(255) (765 bytes) and CJK(255)/in.txt, ok.txt - 34 files.
    Unpack rows: the left panel shows <row>\src, Home, End focuses the archive, Alt+F9 (851) opens the
    Unpack dialog, the path field (210) is set to <row>\tgt by WM_SETTEXT, the mask stays "*.*",
    "Delete archive after unpacking" (6210) is checked for the -DEL rows, OK, every box answered OK / Yes.
      UNP-DEEP         the deep tree            -> all 34 files, nothing asked, t.tar kept
      UNP-DEEP-DEL     the deep tree + Delete   -> all 34 files, nothing asked, t.tar deleted (all extracted)
      UNP-TOOLONG-DEL  CJK(300).txt (300 UTF-16 units: no file system takes it), ok.txt + Delete
                                                -> ok.txt, a "(206)" box with the path, t.tar KEPT
      UNP-DEB          t.deb: control; data.tar with a.txt, a*125/b*125/f.txt (251 bytes, over the listing
                       with its "data\"), DEEP/d.txt, ok.txt -> all 5 files, nothing asked, t.deb kept
    Copy row: the left panel opens t.tar, the right shows tgt; Select All (842), Copy (727), boxes OK.
      COPY-DEEP        the deep tree: the listing shows a*29 (holding top.txt), the top-level folder CJK(255)
                       (feature 321: a top-level folder name is not byte-bounded, as in 0.1.10) and ok.txt;
                       copying the folders copies their whole subtrees -> top.txt, DEEP/f01..f30.txt,
                       CJK(255)/in.txt, ok.txt (33 files)
      COPY-TOOLONG     a*29/top.txt, a*29/CJK(300).txt, ok.txt: the folder is copied -> top.txt, ok.txt and a
                       "(206)" box DURING the copy (the one at opening is not enough)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\299-unpack-dialog-text-fits\probe\unpack299_probe.ps1
    and specs\306-tar-pax-headers\probe\pax306_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Lib) { $Lib = Join-Path $Here '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc308'
$StartDir = $Root + '\start'
$MkUnp = Join-Path $Here 'mkunp308.py'

function Cjk([int]$n, [int]$start = 0x4E00) { $sb = New-Object Text.StringBuilder; for ($i = 0; $i -lt $n; $i++) { [void]$sb.Append([char]($start + $i)) }; return $sb.ToString() }
$Deep = (@(0..9 | ForEach-Object { [string][char](97 + $_) * 29 })) -join '/'
# expected files: relative path ('/') -> content
function Deep-Tree([switch]$Listed) {
    $w = [ordered]@{}
    $w[('a' * 29) + '/top.txt'] = 'T'
    for ($i = 1; $i -le 30; $i++) { $w[('{0}/f{1:00}.txt' -f $Deep, $i)] = ('F{0:00}' -f $i) }
    if (-not $Listed) { $w[(Cjk 90) + '/c.txt'] = 'C' }
    $w[(Cjk 255) + '/in.txt'] = 'I' # feature 321: its top-level folder is listed, so a copy of it extracts in.txt
    $w['ok.txt'] = 'K'
    return $w
}
function Tgt-Files([string]$Tgt) {
    if (-not [IO.Directory]::Exists($LP + $Tgt)) { return @() }
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) }
function Short([string]$s) { if ($s.Length -le 24) { return $s }; return ('{0}..[{1} chars]..{2}' -f $s.Substring(0, 8), $s.Length, $s.Substring($s.Length - 8)) }
# compares tgt with $Want: returns @(ok, facts)
function Check-Tgt([string]$Tgt, $Want) {
    $files = @(Tgt-Files $Tgt)
    $ok = ($files.Count -eq $Want.Count)
    $missing = @($Want.Keys | Where-Object { $files -notcontains $_ })
    $bad = @($Want.Keys | Where-Object { $files -contains $_ -and (Content $Tgt $_) -cne $Want[$_] })
    if ($missing.Count -or $bad.Count) { $ok = $false }
    $f = ('tgt: {0} of {1} files' -f $files.Count, $Want.Count)
    if ($missing.Count) { $f += ('; missing {0}: {1}' -f $missing.Count, ((@($missing | Select-Object -First 4 | ForEach-Object { Esc (Short $_) })) -join ', ')) }
    if ($bad.Count) { $f += ('; wrong content: ' + ((@($bad | ForEach-Object { Esc (Short $_) })) -join ', ')) }
    return @($ok, $f)
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
function Make-Fixture([string]$Row, [string]$Arc) {
    $o = & $Python -I $MkUnp $Row $Arc 2>&1
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($Arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}

# Unpack (Alt+F9) of the whole archive into tgt; $Want = expected files; $Need206 = a "(206)" box
# required (else nothing may be asked); $Delete = check "Delete archive after unpacking"; $ArcGone =
# the archive must be deleted afterwards (else kept)
function Unpack-Row([string]$Case, $Want, [switch]$Need206, [switch]$Delete, [switch]$ArcGone, [string]$Ext = 'tar') {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\src\t.' + $Ext; $tgt = $d + '\tgt'
    try { NewDir ($d + '\src'); NewDir $tgt; Make-Fixture $Case $arc }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $fatal = $null; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $id = Start-Tc ($d + '\src')
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 851 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Unpack') { throw ("851 opened '{0}', not the Unpack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        Set-Field $dlg 210 $tgt
        if ($Delete) {
            $b = Find-Btn $dlg 6210
            if (-not $b -or -not [Drv098f]::IsWindowEnabled($b)) { throw 'the box "Delete archive after unpacking" (6210) is missing or disabled' }
            [void][Drv098f]::Send($b, 0x00F1, 1, 0, 5000)   # BM_SETCHECK BST_CHECKED
        }
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 90 @(1, 6)
        $msgs = Msgs $r
        $fatal = Fatal-Win $id
        End-Row $Case $id $fatal $before; $id = 0
        $c = Check-Tgt $tgt $Want
        $kept = [IO.File]::Exists($LP + $arc)
        $has206 = $msgs -match '\(206\)'
        $asked = ($msgs -ne 'no window')
        $ok = $c[0] -and (-not $fatal) -and ($kept -ne [bool]$ArcGone)
        if ($Need206) { $ok = $ok -and $has206 } else { $ok = $ok -and (-not $asked) }
        Row $Case 'RUN' (V $ok) ('{0}; archive kept: {1} (want {2}); "(206)" shown: {3}; windows: {4}' -f $c[1], $kept, (-not $ArcGone), $has206, (Tail $msgs 260))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

function Copy-Row([string]$Case, $Want, [switch]$Need206) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $arc = $d + '\t.tar'; $tgt = $d + '\tgt'
    try { NewDir $d; NewDir $tgt; Make-Fixture $Case $arc }
    catch { Row $Case 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $tgt) }
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T308', '-l', ('"{0}"' -f $arc), '-r', ('"{0}"' -f $tgt), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        if ((Get-Main $id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        $openMsgs = Msgs (Serve $id 10)
        $loc = Get-Loc $id
        if (-not $loc.StartsWith($arc, [StringComparison]::OrdinalIgnoreCase)) { throw ('the archive did not open; panel at: ' + (Tail $loc 80)) }
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        Post-Cmd (Get-Main $id) 727
        $msgs = Msgs (Serve $id 60 @(1, 6))
        End-Row $Case $id $null $before; $id = 0
        $c = Check-Tgt $tgt $Want
        $ok = $c[0]
        $copy206 = $msgs -match '\(206\)'
        if ($Need206) { $ok = $ok -and $copy206 }
        Row $Case 'RUN' (V $ok) ('{0}; "(206)" during the copy: {1}; at open: {2}; windows: {3}' -f $c[1], $copy206, (Tail $openMsgs 120), (Tail $msgs 200))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc308_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("unp308_probe (feature 308) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; python {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), ((& $Python --version 2>&1) -join ' '))
    Out ''
    Unpack-Row 'UNP-DEEP' (Deep-Tree)
    Unpack-Row 'UNP-DEEP-DEL' (Deep-Tree) -Delete -ArcGone
    $tl = [ordered]@{ 'ok.txt' = 'K' }
    Unpack-Row 'UNP-TOOLONG-DEL' $tl -Need206 -Delete
    $deb = [ordered]@{ 'control/control' = "Package: x`n"; 'data/a.txt' = 'A'; ('data/' + ('a' * 125) + '/' + ('b' * 125) + '/f.txt') = 'F'; ('data/' + $Deep + '/d.txt') = 'D'; 'data/ok.txt' = 'K' }
    Unpack-Row 'UNP-DEB' $deb -Ext 'deb'
    Copy-Row 'COPY-DEEP' (Deep-Tree -Listed)
    Copy-Row 'COPY-TOOLONG' ([ordered]@{ (('a' * 29) + '/top.txt') = 'T'; 'ok.txt' = 'K' }) -Need206
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
