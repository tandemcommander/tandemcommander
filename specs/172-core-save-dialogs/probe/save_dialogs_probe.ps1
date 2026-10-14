<#
.SYNOPSIS
    Feature 172 probe: the core's file dialogs - Configuration export (855), the viewer's Copy to
    File (6067) and Open File (6050) - save / open the name the user typed, also with letters
    outside the code page.

.DESCRIPTION
    Export rows: command 855; the question "save the configuration first?" answered No, the
    information box OK, then the file name typed into the save dialog (wide WM_SETTEXT) and Save.
    Viewer rows: the folder with one source file, End (focus the file), F3 (742), Copy to File
    (6067) in the viewer, the name typed, Save.
    PASS = the folder holds exactly the typed name (read wide) and the right content (a .reg
    export header / the source bytes); nothing else was created.
      EX-ASCII   cfg-ascii.reg                        (control)
      EX-CZ      Czech letters (inside code page 1250)
      EX-CYR     Cyrillic letters (outside 1250)
      EX-CYRDIR  an ASCII name in a Cyrillic folder
      VW-ASCII / VW-CZ / VW-CYR / VW-CYRDIR  the same for the viewer
      VW-OVER    a Czech name that exists: "already exists" answered Yes, the content replaced
      VW-LONG    a name of 140 z-caron letters (280 bytes of UTF-8, more than MAX_PATH)
      VW-INIT    the dialog's suggested name for a source with Czech letters (INIT row)
      VW-OPEN    the viewer's Open File (6050): a file with a Czech name / in a Cyrillic folder
                 typed into the open dialog - the viewer shows it (its title names it)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
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
$Root = $TempRoot + '\tc172'
$StartDir = $Root + '\start'
function C([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
$CzName = C @(0x7A, 0xE1, 0x6C, 0x6F, 0x68, 0x61, 0x2D, 0x11B, 0x161, 0x10D)   # zaloha-esc with acute / carons
$CyrName = C @(0x440, 0x435, 0x437, 0x435, 0x440, 0x432)                      # rezerv in Cyrillic
$CyrDir = C @(0x418, 0x432, 0x430, 0x43D)                                      # Ivan in Cyrillic
$CzSrc = C @(0x17E, 0x6C, 0x75, 0x165, 0xE1, 0x6B)                             # zlutak with caron / acute
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
# the file name field of a save dialog: the edit inside the combo box 1148 (old style) or the
# edit 1001 inside a combo box (the Vista dialog), only in a window that has a shell view (1121)
function NameBox([IntPtr]$Dlg) {
    if (-not (Kid $Dlg 1121 $null)) { return $null }
    return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::Cls([Drv098f]::GetParent($_)) -match 'ComboBox' -and ([Drv098f]::GetDlgCtrlID($_) -eq 1001 -or [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) -eq 1148) }) | Select-Object -First 1
}
function Names([string]$d) { if (-not [IO.Directory]::Exists($LP + $d)) { return @() }; return @([IO.Directory]::GetFileSystemEntries($LP + $d) | ForEach-Object { [IO.Path]::GetFileName($_) }) }

# posts the command to the window, answers the boxes before the save dialog (No, then OK), types
# the name and saves; returns what it saw
function Drive-Save([int]$Id, [IntPtr]$Win, [int]$Cmd, [string]$Full) {
    $r = [pscustomobject]@{ Ok = $false; Note = ''; Pre = @(); Init = $null; After = $null }
    $known = Get-Tops $Id
    Post-Cmd $Win $Cmd
    $od = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 20 -and $od -eq [IntPtr]::Zero) {
        $c = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' }) | Select-Object -First 1
        if ($c) {
            # the save dialog builds its children late: up to 5 s for the file name box (1148)
            $sw2 = [Diagnostics.Stopwatch]::StartNew()
            while ($sw2.Elapsed.TotalSeconds -lt 5 -and -not (NameBox $c) -and [Drv098f]::Txt($c) -notmatch '^(Question|Information)$') { Start-Sleep -Milliseconds 200 }
            Start-Sleep -Milliseconds 600
            if ((NameBox $c)) { $od = $c; break }
            $d = WinDesc $c
            $r.Pre += $d
            if ((Kid $c 1121 $null)) { $r.Pre += ('KIDS: ' + ((@([Drv098f]::Kids($c) | ForEach-Object { '{0}#{1}<{2}#{3}' -f [Drv098f]::Cls($_), [Drv098f]::GetDlgCtrlID($_), [Drv098f]::Cls([Drv098f]::GetParent($_)), [Drv098f]::GetDlgCtrlID([Drv098f]::GetParent($_)) })) -join ' ')) }
            # only the two known boxes are answered (No to "save first?", OK to the information);
            # anything else is cancelled - never a Save into a folder the probe did not choose
            $want = $(if ($d -match 'Do you want to save configuration') { 7 } elseif ($d -match 'If you want to import configuration') { 1 } else { 2 })
            $y = Buttons $c | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1
            if ($y) { Click $y } else { Post-Cmd $c 2 }
            $known = @($known) + @($c); Start-Sleep -Milliseconds 800; continue
        }
        Start-Sleep -Milliseconds 200
    }
    if ($od -eq [IntPtr]::Zero) { $r.Note = 'no save dialog; before it: ' + ($r.Pre -join ' || '); return $r }
    $fn = NameBox $od
    if (-not $fn) { $r.Note = 'no file name field'; Post-Cmd $od 2; return $r }
    $r.Init = [Drv098f]::GetText($fn, 5000)
    if ([string]::IsNullOrEmpty($Full)) { Post-Cmd $od 2; Start-Sleep -Milliseconds 800; $r.Ok = $true; return $r }
    [void][Drv098f]::SetText($fn, $Full, 5000)
    $ok = Buttons $od | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 } | Select-Object -First 1
    if ($ok) { Click $ok } else { Post-Cmd $od 1 }
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 10 -and [Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { Start-Sleep -Milliseconds 100 }
    if ([Drv098f]::IsWindow($od) -and [Drv098f]::IsWindowVisible($od)) { $r.Note = 'the save dialog stayed open: ' + (WinDesc $od); Post-Cmd $od 2; Start-Sleep -Milliseconds 800 }
    $r.Ok = $true
    return $r
}

function Check-Folder([string]$Case, [string]$Dir, [string]$Name, [scriptblock]$Content, $r, $after) {
    $names = @(Names $Dir)
    $okName = $names.Count -eq 1 -and $names[0] -ceq $Name
    $okBody = $false
    if ($okName) { $okBody = & $Content ([IO.File]::ReadAllBytes($LP + $Dir + '\' + $Name)) }
    Row $Case 'FILE' (V ($okName -and $okBody)) ("typed '{0}' -> folder holds {1}; content {2}; {3}windows after: {4}" -f (Esc $Name), (($names | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', '), $(if ($okName) { $okBody } else { '-' }), $(if ($r.Note) { $r.Note + '; ' } else { '' }), (Msgs $after))
}

$IsReg = { param($b) $t = [Text.Encoding]::ASCII.GetString($b, 0, [Math]::Min(80, $b.Length)); $u = $(if ($b.Length -gt 4) { [Text.Encoding]::Unicode.GetString($b, 2, [Math]::Min(78, $b.Length - 2)) } else { '' }); return ($t.StartsWith('REGEDIT4') -or $u.StartsWith('Windows Registry Editor')) }
$SrcBody = 'hello 172 - the viewer copy'
$IsSrc = { param($b) return ([Text.Encoding]::ASCII.GetString($b) -ceq $SrcBody) }

function Run-Export([string]$Case, [string]$Dir, [string]$Name) {
    if (-not (Want $Case)) { return }
    NewDir $Dir
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $StartDir
        $r = Drive-Save $id (Get-Main $id) 855 ($Dir + '\' + $Name)
        $after = Serve $id 20 @(1, 6)
        Out ('           pre ' + (Esc ($r.Pre -join ' || ')))
        End-Row $Case $id $null $before; $id = 0
        Check-Folder $Case $Dir $Name $IsReg $r $after
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

function Run-Viewer([string]$Case, [string]$Src, [string]$Dir, [string]$Name, [string]$Existing) {
    if (-not (Want $Case)) { return }
    $sd = $Root + '\src-' + $Case; NewDir $sd
    [IO.File]::WriteAllText($LP + $sd + '\' + $Src, $SrcBody, (New-Object Text.ASCIIEncoding))
    if ($Dir) { NewDir $Dir }
    if ($Existing) { [IO.File]::WriteAllText($LP + $Dir + '\' + $Name, $Existing, (New-Object Text.ASCIIEncoding)) }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $sd
        Key $id 0x23   # End: the file (the first item is "..")
        $vw = Open-ByCmd $id 742 15
        if ($vw -eq [IntPtr]::Zero) { Row $Case 'VIEW' 'NOT DRIVEN' 'no viewer window'; return }
        Start-Sleep -Milliseconds 1000
        Out ('           viewer ' + (WinDesc $vw))
        $full = $null; if ($Dir) { $full = $Dir + '\' + $Name }
        $r = Drive-Save $id $vw 6067 $full
        $after = Serve $id 20 @(1, 6)
        if ($Case -eq 'VW-INIT') {
            Row $Case 'INIT' (V ($r.Init -ceq $Src)) ("source '{0}' -> the dialog suggests '{1}'; {2}" -f (Esc $Src), (Esc $r.Init), $r.Note)
        }
        [void][Drv098f]::PostMessageW($vw, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 800
        End-Row $Case $id $null $before; $id = 0
        if ($Dir) { Check-Folder $Case $Dir $Name $IsSrc $r $after }
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

function Run-Open([string]$Case, [string]$Dir, [string]$Name) {
    if (-not (Want $Case)) { return }
    $sd = $Root + '\src-' + $Case; NewDir $sd
    [IO.File]::WriteAllText($LP + $sd + '\a.dat', $SrcBody, (New-Object Text.ASCIIEncoding))
    NewDir $Dir
    [IO.File]::WriteAllText($LP + $Dir + '\' + $Name, 'the file to open', (New-Object Text.ASCIIEncoding))
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $sd
        Key $id 0x23
        $vw = Open-ByCmd $id 742 15
        if ($vw -eq [IntPtr]::Zero) { Row $Case 'VIEW' 'NOT DRIVEN' 'no viewer window'; return }
        Start-Sleep -Milliseconds 1000
        $r = Drive-Save $id $vw 6050 ($Dir + '\' + $Name)
        $after = Serve $id 20 @(1, 6)
        Start-Sleep -Milliseconds 800
        $title = [Drv098f]::Txt($vw)
        $ok = $title.StartsWith($Dir + '\' + $Name)
        Row $Case 'TITLE' (V $ok) ("opened '{0}' -> viewer title '{1}'; {2}windows after: {3}" -f (Esc $Name), (Esc $title), $(if ($r.Note) { $r.Note + '; ' } else { '' }), (Msgs $after))
        [void][Drv098f]::PostMessageW($vw, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 800
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc172_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
# the export creates the program's folder under the roaming application data (its start folder)
$AppDir = Join-Path $env:APPDATA 'Tandem Commander'
$AppDirExisted = Test-Path -LiteralPath $AppDir
$AppDirBefore = @(); if ($AppDirExisted) { $AppDirBefore = @(Get-ChildItem -LiteralPath $AppDir -Force | ForEach-Object { $_.Name }) }
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("save_dialogs_probe (feature 172), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    Run-Export 'EX-ASCII' ($Root + '\ex-ascii') 'cfg-ascii.reg'
    Run-Export 'EX-CZ' ($Root + '\ex-cz') ($CzName + '.reg')
    Run-Export 'EX-CYR' ($Root + '\ex-cyr') ($CyrName + '.reg')
    Run-Export 'EX-CYRDIR' ($Root + '\' + $CyrDir + '-ex') 'cfg.reg'
    Run-Viewer 'VW-ASCII' 'a.dat' ($Root + '\vw-ascii') 'copy-ascii.txt'
    Run-Viewer 'VW-CZ' 'a.dat' ($Root + '\vw-cz') ($CzName + '.txt')
    Run-Viewer 'VW-CYR' 'a.dat' ($Root + '\vw-cyr') ($CyrName + '.txt')
    Run-Viewer 'VW-CYRDIR' 'a.dat' ($Root + '\' + $CyrDir + '-vw') 'copy.txt'
    # an existing target: the "already exists" question answered Yes - replaced through a temporary file
    Run-Viewer 'VW-OVER' 'a.dat' ($Root + '\vw-over') ($CzName + '.txt') 'the old content'
    # a name of more than MAX_PATH bytes in UTF-8 (fewer than MAX_PATH characters)
    Run-Viewer 'VW-LONG' 'a.dat' ($Root + '\vw-long') ((C @(0x17E)) * 140 + '.txt')
    Run-Viewer 'VW-INIT' ($CzSrc + '.dat') $null $null
    Run-Open 'VW-OPEN-CZ' ($Root + '\vw-open') ($CzName + '.dat')
    Run-Open 'VW-OPEN-CYRDIR' ($Root + '\' + $CyrDir + '-open') 'b.dat'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $AppDirNow = @(); if (Test-Path -LiteralPath $AppDir) { $AppDirNow = @(Get-ChildItem -LiteralPath $AppDir -Force | ForEach-Object { $_.Name }) }
    $newInApp = @($AppDirNow | Where-Object { $AppDirBefore -notcontains $_ })
    if ($newInApp.Count) { Out ('APPDATA: NEW ITEMS in ' + $AppDir + ': ' + ($newInApp -join ', ') + ' - left for a look') }
    elseif (-not $AppDirExisted -and (Test-Path -LiteralPath $AppDir)) { Remove-Item -LiteralPath $AppDir -Force; Out ('APPDATA: the folder the export created removed (it was empty)') }
    else { Out 'APPDATA: unchanged' }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
if ($Expect -eq 'before') { exit 0 }
exit $nf
