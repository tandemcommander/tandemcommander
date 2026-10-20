<#
.SYNOPSIS
    Feature 252 probe: a TAR or 7z archive holding names that differ only in case (A.txt / a.txt,
    folders D / d) is listed case-sensitively - the selected twin, and only it, is restored, hidden
    and copied; folders D and d stay two folders. An archive without such names behaves as before.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\src - a case-sensitive folder
    (fsutil file setCaseSensitiveInfo) with the archive's content; <row>\t.tar (Windows tar.exe) or
    <row>\t.7z (C:\Program Files\7-Zip\7z.exe) made from it; <row>\tgt - an empty case-sensitive
    folder. The left panel shows the archive, the right panel tgt.
      TAR-HIDE / 7Z-HIDE      A.txt, a.txt, z.txt. Home, Down, Insert selects the first file; Hide
                              Selected Names (2945), Select All (842), Copy (727, dialogs OK).
                              PASS = tgt holds z.txt and exactly one of the twins (the other one)
      TAR-GLOBAL / 7Z-GLOBAL  the same archive; Insert on the first file, Store Selection (866, OK),
                              Unselect All (844), Restore Selection (867, OK), Copy.
                              PASS = tgt holds exactly one file, a twin
      TAR-TREE / 7Z-TREE      D\x.txt and d\y.txt. Select All, Copy.
                              PASS = tgt\D holds only x.txt and tgt\d only y.txt
      TAR-CONTROL / 7Z-CONTROL  no twins: Docs\f.txt and z.txt; the left panel is opened at
                              <archive>\DOCS (another case). PASS = the panel is inside Docs
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc252'
$StartDir = $Root + '\start'
$TarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
$SevenZip = 'C:\Program Files\7-Zip\7z.exe'

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
# the archive of the folder's content (items at the archive's root); returns its path
function Make-Archive([string]$Kind, [string]$Src, [string]$Dir) {
    $items = @([IO.Directory]::GetFileSystemEntries($LP + $Src) | ForEach-Object { [IO.Path]::GetFileName($_) })
    if ($Kind -eq 'TAR') {
        $arc = $Dir + '\t.tar'
        $o = & $TarExe -cf $arc -C $Src @items 2>&1
    }
    else {
        $arc = $Dir + '\t.7z'
        $o = & $SevenZip a -t7z -bd -y -ssc $arc ($Src + '\*') 2>&1   # -ssc: twins are two files
    }
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return $arc
}
function Start-Arc([string]$Left, [string]$Right) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T252', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1') -PassThru
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
    if ($Kind -eq 'TAR' -and -not (Test-Path -LiteralPath $TarExe)) { Row $name 'RUN' 'NOT DRIVEN' 'no tar.exe'; return }
    if ($Kind -eq '7Z' -and -not (Test-Path -LiteralPath $SevenZip)) { Row $name 'RUN' 'NOT DRIVEN' 'no 7z.exe'; return }
    $d = $Root + '\' + $name
    $src = $d + '\src'; $tgt = $d + '\tgt'
    try {
        Make-CsDir $src; Make-CsDir $tgt
        if ($Case -eq 'TREE') {
            NewDir ($src + '\D'); NewDir ($src + '\d')
            WriteFile ($src + '\D\x.txt') 'X'; WriteFile ($src + '\d\y.txt') 'Y'
        }
        elseif ($Case -eq 'CONTROL') {
            NewDir ($src + '\Docs'); WriteFile ($src + '\Docs\f.txt') 'F'; WriteFile ($src + '\z.txt') 'z'
        }
        else { WriteFile ($src + '\A.txt') 'UPPER'; WriteFile ($src + '\a.txt') 'lower'; WriteFile ($src + '\z.txt') 'z' }
        $arc = Make-Archive $Kind $src $d
    }
    catch { Row $name 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        $left = $arc; if ($Case -eq 'CONTROL') { $left = $arc + '\DOCS' }
        $id = Start-Arc $left $tgt
        $steps = New-Object System.Collections.ArrayList
        $msgs = ''
        if ($Case -eq 'CONTROL') {
            $loc = Get-Loc $id
            End-Row $name $id $null $before; $id = 0
            $ok = $loc -match '\\(Docs|DOCS)\\?$'
            Row $name 'RUN' (V $ok) ('panel at: ' + (Tail $loc 60))
            return
        }
        if ($Case -eq 'TREE') { Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800 }
        else {
            Key $id 0x24; Key $id 0x28; Key $id 0x2D   # Home, Down, Insert: the first file selected
            Start-Sleep -Milliseconds 500
            if ($Case -eq 'HIDE') {
                Post-Cmd (Get-Main $id) 2945; Start-Sleep -Milliseconds 1500
                Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
            }
            else {
                [void]$steps.Add('store: ' + (Dialog-Ok $id 866))
                Post-Cmd (Get-Main $id) 844; Start-Sleep -Milliseconds 500
                [void]$steps.Add('restore: ' + (Dialog-Ok $id 867))
            }
        }
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 40 @(1, 6)
        $msgs = Msgs $r
        End-Row $name $id $null $before; $id = 0
        $files = @(Tgt-Files $tgt)
        $twins = @($files | Where-Object { $_ -ceq 'A.txt' -or $_ -ceq 'a.txt' })
        if ($Case -eq 'HIDE') { $ok = ($files.Count -eq 2) -and ($files -ccontains 'z.txt') -and ($twins.Count -eq 1) }
        elseif ($Case -eq 'GLOBAL') { $ok = ($files.Count -eq 1) -and ($twins.Count -eq 1) }
        else { $ok = ($files.Count -eq 2) -and ($files -ccontains 'D/x.txt') -and ($files -ccontains 'd/y.txt') }
        Row $name 'RUN' (V $ok) ("tgt: {0}; steps: {1}; windows: {2}" -f $(if ($files.Count) { $files -join ',' } else { 'empty' }), ($steps -join ' / '), (Tail $msgs 160))
    }
    catch { Row $name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $name $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc252_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("arc252_probe (feature 252) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    foreach ($k in @('TAR', '7Z')) {
        Run-Case $k 'CONTROL'
        Run-Case $k 'HIDE'
        Run-Case $k 'GLOBAL'
        Run-Case $k 'TREE'
    }
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
