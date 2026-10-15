<#
.SYNOPSIS
    Feature 195 probe: F5 Copy within a case-sensitive folder - "a.txt" copied as "A.txt" is a
    copy to another name (it was refused "Cannot copy a file to itself." by the name's case-
    insensitive rule); the same file under another case (a hard link) stays refused.

.DESCRIPTION
    Rows (Copy, command 727, the target typed in the field; windows answered by the row):
      cs-new    case-sensitive folder (fsutil setCaseSensitiveInfo), only a.txt: copied as A.txt -
                both files, the same content, no question
      cs-other  a.txt and A.txt two files: the overwrite question, answered Yes - A.txt holds
                a.txt's content, a.txt kept
      cs-hl     A.txt a hard link of a.txt (one file): refused "to itself" (both builds)
      cs-dir    a folder d (with a file) copied as D in the case-sensitive folder - both folders
      cs-junc   D a junction to d: copying d as D is refused at the folder ("to itself")
      ci-case   an ordinary (case-insensitive) folder, a.txt copied as A.txt: refused "to
                itself" (control, both builds)
    Driver, fixtures and helpers from specs/158-*/probe/cs_overwrite_probe.ps1 (WebDAV unused).
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [int]$Port = 18103,
    [switch]$Expect103   # also require the windows this feature shows (off for the build before it)
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc195_cs'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$DavBack = $Root + '\dav'
$DavLog = $Root + '\davnorm.log'
$DavA = '\\localhost@' + $Port + '\dav'
$DavB = '\\127.0.0.1@' + $Port + '\dav'
$Nfd = 'cafe' + [char]0x0301 + '.txt'     # how a macOS server stores the name
$Nfc = 'Caf' + [char]0xE9 + '.txt'        # what the user types: another spelling (and case)
$ConfKey = 'HKCU:\Software\Tandem Commander\0.1\Configuration\Confirmation'
$script:Links = New-Object System.Collections.ArrayList
$script:Subst = $null
$script:Dav = $null

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
function Put([string]$p, [string]$text) { [IO.File]::WriteAllText($LP + $p, $text, (New-Object Text.ASCIIEncoding)) }
# "name=content; ..." of a folder (names escaped), the file contents read on disk
function Snap([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return '(gone)' }
    $n = @()
    foreach ($e in [IO.Directory]::GetFileSystemEntries($LP + $Dir)) {
        $name = [IO.Path]::GetFileName($e)
        if ([IO.File]::Exists($e)) { $n += ((Esc $name) + '=' + [IO.File]::ReadAllText($e)) } else { $n += ((Esc $name) + '/') }
    }
    return (($n | Sort-Object) -join '; ')
}
function Holders([string]$Dir, [string]$Text) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetFiles($LP + $Dir) | Where-Object { [IO.File]::ReadAllText($_) -ceq $Text } | ForEach-Object { [IO.Path]::GetFileName($_) })
}
function Read-Shared([string]$p) {   # the server keeps its log open for writing
    if (-not [IO.File]::Exists($p)) { return @() }
    $fs = New-Object IO.FileStream($p, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $sr = New-Object IO.StreamReader($fs); return @(($sr.ReadToEnd() -split "`r?`n") | Where-Object { $_ -ne '' }) } finally { $fs.Dispose() }
}
function Dav-Lines([int]$From) {
    $all = @(Read-Shared $DavLog)
    if ($all.Count -le $From) { return @() }
    return @($all[$From..($all.Count - 1)] | Where-Object { $_ -match ' (MOVE|DELETE|PUT|COPY) ' })
}
function Dav-Count { return @(Read-Shared $DavLog).Count }
function Set-Overwrite([int]$v) {
    if (-not (Test-Path $ConfKey)) { [void](New-Item -Path $ConfKey -Force) }
    Set-ItemProperty -Path $ConfKey -Name 'File Overwrite' -Value $v -Type DWord
}

