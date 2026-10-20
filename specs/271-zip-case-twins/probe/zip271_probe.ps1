<#
.SYNOPSIS
    Feature 271 probe: a ZIP archive made on Windows that holds names differing only in case
    (A.txt / a.txt, folders D / d) is listed case-sensitively - the selected twin, and only it, is
    restored, hidden, copied and deleted; folders D and d stay two folders. A ZIP without such names
    behaves as before.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\t.zip written by .NET ZipArchive
    (Windows PowerShell 5.1 = .NET Framework: "version made by" host 0 = MS-DOS / Windows; the row
    reports the host bytes it found); UNIX rows patch every central header's host byte to 3 (Unix);
    <row>\tgt - an empty case-sensitive folder (fsutil file setCaseSensitiveInfo). The left panel
    shows the archive, the right panel tgt.
      ZIP-CONTROL  no twins: Docs/f.txt and z.txt; the left panel is opened at <archive>\DOCS
                   (another case). PASS = the panel is inside Docs (case-insensitive as before)
      ZIP-HIDE     A.txt, a.txt, z.txt. Home, Down, Insert selects the first file; Hide Selected
                   Names (2945), Select All (842), Copy (727, dialogs OK).
                   PASS = tgt holds z.txt and exactly one twin (the other one), with its own content
      ZIP-GLOBAL   the same archive; Insert on the first file, Store Selection (866, OK), Unselect
                   All (844), Restore Selection (867, OK), Copy. PASS = tgt holds exactly one twin,
                   with its own content
      ZIP-TREE     D/x.txt and d/y.txt (no folder entries). Select All, Copy.
                   PASS = the Copy dialog counts 2 directories, tgt\D holds only x.txt and tgt\d
                   only y.txt
      ZIP-ONE      the same archive; Home, Down, Insert selects the first folder, Copy.
                   PASS = tgt holds exactly one file: D/x.txt or d/y.txt
      ZIP-DEL      the same archive; Home, Down, Insert, Delete (729, Yes).
                   PASS = the archive keeps exactly one entry: D/x.txt or d/y.txt
      UNIX-ONE / UNIX-DEL  as ZIP-ONE / ZIP-DEL with the Unix host byte (the listing was
                   case-sensitive before 271; the operation on a folder without its own entry was not)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$Lib,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

# $PSScriptRoot is empty in a parameter default (PS 5.1, feature 253) - computed here
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Root = $TempRoot + '\tc271'
$StartDir = $Root + '\start'

function Dialog-Ok([int]$Id, [int]$Cmd) {
    $dlg = Open-ByCmd $Id $Cmd 10
    if ($dlg -eq [IntPtr]::Zero) { return 'no dialog' }
    $d = WinDesc $dlg
    Click-Ok $dlg
    [void](Serve $Id 20 @(1, 6))
    return (Tail $d 40)
}
function Make-CsDir([string]$d) {
    NewDir $d
    $o = & fsutil.exe file setCaseSensitiveInfo $d enable 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('no case-sensitive folder: ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}
# writes the entries (name -> content, '/'-separated names) into a new ZIP; Unix: host byte 3
function Make-Zip([string]$Zip, [System.Collections.Specialized.OrderedDictionary]$Entries, [bool]$Unix) {
    $fs = [IO.File]::Open($Zip, [IO.FileMode]::CreateNew)
    try {
        $za = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
        foreach ($k in $Entries.Keys) {
            $e = $za.CreateEntry($k)
            $w = New-Object IO.StreamWriter($e.Open(), (New-Object Text.ASCIIEncoding))
            $w.Write([string]$Entries[$k]); $w.Dispose()
        }
        $za.Dispose()
    }
    finally { $fs.Dispose() }
    $b = [IO.File]::ReadAllBytes($Zip)
    $hosts = New-Object System.Collections.ArrayList
    for ($i = 0; $i + 46 -le $b.Length; $i++) {
        if ($b[$i] -eq 0x50 -and $b[$i + 1] -eq 0x4B -and $b[$i + 2] -eq 1 -and $b[$i + 3] -eq 2) {
            if ($Unix) { $b[$i + 5] = 3 }
            [void]$hosts.Add([int]$b[$i + 5])
        }
    }
    if ($Unix) { [IO.File]::WriteAllBytes($Zip, $b) }
    return ('host ' + (@($hosts | Sort-Object -Unique) -join '/') + ' in ' + $hosts.Count + ' central headers')
}
function Zip-Entries([string]$Zip) {
    $za = [System.IO.Compression.ZipFile]::OpenRead($Zip)
    try { return @($za.Entries | ForEach-Object { $_.FullName } | Sort-Object) }
    finally { $za.Dispose() }
}
function Start-Arc([string]$Left, [string]$Right) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T271', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 2000
    [void](Serve $p.Id 10)
    return $p.Id
}
# the files under tgt, relative, '/'-separated, case kept
function Tgt-Files([string]$Tgt) {
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}

function Run-Case([string]$Kind, [string]$Case) {
    $name = $Kind + '-' + $Case
    if (-not (Want $name)) { return }
    $d = $Root + '\' + $name
    $tgt = $d + '\tgt'
    $arc = $d + '\t.zip'
    $e = New-Object System.Collections.Specialized.OrderedDictionary
    if ($Case -eq 'CONTROL') { $e['Docs/f.txt'] = 'F'; $e['z.txt'] = 'z' }
    elseif ($Case -eq 'HIDE' -or $Case -eq 'GLOBAL') { $e['A.txt'] = 'UPPER'; $e['a.txt'] = 'lower'; $e['z.txt'] = 'z' }
    else { $e['D/x.txt'] = 'X'; $e['d/y.txt'] = 'Y' }
    try {
        NewDir $d; Make-CsDir $tgt
        $hostInfo = Make-Zip $arc $e ($Kind -eq 'UNIX')
    }
    catch { Row $name 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        $left = $arc; if ($Case -eq 'CONTROL') { $left = $arc + '\DOCS' }
        $id = Start-Arc $left $tgt
        $steps = New-Object System.Collections.ArrayList
        [void]$steps.Add($hostInfo)
        $msgs = ''
        if ($Case -eq 'CONTROL') {
            $loc = Get-Loc $id
            End-Row $name $id $null $before; $id = 0
            $ok = $loc -match '\\(Docs|DOCS)\\?$'
            Row $name 'RUN' (V $ok) ('panel at: ' + (Tail $loc 60) + '; ' + $hostInfo)
            return
        }
        if ($Case -eq 'TREE') { Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800 }
        else {
            Key $id 0x24; Key $id 0x28; Key $id 0x2D   # Home, Down, Insert: the first item selected
            Start-Sleep -Milliseconds 500
            if ($Case -eq 'HIDE') {
                Post-Cmd (Get-Main $id) 2945; Start-Sleep -Milliseconds 1500
                Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
            }
            elseif ($Case -eq 'GLOBAL') {
                [void]$steps.Add('store: ' + (Dialog-Ok $id 866))
                Post-Cmd (Get-Main $id) 844; Start-Sleep -Milliseconds 500
                [void]$steps.Add('restore: ' + (Dialog-Ok $id 867))
            }
        }
        if ($Case -eq 'DEL') { Post-Cmd (Get-Main $id) 729 } else { Post-Cmd (Get-Main $id) 727 }
        $r = Serve $id 40 @(1, 6)
        $msgs = Msgs $r
        End-Row $name $id $null $before; $id = 0
        if ($Case -eq 'DEL') {
            $left = @(Zip-Entries $arc)
            $ok = ($left.Count -eq 1) -and (($left -ccontains 'D/x.txt') -or ($left -ccontains 'd/y.txt'))
            Row $name 'RUN' (V $ok) ("archive keeps: {0}; steps: {1}; windows: {2}" -f $(if ($left.Count) { $left -join ',' } else { 'nothing' }), ($steps -join ' / '), (Tail $msgs 160))
            return
        }
        $files = @(Tgt-Files $tgt)
        $twins = @($files | Where-Object { $_ -ceq 'A.txt' -or $_ -ceq 'a.txt' })
        # the arrived twin must carry its own content (A.txt UPPER, a.txt lower)
        $own = $true
        foreach ($t in $twins) { $want = $(if ($t -ceq 'A.txt') { 'UPPER' } else { 'lower' }); if ([IO.File]::ReadAllText($LP + $tgt + '\' + $t) -cne $want) { $own = $false } }
        if ($twins.Count) { [void]$steps.Add('content: ' + (($twins | ForEach-Object { $_ + '=' + [IO.File]::ReadAllText($LP + $tgt + '\' + $_) }) -join ',')) }
        if ($Case -eq 'HIDE') { $ok = ($files.Count -eq 2) -and ($files -ccontains 'z.txt') -and ($twins.Count -eq 1) -and $own }
        elseif ($Case -eq 'GLOBAL') { $ok = ($files.Count -eq 1) -and ($twins.Count -eq 1) -and $own }
        elseif ($Case -eq 'ONE') { $ok = ($files.Count -eq 1) -and (($files -ccontains 'D/x.txt') -or ($files -ccontains 'd/y.txt')) }
        # review 271: the Copy dialog must count two folders - the copied files alone pass also for one
        # merged folder (the extraction writes the archive's own names)
        else { $ok = ($files.Count -eq 2) -and ($files -ccontains 'D/x.txt') -and ($files -ccontains 'd/y.txt') -and ($msgs -match 'Copy 2 directories') }
        Row $name 'RUN' (V $ok) ("tgt: {0}; steps: {1}; windows: {2}" -f $(if ($files.Count) { $files -join ',' } else { 'empty' }), ($steps -join ' / '), (Tail $msgs 160))
    }
    catch { Row $name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $name $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc271_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("zip271_probe (feature 271) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    foreach ($c in @('CONTROL', 'HIDE', 'GLOBAL', 'TREE', 'ONE', 'DEL')) { Run-Case 'ZIP' $c }
    foreach ($c in @('ONE', 'DEL')) { Run-Case 'UNIX' $c }
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
}
exit $nf
