<#
.SYNOPSIS
    Feature 204 probe: an archive member whose folder part is only the short (8.3) name of another
    folder in the target ("LONGDI~1/a.txt" next to "longdirname") is unpacked into a folder of its
    own - never into the other folder - while a target the user typed with a short name still
    resolves through it.

.DESCRIPTION
    Rows (F5 out of the archive, command 727, the target folder typed; boxes answered Yes / OK):
      zip-dir    ZIP, member LONGDI~1/a.txt (no folder entry): PASS = a folder LONGDI~1 holding
                 a.txt, longdirname holds only keep.txt
      zip-entry  ZIP, entries "LONGDI~1/" and "LONGDI~1/a.txt" (the folder made by its entry)
      zip-deep   ZIP, member LONGDI~1/sub/a.txt
      zip-same   ZIP, member LONGDI~1/keep.txt - the other folder's file never offered for
                 overwriting, its content kept
      tar-dir    TAR (tar.exe), member LONGDI~1/a.txt
      zip-held   ZIP, member LONGDI~1/a.txt, keep.txt inside longdirname held open (the folder cannot
                 be moved aside): PASS = an error, nothing unpacked into longdirname
      7z-dir     7-Zip plug-in (an archive made by Windows' tar.exe), member LONGDI~1/a.txt (its
                 folders made on the plug-in's own thread)
      7z-held    the same with keep.txt held open: an error, nothing unpacked into longdirname
      f9-zip     Alt+F9 (Unpack, 851) of the ZIP, target typed: UnpackWholeArchive
      root       F5 out of the ZIP to the root of a SUBST drive mapped to the target folder
      typed      the control: ZIP member x.txt, the target typed as "tgt\LONGDI~1\" - the user's own
                 short name keeps resolving: x.txt lands in longdirname
    Short names must be made on the volume (dir /x; NOT DRIVEN otherwise). Driver of 158's probe.
    MUST run through tools\\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
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
$Root = $TempRoot + '\tc204_ud'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$DavBack = $Root + '\dav'
$DavLog = $Root + '\davnorm.log'
$DavA = '\\localhost@' + $Port + '\dav'
$DavB = '\\127.0.0.1@' + $Port + '\dav'
$Nfd = 'cafe' + [char]0x0301 + '.txt'     # how a macOS server stores the name
$Nfc = 'Caf' + [char]0xE9 + '.txt'        # what the user types: another spelling (and case)
$ConfKey = 'HKCU:\Software\Tandem Commander\Settings\Configuration\Confirmation'
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

function CS-Dir([string]$Case) {
    $d = New-Case $Case; NewDir "$d\cs"
    $r = Cmd ("fsutil file setCaseSensitiveInfo `"{0}`" enable" -f "$d\cs")
    if ($r.Rc -ne 0) { return @($d, ('case sensitivity refused: ' + $r.Text)) }
    return @($d, '')
}
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
function Zip-Make([string]$Zip, [string[]]$Names, [string]$Content) {
    $z = [IO.Compression.ZipFile]::Open($LP + $Zip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($n in $Names) {
            $e = $z.CreateEntry($n)
            if (-not $n.EndsWith('/')) { $w = New-Object IO.StreamWriter($e.Open()); $w.Write($Content); $w.Dispose() }
        }
    }
    finally { $z.Dispose() }
}
function UD-Dir([string]$Case) {
    $d = New-Case $Case
    NewDir "$d\tgt"; NewDir "$d\tgt\longdirname"; Put "$d\tgt\longdirname\keep.txt" 'PRECIOUS-D'
    $r = Cmd ("dir /x `"{0}`"" -f "$d\tgt")
    if ($r.Text -notmatch 'LONGDI~1') { return @($d, ('no short name on this volume: ' + $r.Text)) }
    return @($d, '')
}
# PASS: longdirname holds only keep.txt (content kept) and a folder LONGDI~1 of its own holds $Rel
function UD-Check([string]$d, [string]$Rel) {
    $inside = @(Get-ChildItem -LiteralPath ($LP + "$d\tgt\longdirname") -Force | ForEach-Object { $_.Name }) -join ','
    $keep = [IO.File]::ReadAllText($LP + "$d\tgt\longdirname\keep.txt")
    $own = @(Get-ChildItem -LiteralPath ($LP + "$d\tgt") -Directory | ForEach-Object { $_.Name }) -ccontains 'LONGDI~1'
    $there = $own -and [IO.File]::Exists($LP + "$d\tgt\LONGDI~1\$Rel")
    $x = Snap "$d\tgt"
    $kept = ($inside -ceq 'keep.txt') -and ($keep -ceq 'PRECIOUS-D')
    return (Res ($kept -and $there) (-not $kept) ($x + '; longdirname holds: ' + $inside + '; keep.txt: ' + $keep + '; own LONGDI~1 with ' + $Rel + ': ' + $there))
}
function UD-Case([string]$Case, [string[]]$Names, [string]$Rel, [string]$Asked) {
    $x = UD-Dir $Case; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    Zip-Make "$d\a.zip" $Names ('COPIED-' + $Case)
    @{ Asked = $Asked; NotAsked = 'Overwrite'; Dir = $d; Left = "$d\a.zip"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = "$d\tgt\"; Rel = $Rel
       Check = { UD-Check $d $c.Rel } }
}
$Cases['zip-dir'] = { UD-Case 'zip-dir' @('LONGDI~1/a.txt') 'a.txt' '^nothing$' }
$Cases['zip-entry'] = { UD-Case 'zip-entry' @('LONGDI~1/', 'LONGDI~1/a.txt') 'a.txt' '^nothing$' }
$Cases['zip-deep'] = { UD-Case 'zip-deep' @('LONGDI~1/sub/a.txt') 'sub\a.txt' '^nothing$' }
$Cases['zip-same'] = { UD-Case 'zip-same' @('LONGDI~1/keep.txt') 'keep.txt' '^nothing$' }
$Cases['zip-held'] = {
    $x = UD-Dir 'zip-held'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    Zip-Make "$d\a.zip" @('LONGDI~1/a.txt') 'COPIED-zip-held'
    $global:Held204 = [IO.File]::Open($LP + "$d\tgt\longdirname\keep.txt", [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    @{ Asked = '.'; NotAsked = 'Overwrite'; Dir = $d; Left = "$d\a.zip"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = "$d\tgt\"
       Check = {
           if ($global:Held204) { $global:Held204.Dispose(); $global:Held204 = $null }
           $inside = @(Get-ChildItem -LiteralPath ($LP + "$d\tgt\longdirname") -Force | ForEach-Object { $_.Name }) -join ','
           $keep = [IO.File]::ReadAllText($LP + "$d\tgt\longdirname\keep.txt")
           $x = Snap "$d\tgt"; $ok = ($inside -ceq 'keep.txt') -and ($keep -ceq 'PRECIOUS-D')
           Res $ok (-not $ok) ($x + '; longdirname holds: ' + $inside) } }
}
function SevenZ([string]$d) {
    NewDir "$d\s"; NewDir "$d\s\LONGDI~1"; Put "$d\s\LONGDI~1\a.txt" 'COPIED-7z'
    $r = Cmd ("cd /d `"{0}`" && %SystemRoot%\System32\tar.exe --format 7zip -cf a.7z -C s LONGDI~1" -f $d)
    if (-not [IO.File]::Exists($LP + "$d\a.7z")) { return ('tar.exe made no archive: ' + $r.Text) }
    return ''
}
$Cases['7z-dir'] = {
    $x = UD-Dir '7z-dir'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    $e = SevenZ $d; if ($e) { return @{ Skip = $e } }
    @{ Asked = '^nothing$'; NotAsked = 'Overwrite'; Dir = $d; Left = "$d\a.7z"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = "$d\tgt\"
       Check = { UD-Check $d 'a.txt' } }
}
$Cases['7z-held'] = {
    $x = UD-Dir '7z-held'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    $e = SevenZ $d; if ($e) { return @{ Skip = $e } }
    $global:Held204 = [IO.File]::Open($LP + "$d\tgt\longdirname\keep.txt", [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    @{ Asked = '.'; NotAsked = 'Overwrite'; Dir = $d; Left = "$d\a.7z"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = "$d\tgt\"
       Check = {
           if ($global:Held204) { $global:Held204.Dispose(); $global:Held204 = $null }
           $inside = @(Get-ChildItem -LiteralPath ($LP + "$d\tgt\longdirname") -Force | ForEach-Object { $_.Name }) -join ','
           $keep = [IO.File]::ReadAllText($LP + "$d\tgt\longdirname\keep.txt")
           $x = Snap "$d\tgt"; $ok = ($inside -ceq 'keep.txt') -and ($keep -ceq 'PRECIOUS-D')
           Res $ok (-not $ok) ($x + '; longdirname holds: ' + $inside) } }
}
$Cases['f9-zip'] = {
    $x = UD-Dir 'f9-zip'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    NewDir "$d\src"; Zip-Make "$d\src\a.zip" @('LONGDI~1/a.txt') 'COPIED-f9-zip'
    @{ Asked = '^nothing$'; NotAsked = 'Overwrite'; Dir = $d; Left = "$d\src"; Right = "$d\tgt"; FocusLast = $true; Cmd = 851; Text = "$d\tgt\"
       Check = { UD-Check $d 'a.txt' } }
}
$Cases['root'] = {
    $x = UD-Dir 'root'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    Zip-Make "$d\a.zip" @('LONGDI~1/a.txt') 'COPIED-root'
    $used = @([IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpper() })
    $letter = @('Y', 'X', 'W', 'V', 'U', 'T') | Where-Object { $used -notcontains $_ } | Select-Object -First 1
    if (-not $letter) { return @{ Skip = 'no free drive letter' } }
    $r = Cmd ("subst {0}: `"{1}`"" -f $letter, "$d\tgt")
    if (-not [IO.Directory]::Exists($letter + ':\longdirname')) { return @{ Skip = ('subst failed: ' + $r.Text) } }
    $script:Subst = $letter + ':'
    @{ Asked = '^nothing$'; NotAsked = 'Overwrite'; Dir = $d; Left = "$d\a.zip"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = ($letter + ':\')
       Check = { $r = UD-Check $d 'a.txt'; [void](Cmd ("subst {0} /d" -f $script:Subst)); $script:Subst = $null; $r } }
}
$Cases['tar-dir'] = {
    $x = UD-Dir 'tar-dir'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    NewDir "$d\s"; NewDir "$d\s\LONGDI~1"; Put "$d\s\LONGDI~1\a.txt" 'COPIED-tar-dir'
    $r = Cmd ("cd /d `"{0}`" && %SystemRoot%\System32\tar.exe -cf a.tar -C s LONGDI~1" -f $d)   # relative: bsdtar takes "C:..." for a remote host
    if (-not [IO.File]::Exists($LP + "$d\a.tar")) { return @{ Skip = ('tar.exe made no archive: ' + $r.Text) } }
    @{ Asked = '^nothing$'; NotAsked = 'Overwrite'; Dir = $d; Left = "$d\a.tar"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = "$d\tgt\"
       Check = { UD-Check $d 'a.txt' } }
}
$Cases['typed'] = {
    $x = UD-Dir 'typed'; $d = $x[0]; if ($x[1]) { return @{ Skip = $x[1] } }
    Zip-Make "$d\a.zip" @('x.txt') 'COPIED-typed'
    @{ Asked = '^nothing$'; Dir = $d; Left = "$d\a.zip"; Right = "$d\tgt"; FocusLast = $true; Cmd = 727; Text = "$d\tgt\LONGDI~1\"
       Check = { $inside = @(Get-ChildItem -LiteralPath ($LP + "$d\tgt\longdirname") -Force | ForEach-Object { $_.Name } | Sort-Object) -join ','; $x = Snap "$d\tgt"; Res ($inside -ceq 'keep.txt,x.txt') $false ($x + '; longdirname holds: ' + $inside) } }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc204_ud_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir; NewDir $DavBack
    Set-Config
    Set-Overwrite 1
    Out ("unpack_dir_probe (feature 204) {0}" -f $Label)
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