# serves the instance until idle: records every window; Yes / OK; Skip on an error dialog;
# Cancel on a Quick Rename dialog that comes back (the program re-opens it after a failure)
function Serve103([int]$Id, [double]$Seconds = 60, $Ignore = @()) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and $Ignore -notcontains $_ })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) { continue }   # progress
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            if (@('Quick Rename', 'Rename File') -contains [Drv098f]::Txt($h)) { [void]$r.Messages.Add([Drv098f]::Txt($h) + ' dialog re-opened (cancelled)'); Close-Win $h; Start-Sleep -Milliseconds 400; continue }
            [void]$r.Messages.Add($d)
            $pick = $null
            foreach ($want in $script:Answers) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } }
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function Short([string]$s) {
    $s = $s -replace '\[Button id=\d+\] [^|]*(\||$)', ''
    $s = $s -replace '\[Static id=-?\d+\] ', ''
    if ($s.Length -gt 230) { $s = $s.Substring(0, 230) + '...' }
    return $s.Trim()
}

# one case: $Setup returns @{ Left; Right; Focus; Cmd; Text; Check } (Check: scriptblock -> @{ Ok; Lost; Facts })
function Run-Case([string]$Case, [scriptblock]$Setup) {
    $script:Answers = @(6, 1, 173)
    $before = Reports; $id = 0; $fatal = $null
    try {
        $c = & $Setup
        if ($c.Answers) { $script:Answers = $c.Answers }
        if ($c.Skip) { Row $Case 'RUN' 'NOT DRIVEN' $c.Skip; return }
        $davFrom = Dav-Count
        Set-Overwrite $(if ($c.Silent) { 0 } else { 1 })   # the program writes its configuration back at exit
        $script:StartDirSave = $StartDir
        $StartDir = $c.Right
        $id = Start-Tc $c.Left
        $StartDir = $script:StartDirSave
        if ($c.FocusLast) {   # a folder: Change Directory would enter it - focus the last item instead
            $held = Do-ChangeDir $id $c.Left
            Key $id 0x24; Key $id 0x23
        }
        else { $held = Do-ChangeDir $id $c.Focus }
        Start-Sleep -Milliseconds 500
        $viewer = [IntPtr]::Zero
        if ($c.Viewer) {   # PictView: F3 opens the image, CMD_IMG_RENAME (185) its Rename File dialog
            $viewer = Open-ByCmd $id 742 20
            if ($viewer -eq [IntPtr]::Zero -or [Drv098f]::Cls($viewer) -eq '#32770') { throw 'PictView did not open the image' }
            Start-Sleep -Milliseconds 1500
            $known = Get-Tops $id
            Post-Cmd $viewer 185
            $dlg = Wait-NewWin $id $known 10
            if ($dlg -eq [IntPtr]::Zero) { throw 'PictView opened no Rename File dialog' }
            $fld = Find-Ctl $dlg 2172
        }
        else {
            $dlg = Open-ByCmd $id $c.Cmd 15
            if ($dlg -eq [IntPtr]::Zero) { throw ('command ' + $c.Cmd + ' opened no window') }
            $fld = Find-Ctl $dlg 210
        }
        if ($fld -eq [IntPtr]::Zero) { throw 'the name field was not found' }
        $was = [Drv098f]::GetText($fld, 5000)
        if ($c.TextFor) { $c.Text = & $c.TextFor (FullText $dlg) $c.Dir }
        # never a target outside the fixture (an answered "create it?" would make it)
        if (-not ([string]$c.Text).StartsWith($Root + '\')) { throw ('the target is outside the fixture: ' + $c.Text) }
        [void][Drv098f]::SetText($fld, $c.Text, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve103 $id 90 @($viewer)
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        if ($viewer -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($viewer)) {
            [void][Drv098f]::PostMessageW($viewer, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($viewer)) { Start-Sleep -Milliseconds 100 }
            $r2 = Serve103 $id 15
            foreach ($m in $r2.Messages) { [void]$r.Messages.Add('after closing the viewer: ' + $m) }
        }
        Start-Sleep -Milliseconds 500
        $d = $c.Dir
        $res = & $c.Check
        $msgs = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || ')
        $dav = @(Dav-Lines $davFrom | ForEach-Object { ($_ -replace '^\S+ ', '') })
        $shown = $(if ($msgs) { $msgs } else { 'nothing' })
        $as103 = ($shown -match $c.Asked) -and (-not $c.NotAsked -or $shown -notmatch $c.NotAsked)
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and $res.Ok -and ($as103 -or -not $Expect103)
        $verdict = V $ok
        Row $Case 'RUN' $verdict ("lost={0}; windows as 103 expects: $as103; focus held {1}; field was '{2}', set '{3}'; on disk: {4}; asked: {5}{6}{7}{8}" -f $res.Lost, $held, (Tail $was 40), (Tail $c.Text 40), $res.Facts, $(if ($msgs) { $msgs } else { 'nothing' }), $(if ($dav.Count) { '; server: ' + ($dav -join ' / ') } else { '' }), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally {
        $StartDir = $script:StartDirSave
        if ($id) { End-Row $Case $id $fatal $before }
    }
}

# ---- fixtures and checks -----------------------------------------------------------
function New-Case([string]$Case) { $d = $Root + '\' + $Case; NewDir $d; return $d }
function Dav-Case([string]$Case) { $d = $DavBack + '\' + $Case; NewDir $d; return $d }
function Res([bool]$Ok, [bool]$Lost, [string]$Facts) { return [pscustomobject]@{ Ok = $Ok; Lost = $Lost; Facts = $Facts } }

$Cases = [ordered]@{}
# the same entries in any order (the listing's order is not the point)
function Same([string]$Got, [string]$Want) {
    $g = @($Got -split '; ' | Sort-Object -CaseSensitive) -join '|'
    $w = @($Want -split '; ' | Sort-Object -CaseSensitive) -join '|'
    return $g -ceq $w
}

function CS-Dir([string]$Case) {
    $d = New-Case $Case; NewDir "$d\cs"
    $r = Cmd ("fsutil file setCaseSensitiveInfo `"{0}`" enable" -f "$d\cs")
    if ($r.Rc -ne 0) { return @($d, ('case sensitivity refused: ' + $r.Text)) }
    return @($d, '')
}
$Cases['cs-new'] = {
    $x = CS-Dir 'cs-new'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    Put "$d\cs\a.txt" 'PRECIOUS-1'
    @{ Asked = '^nothing$'; NotAsked = 'to itself'; Dir = $d; Left = "$d\cs"; Right = $StartDir; Focus = "$d\cs\a.txt"; Cmd = 727; Text = "$d\cs\A.txt"
       Check = { $x = Snap "$d\cs"; Res (Same $x 'A.txt=PRECIOUS-1; a.txt=PRECIOUS-1') $false $x } }
}
$Cases['cs-other'] = {
    $x = CS-Dir 'cs-other'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    Put "$d\cs\a.txt" 'PRECIOUS-2'; Put "$d\cs\A.txt" 'other-2'
    @{ Asked = 'Confirm File Overwrite'; NotAsked = 'to itself'; Dir = $d; Left = "$d\cs"; Right = $StartDir; Focus = "$d\cs\a.txt"; Cmd = 727; Text = "$d\cs\A.txt"
       Check = { $x = Snap "$d\cs"; Res (Same $x 'A.txt=PRECIOUS-2; a.txt=PRECIOUS-2') ((Holders "$d\cs" 'PRECIOUS-2').Count -eq 0) $x } }
}
$Cases['cs-hl'] = {
    $x = CS-Dir 'cs-hl'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    Put "$d\cs\a.txt" 'PRECIOUS-3'
    $r = Cmd ("mklink /H `"{0}`" `"{1}`"" -f "$d\cs\A.txt", "$d\cs\a.txt"); if ($r.Rc -ne 0) { return @{ Skip = 'mklink /H refused: ' + $r.Text } }
    @{ Asked = 'to itself'; Dir = $d; Left = "$d\cs"; Right = $StartDir; Focus = "$d\cs\a.txt"; Cmd = 727; Text = "$d\cs\A.txt"
       Check = { $x = Snap "$d\cs"; Res (Same $x 'A.txt=PRECIOUS-3; a.txt=PRECIOUS-3') ((Holders "$d\cs" 'PRECIOUS-3').Count -eq 0) $x } }
}
$Cases['cs-dir'] = {
    $x = CS-Dir 'cs-dir'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    NewDir "$d\cs\d"; Put "$d\cs\d\f.txt" 'PRECIOUS-5'
    @{ Asked = '^nothing$'; NotAsked = 'to itself'; Dir = $d; Left = "$d\cs"; Right = $StartDir; FocusLast = $true; Cmd = 727; Text = "$d\cs\D"
       Check = { $x = Snap "$d\cs"; $y = Snap "$d\cs\D"; Res ((Same $x 'D/; d/') -and $y -ceq 'f.txt=PRECIOUS-5') $false ($x + ' | D: ' + $y) } }
}
$Cases['cs-junc'] = {   # review of 195: D a junction to d - the same folder through a link
    $x = CS-Dir 'cs-junc'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    NewDir "$d\cs\d"; Put "$d\cs\d\f.txt" 'PRECIOUS-6'
    $r = Cmd ("mklink /J `"{0}`" `"{1}`"" -f "$d\cs\D", "$d\cs\d"); if ($r.Rc -ne 0) { return @{ Skip = 'mklink /J refused: ' + $r.Text } }
    [void]$script:Links.Add($LP + "$d\cs\D")
    # the panel's order of d and D is not fixed: the last item is focused, the dialog's text names it,
    # the target is the other spelling
    @{ Asked = 'directory to itself'; Dir = $d; Left = "$d\cs"; Right = $StartDir; FocusLast = $true; Cmd = 727; Text = "$d\cs\D"
       TextFor = { param($dlgText, $dir) if ($dlgText -cmatch "'D'") { "$dir\cs\d" } else { "$dir\cs\D" } }
       Check = { $y = Snap "$d\cs\d"; Res ($y -ceq 'f.txt=PRECIOUS-6') ((Holders "$d\cs\d" 'PRECIOUS-6').Count -eq 0) ('d: ' + $y) } }
}
$Cases['ci-case'] = {
    $d = New-Case 'ci-case'; Put "$d\a.txt" 'PRECIOUS-4'
    @{ Asked = 'to itself'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 727; Text = "$d\A.txt"
       Check = { $x = Snap $d; Res (Same $x 'a.txt=PRECIOUS-4') ((Holders $d 'PRECIOUS-4').Count -eq 0) $x } }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc195_cs_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir; NewDir $DavBack
    Set-Config
    Set-Overwrite 1
    Out ("cs_copy_probe (feature 195) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    # the WebDAV server
    $script:DavOk = $false; $script:DavWhy = 'WebDAV not started'
    if ($true) { $script:DavWhy = 'not used by this probe' }
    else {
        try {
            $script:Dav = Start-Process -FilePath $Python -ArgumentList @(('"{0}"' -f (Join-Path $PSScriptRoot 'davnorm.py')), ('"{0}"' -f $DavBack), $Port, ('"{0}"' -f $DavLog)) -PassThru -WindowStyle Hidden
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.Elapsed.TotalSeconds -lt 20 -and -not $script:DavOk) { Start-Sleep -Milliseconds 500; $script:DavOk = Test-Path -LiteralPath $DavA }
            if (-not $script:DavOk) { $script:DavWhy = "the WebDAV path $DavA did not answer" }
        }
        catch { $script:DavWhy = 'python could not be started: ' + $_.Exception.Message }
    }
    Out ("WebDAV  : {0}" -f $(if ($script:DavOk) { "$DavA and $DavB (normalising server, port $Port)" } else { 'NOT AVAILABLE - ' + $script:DavWhy }))
    Out ''
    foreach ($k in @($Cases.Keys)) { if (Want $k) { Run-Case $k $Cases[$k] } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    if ($script:Subst) { [void](Cmd ("subst {0} /d" -f $script:Subst)) }
    foreach ($l in @($script:Links)) { if ([IO.Directory]::Exists($l)) { [void](Cmd ("rmdir `"{0}`"" -f $l)) } }
    if ($script:Dav -and -not $script:Dav.HasExited) { Stop-Process -Id $script:Dav.Id -Force; Start-Sleep -Milliseconds 500 }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; subst removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), (-not $script:Subst -or -not (Test-Path ($script:Subst + '\'))), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf

