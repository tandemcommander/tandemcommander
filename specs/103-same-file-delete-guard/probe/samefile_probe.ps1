<#
.SYNOPSIS
    Feature 103 probe: renaming, moving or copying a file onto ANOTHER NAME OR PATH OF
    ITSELF must never delete or truncate it; ordinary overwrites must work as before.

.DESCRIPTION
    Fixtures under %TEMP%\tc103_sf (removed at the end). Every case starts the program
    with the left panel on the source folder (and the right panel on the target folder),
    focuses the file through Change Directory, runs the route and answers the windows:
    Yes / OK, Skip on an error dialog, Cancel on a re-opened Quick Rename dialog. Then
    it reads the files ON DISK (for WebDAV: the server's backing folder) and checks that
    the content of the source still exists - "lost" means no file holds it any more.

    Aliases (two names or paths, one file):
      dav-*    a local WebDAV server (davnorm.py, Python standard library) whose name
               lookup folds like a macOS server: "cafe" + U+0301 (NFD, how macOS stores
               it) and "Caf" + U+00E9 (typed by the user) are ONE entry; Windows treats
               them as two names. The redirector reports such a rename as "already
               exists" - the defect's own situation. The same server is also reachable
               as \\localhost@port and \\127.0.0.1@port: one file under two server names
               (dav-x*). WebDAV reports no file ids (index 0): the "ids unknown" path.
      junc-*   a junction alias of the folder (NTFS answers the move itself)
      subst-*  a SUBST drive letter on the folder
      unc-*    the loopback administrative share \\localhost\C$ (same file, file ids known)
      hl-*     hard links (one file, two names, link count 2)
      cs-*     a case-sensitive folder: a.txt and A.txt are DIFFERENT files
      8dot3-*  a file renamed to its own 8.3 short name
    Controls: norm-* (an ordinary overwrite of a different file), case-qren (a plain
    case change), dav-norm / dav-twin (ordinary overwrites on WebDAV; the twins have the
    same size and times, so only the self-check of the temporary-name route tells them
    apart).
    Routes: qren = Quick Rename (754), mov = F6 (728), cpy = F5 (727).

    Expected (this feature): no case loses data; a rename/move onto another spelling of
    itself is performed (via a temporary name); a copy or a cross-name move onto itself
    is refused with "Cannot copy/move a file to itself."; ordinary overwrites still ask
    and overwrite. The build before 103 is the control (dav-qren, dav-mov, dav-msil,
    dav-xmov lose the file).

    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported/restored/verified.
    Pure ASCII. Exit code = number of FAIL rows.
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
$Root = $TempRoot + '\tc103_sf'
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
            foreach ($want in 6, 1, 173) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } }
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
    $before = Reports; $id = 0; $fatal = $null
    try {
        $c = & $Setup
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

# --- WebDAV, another spelling of the same entry (the defect itself) ---
$Cases['dav-qren'] = {
    if (-not $script:DavOk) { return @{ Skip = $script:DavWhy } }
    $b = Dav-Case 'dav-qren'; Put "$b\$Nfd" 'PRECIOUS-1'
    @{ Asked = '^nothing$'; Dir = $d; Left = "$DavA\dav-qren"; Right = $StartDir; Focus = "$DavA\dav-qren\$Nfd"; Cmd = 754; Text = $Nfc
       Check = { $h = @(Holders "$DavBack\dav-qren" 'PRECIOUS-1'); Res ($h.Count -eq 1 -and $h[0] -ceq $Nfc) ($h.Count -eq 0) (Snap "$DavBack\dav-qren") } }
}
$Cases['dav-mov'] = {
    if (-not $script:DavOk) { return @{ Skip = $script:DavWhy } }
    $b = Dav-Case 'dav-mov'; Put "$b\$Nfd" 'PRECIOUS-2'
    @{ Asked = '^nothing$'; Dir = $d; Left = "$DavA\dav-mov"; Right = $StartDir; Focus = "$DavA\dav-mov\$Nfd"; Cmd = 728; Text = "$DavA\dav-mov\$Nfc"
       Check = { $h = @(Holders "$DavBack\dav-mov" 'PRECIOUS-2'); Res ($h.Count -eq 1 -and $h[0] -ceq $Nfc) ($h.Count -eq 0) (Snap "$DavBack\dav-mov") } }
}
$Cases['dav-msil'] = {   # the same with "Confirm file overwrite" off: no question at all
    if (-not $script:DavOk) { return @{ Skip = $script:DavWhy } }
    $b = Dav-Case 'dav-msil'; Put "$b\$Nfd" 'PRECIOUS-3'
    @{ Asked = '^nothing$'; Silent = $true; Dir = $d; Left = "$DavA\dav-msil"; Right = $StartDir; Focus = "$DavA\dav-msil\$Nfd"; Cmd = 728; Text = "$DavA\dav-msil\$Nfc"
       Check = { $h = @(Holders "$DavBack\dav-msil" 'PRECIOUS-3'); Res ($h.Count -eq 1 -and $h[0] -ceq $Nfc) ($h.Count -eq 0) (Snap "$DavBack\dav-msil") } }
}
# --- WebDAV, one file under two server names ---
$Cases['dav-xmov'] = {
    if (-not $script:DavOk) { return @{ Skip = $script:DavWhy } }
    $b = Dav-Case 'dav-xmov'; Put "$b\x.txt" 'PRECIOUS-4'
    @{ Asked = 'Cannot move a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = "$DavA\dav-xmov"; Right = "$DavB\dav-xmov"; Focus = "$DavA\dav-xmov\x.txt"; Cmd = 728; Text = "$DavB\dav-xmov\"
       Check = { $h = @(Holders "$DavBack\dav-xmov" 'PRECIOUS-4'); Res ($h.Count -eq 1) ($h.Count -eq 0) (Snap "$DavBack\dav-xmov") } }
}
$Cases['dav-xcpy'] = {
    if (-not $script:DavOk) { return @{ Skip = $script:DavWhy } }
    $b = Dav-Case 'dav-xcpy'; Put "$b\x.txt" 'PRECIOUS-5'
    @{ Asked = 'Cannot copy a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = "$DavA\dav-xcpy"; Right = "$DavB\dav-xcpy"; Focus = "$DavA\dav-xcpy\x.txt"; Cmd = 727; Text = "$DavB\dav-xcpy\"
       Check = { $h = @(Holders "$DavBack\dav-xcpy" 'PRECIOUS-5'); Res ($h.Count -eq 1) ($h.Count -eq 0) (Snap "$DavBack\dav-xcpy") } }
}
# --- WebDAV controls: ordinary overwrites of a different file ---
$Cases['dav-norm'] = {
    if (-not $script:DavOk) { return @{ Skip = $script:DavWhy } }
    $b = Dav-Case 'dav-norm'; Put "$b\a.txt" 'PRECIOUS-6'; Put "$b\b.txt" 'other content, longer'
    @{ Asked = 'Confirm File Overwrite'; NotAsked = 'itself'; Dir = $d; Left = "$DavA\dav-norm"; Right = $StartDir; Focus = "$DavA\dav-norm\a.txt"; Cmd = 728; Text = "$DavA\dav-norm\b.txt"
       Check = { $s = Snap "$DavBack\dav-norm"; Res ($s -ceq 'b.txt=PRECIOUS-6') ((Holders "$DavBack\dav-norm" 'PRECIOUS-6').Count -eq 0) $s } }
}
function Twins([string]$b, [string]$ta, [string]$tb) {
    Put "$b\a.txt" $ta; Put "$b\b.txt" $tb
    $t = [datetime]'2026-01-02 03:04:05'
    foreach ($f in "$b\a.txt", "$b\b.txt") { [IO.File]::SetCreationTime($f, $t); [IO.File]::SetLastWriteTime($f, $t) }
}
$Cases['dav-twin'] = {   # different files, same size and times: the move's self-check must tell them apart
    if (-not $script:DavOk) { return @{ Skip = $script:DavWhy } }
    $b = Dav-Case 'dav-twin'; Twins $b 'PRECIOUS-7' 'twin-ofs-7'
    @{ Asked = 'Confirm File Overwrite'; NotAsked = 'itself'; Dir = $d; Left = "$DavA\dav-twin"; Right = $StartDir; Focus = "$DavA\dav-twin\a.txt"; Cmd = 728; Text = "$DavA\dav-twin\b.txt"
       Check = { $s = Snap "$DavBack\dav-twin"; Res ($s -ceq 'b.txt=PRECIOUS-7') ((Holders "$DavBack\dav-twin" 'PRECIOUS-7').Count -eq 0) $s } }
}
$Cases['dav-twcp'] = {   # the same twins copied: refused by this feature (documented limit), nothing lost
    if (-not $script:DavOk) { return @{ Skip = $script:DavWhy } }
    $b = Dav-Case 'dav-twcp'; Twins $b 'PRECIOUS-8' 'twin-ofs-8'
    @{ Asked = 'Cannot copy a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = "$DavA\dav-twcp"; Right = $StartDir; Focus = "$DavA\dav-twcp\a.txt"; Cmd = 727; Text = "$DavA\dav-twcp\b.txt"
       Check = { $s = Snap "$DavBack\dav-twcp"; Res ((Holders "$DavBack\dav-twcp" 'PRECIOUS-8').Count -ge 1) ((Holders "$DavBack\dav-twcp" 'PRECIOUS-8').Count -eq 0) $s } }
}

# --- PictView's rename of the viewed image: NOT DRIVEN. Measured on both builds: the viewer keeps
# the shown image open, so its Rename fails with error 32 (sharing violation) before any "already
# exists" - on NTFS and on WebDAV alike (pre-existing, recorded in the fix-log). The Viewer route
# of Run-Case (F3, CMD_IMG_RENAME 185, field 2172) is kept for when that is fixed.

# --- NTFS aliases ---
$Cases['junc-mov'] = {
    $d = New-Case 'junc-mov'; NewDir "$d\dir"; Put "$d\dir\a.txt" 'PRECIOUS-9'
    $r = Cmd ("mklink /J `"{0}`" `"{1}`"" -f "$d\junc", "$d\dir"); if ($r.Rc -ne 0) { return @{ Skip = 'mklink /J refused: ' + $r.Text } }; [void]$script:Links.Add("$d\junc")
    @{ Asked = '^nothing$'; Dir = $d; Left = "$d\dir"; Right = "$d\junc"; Focus = "$d\dir\a.txt"; Cmd = 728; Text = "$d\junc\"
       Check = { $s = Snap "$d\dir"; Res ($s -ceq 'a.txt=PRECIOUS-9') ((Holders "$d\dir" 'PRECIOUS-9').Count -eq 0) $s } }
}
$Cases['junc-cpy'] = {
    $d = New-Case 'junc-cpy'; NewDir "$d\dir"; Put "$d\dir\a.txt" 'PRECIOUS-10'
    $r = Cmd ("mklink /J `"{0}`" `"{1}`"" -f "$d\junc", "$d\dir"); if ($r.Rc -ne 0) { return @{ Skip = 'mklink /J refused: ' + $r.Text } }; [void]$script:Links.Add("$d\junc")
    @{ Asked = 'Cannot copy a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = "$d\dir"; Right = "$d\junc"; Focus = "$d\dir\a.txt"; Cmd = 727; Text = "$d\junc\"
       Check = { $s = Snap "$d\dir"; Res ($s -ceq 'a.txt=PRECIOUS-10') ((Holders "$d\dir" 'PRECIOUS-10').Count -eq 0) $s } }
}
function Subst-On([string]$dir) {
    if ($script:Subst) { [void](Cmd ("subst {0} /d" -f $script:Subst)); $script:Subst = $null }
    $used = @([IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpper() })
    $letter = $null; foreach ($l in 'T', 'U', 'V', 'W', 'Q', 'R', 'S') { if ($used -notcontains $l -and -not $letter) { $letter = $l } }
    if (-not $letter) { return $null }
    $r = Cmd ("subst {0}: `"{1}`"" -f $letter, $dir); if ($r.Rc -ne 0) { return $null }
    $script:Subst = $letter + ':'; return $script:Subst
}
$Cases['subst-mov'] = {
    $d = New-Case 'subst-mov'; Put "$d\a.txt" 'PRECIOUS-11'
    $s = Subst-On $d; if (-not $s) { return @{ Skip = 'no free drive letter / subst refused' } }
    @{ Asked = 'Cannot move a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = $d; Right = "$s\"; Focus = "$d\a.txt"; Cmd = 728; Text = "$s\"
       Check = { $x = Snap $d; Res ($x -ceq 'a.txt=PRECIOUS-11') ((Holders $d 'PRECIOUS-11').Count -eq 0) $x } }
}
$Cases['subst-cpy'] = {
    $d = New-Case 'subst-cpy'; Put "$d\a.txt" 'PRECIOUS-12'
    $s = Subst-On $d; if (-not $s) { return @{ Skip = 'no free drive letter / subst refused' } }
    @{ Asked = 'Cannot copy a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = $d; Right = "$s\"; Focus = "$d\a.txt"; Cmd = 727; Text = "$s\"
       Check = { $x = Snap $d; Res ($x -ceq 'a.txt=PRECIOUS-12') ((Holders $d 'PRECIOUS-12').Count -eq 0) $x } }
}
$Cases['unc-mov'] = {
    $d = New-Case 'unc-mov'; Put "$d\a.txt" 'PRECIOUS-13'
    $u = '\\localhost\' + $d.Substring(0, 1) + '$' + $d.Substring(2)
    if (-not (Test-Path -LiteralPath "$u\a.txt")) { return @{ Skip = 'the administrative share is not reachable: ' + $u } }
    @{ Asked = 'Cannot move a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = $d; Right = $u; Focus = "$d\a.txt"; Cmd = 728; Text = "$u\"
       Check = { $x = Snap $d; Res ($x -ceq 'a.txt=PRECIOUS-13') ((Holders $d 'PRECIOUS-13').Count -eq 0) $x } }
}
$Cases['unc-cpy'] = {
    $d = New-Case 'unc-cpy'; Put "$d\a.txt" 'PRECIOUS-14'
    $u = '\\localhost\' + $d.Substring(0, 1) + '$' + $d.Substring(2)
    if (-not (Test-Path -LiteralPath "$u\a.txt")) { return @{ Skip = 'the administrative share is not reachable: ' + $u } }
    @{ Asked = 'Cannot copy a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = $d; Right = $u; Focus = "$d\a.txt"; Cmd = 727; Text = "$u\"
       Check = { $x = Snap $d; Res ($x -ceq 'a.txt=PRECIOUS-14') ((Holders $d 'PRECIOUS-14').Count -eq 0) $x } }
}
function Hard-Link([string]$d) {
    Put "$d\a.txt" 'PRECIOUS-HL'
    $r = Cmd ("mklink /H `"{0}`" `"{1}`"" -f "$d\b.txt", "$d\a.txt"); return ($r.Rc -eq 0)
}
$Cases['hl-qren'] = {   # NTFS renames a link onto another link of the same file by itself
    $d = New-Case 'hl-qren'; if (-not (Hard-Link $d)) { return @{ Skip = 'mklink /H refused' } }
    @{ Asked = '^nothing$'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 754; Text = 'b.txt'
       Check = { $x = Snap $d; Res ((Holders $d 'PRECIOUS-HL').Count -ge 1) ((Holders $d 'PRECIOUS-HL').Count -eq 0) $x } }
}
$Cases['hl-mov'] = {
    $d = New-Case 'hl-mov'; if (-not (Hard-Link $d)) { return @{ Skip = 'mklink /H refused' } }
    @{ Asked = '^nothing$'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 728; Text = "$d\b.txt"
       Check = { $x = Snap $d; Res ((Holders $d 'PRECIOUS-HL').Count -ge 1) ((Holders $d 'PRECIOUS-HL').Count -eq 0) $x } }
}
$Cases['hl-cpy'] = {
    $d = New-Case 'hl-cpy'; if (-not (Hard-Link $d)) { return @{ Skip = 'mklink /H refused' } }
    @{ Asked = 'Confirm File Overwrite'; NotAsked = 'itself'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 727; Text = "$d\b.txt"
       Check = { $x = Snap $d; Res ($x -ceq 'a.txt=PRECIOUS-HL; b.txt=PRECIOUS-HL') ((Holders $d 'PRECIOUS-HL').Count -eq 0) $x } }
}
$Cases['cs-qren'] = {   # a.txt and A.txt are two files here: refused as before, nothing deleted
    $d = New-Case 'cs-qren'; NewDir "$d\cs"
    $r = Cmd ("fsutil file setCaseSensitiveInfo `"{0}`" enable" -f "$d\cs"); if ($r.Rc -ne 0) { return @{ Skip = 'case sensitivity refused: ' + $r.Text } }
    Put "$d\cs\a.txt" 'PRECIOUS-15'; Put "$d\cs\A.txt" 'other-15'
    @{ Asked = '\(183\)'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = "$d\cs"; Right = $StartDir; Focus = "$d\cs\a.txt"; Cmd = 754; Text = 'A.txt'
       Check = { $x = Snap "$d\cs"; Res ($x -ceq 'a.txt=PRECIOUS-15; A.txt=other-15' -or $x -ceq 'A.txt=other-15; a.txt=PRECIOUS-15') ((Holders "$d\cs" 'PRECIOUS-15').Count -eq 0) $x } }
}
$Cases['8dot3-qren'] = {
    $d = New-Case '8dot3-qren'; Put "$d\longfilename.txt" 'PRECIOUS-16'
    $short = ''; try { $fso = New-Object -ComObject Scripting.FileSystemObject; $short = $fso.GetFile("$d\longfilename.txt").ShortName } catch { }
    if (-not $short -or $short -eq 'longfilename.txt') { return @{ Skip = 'no 8.3 names on this volume' } }
    @{ Asked = '^nothing$'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\longfilename.txt"; Cmd = 754; Text = $short
       Check = { $x = Snap $d; Res ((Holders $d 'PRECIOUS-16').Count -eq 1) ((Holders $d 'PRECIOUS-16').Count -eq 0) $x } }
}
# --- symbolic links and junctions onto what they point at (second review of 103) ---
# a real (not a link) file of the folder holding the text
function RealHolders([string]$Dir, [string]$Text) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetFiles($LP + $Dir) | Where-Object { ([IO.File]::GetAttributes($_) -band [IO.FileAttributes]::ReparsePoint) -eq 0 -and [IO.File]::ReadAllText($_) -ceq $Text } | ForEach-Object { [IO.Path]::GetFileName($_) })
}
# "name=content" with links marked "->"
function LinkSnap([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return '(gone)' }
    $n = @()
    foreach ($e in [IO.Directory]::GetFileSystemEntries($LP + $Dir)) {
        $name = Esc ([IO.Path]::GetFileName($e)); $isLink = ([IO.File]::GetAttributes($e) -band [IO.FileAttributes]::ReparsePoint) -ne 0
        if ([IO.Directory]::Exists($e)) { $n += ($name + $(if ($isLink) { '/ (link)' } else { '/' })) }
        else { $t = '<unreadable>'; try { $t = [IO.File]::ReadAllText($e) } catch { }; $n += ($name + $(if ($isLink) { ' (link)=' } else { '=' }) + $t) }
    }
    return (($n | Sort-Object) -join '; ')
}
function Sym-Case([string]$Case) {
    $d = New-Case $Case; Put "$d\a.txt" 'PRECIOUS-SL'
    $r = Cmd ("mklink `"{0}`" `"{1}`"" -f "$d\lnk.txt", "$d\a.txt")
    if ($r.Rc -ne 0) { return $null }
    return $d
}
$Cases['sl-qren'] = {   # a symbolic link renamed onto the file it points at
    $d = Sym-Case 'sl-qren'; if (-not $d) { return @{ Skip = 'mklink (file symbolic link) refused' } }
    @{ Asked = 'Cannot move a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\lnk.txt"; Cmd = 754; Text = 'a.txt'
       Check = { $h = @(RealHolders $d 'PRECIOUS-SL'); Res ($h.Count -eq 1 -and $h[0] -ceq 'a.txt') ($h.Count -eq 0) (LinkSnap $d) } }
}
$Cases['sl-mov'] = {
    $d = Sym-Case 'sl-mov'; if (-not $d) { return @{ Skip = 'mklink (file symbolic link) refused' } }
    @{ Asked = 'Cannot move a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\lnk.txt"; Cmd = 728; Text = "$d\a.txt"
       Check = { $h = @(RealHolders $d 'PRECIOUS-SL'); Res ($h.Count -eq 1 -and $h[0] -ceq 'a.txt') ($h.Count -eq 0) (LinkSnap $d) } }
}
$Cases['slt-qren'] = {   # the mirror: the file renamed onto a link that points at it (the link is replaced)
    $d = Sym-Case 'slt-qren'; if (-not $d) { return @{ Skip = 'mklink (file symbolic link) refused' } }
    @{ Asked = 'Confirm File Overwrite'; NotAsked = 'itself'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 754; Text = 'lnk.txt'
       Check = { $h = @(RealHolders $d 'PRECIOUS-SL'); Res ($h.Count -eq 1 -and $h[0] -ceq 'lnk.txt') ($h.Count -eq 0) (LinkSnap $d) } }
}
$Cases['slt-mov'] = {
    $d = Sym-Case 'slt-mov'; if (-not $d) { return @{ Skip = 'mklink (file symbolic link) refused' } }
    @{ Asked = 'Confirm File Overwrite'; NotAsked = 'itself'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 728; Text = "$d\lnk.txt"
       Check = { $h = @(RealHolders $d 'PRECIOUS-SL'); Res ($h.Count -eq 1 -and $h[0] -ceq 'lnk.txt') ($h.Count -eq 0) (LinkSnap $d) } }
}
$Cases['sl-cpy'] = {   # the copy variants: the link copied onto its target, the target onto the link
    $d = Sym-Case 'sl-cpy'; if (-not $d) { return @{ Skip = 'mklink (file symbolic link) refused' } }
    @{ Asked = 'Cannot copy a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\lnk.txt"; Cmd = 727; Text = "$d\a.txt"
       Check = { $h = @(RealHolders $d 'PRECIOUS-SL'); $x = LinkSnap $d; Res ($h.Count -eq 1 -and $h[0] -ceq 'a.txt' -and $x -match 'lnk.txt \(link\)') ($h.Count -eq 0) $x } }
}
$Cases['slt-cpy'] = {
    $d = Sym-Case 'slt-cpy'; if (-not $d) { return @{ Skip = 'mklink (file symbolic link) refused' } }
    @{ Asked = 'Cannot copy a file to itself'; NotAsked = 'Confirm File Overwrite'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 727; Text = "$d\lnk.txt"
       Check = { $h = @(RealHolders $d 'PRECIOUS-SL'); $x = LinkSnap $d; Res ($h.Count -eq 1 -and $h[0] -ceq 'a.txt' -and $x -match 'lnk.txt \(link\)') ($h.Count -eq 0) $x } }
}
function Junc-Case([string]$Case) {
    $d = New-Case $Case; NewDir "$d\F"; Put "$d\F\f.txt" 'PRECIOUS-JN'
    $r = Cmd ("mklink /J `"{0}`" `"{1}`"" -f "$d\J", "$d\F"); if ($r.Rc -ne 0) { return $null }
    [void]$script:Links.Add("$d\J")
    [void]$script:Links.Add("$d\F\J")   # F6 onto an existing folder moves INTO it: F\J -> F (a loop) must go first
    return $d
}
$Cases['jn-qren'] = {   # a junction renamed onto the folder it points at
    $d = Junc-Case 'jn-qren'; if (-not $d) { return @{ Skip = 'mklink /J refused' } }
    @{ Asked = 'Cannot move a directory to itself'; FocusLast = $true; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\J"; Cmd = 754; Text = 'F'
       Check = { $f = [IO.File]::Exists($LP + "$d\F\f.txt") -and ([IO.File]::GetAttributes($LP + "$d\F") -band [IO.FileAttributes]::ReparsePoint) -eq 0; Res $f (-not [IO.File]::Exists($LP + "$d\F\f.txt")) ((LinkSnap $d) + ' | F: ' + (LinkSnap "$d\F")) } }
}
$Cases['jn-mov'] = {   # F6 of the junction with its target folder as the target: moved INTO it (both builds)
    $d = Junc-Case 'jn-mov'; if (-not $d) { return @{ Skip = 'mklink /J refused' } }
    @{ Asked = '^nothing$'; FocusLast = $true; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\J"; Cmd = 728; Text = "$d\F"
       Check = { $f = [IO.File]::Exists($LP + "$d\F\f.txt") -and ([IO.File]::GetAttributes($LP + "$d\F") -band [IO.FileAttributes]::ReparsePoint) -eq 0; Res $f (-not [IO.File]::Exists($LP + "$d\F\f.txt")) ((LinkSnap $d) + ' | F: ' + (LinkSnap "$d\F")) } }
}

# --- controls on NTFS ---
$Cases['case-qren'] = {
    $d = New-Case 'case-qren'; Put "$d\a.txt" 'PRECIOUS-17'
    @{ Asked = '^nothing$'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 754; Text = 'A.txt'
       Check = { $x = Snap $d; Res ($x -ceq 'A.txt=PRECIOUS-17') ((Holders $d 'PRECIOUS-17').Count -eq 0) $x } }
}
$Cases['norm-qren'] = {
    $d = New-Case 'norm-qren'; Put "$d\a.txt" 'PRECIOUS-18'; Put "$d\b.txt" 'other-18'
    @{ Asked = 'Confirm File Overwrite'; NotAsked = 'itself'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 754; Text = 'b.txt'
       Check = { $x = Snap $d; Res ($x -ceq 'b.txt=PRECIOUS-18') ((Holders $d 'PRECIOUS-18').Count -eq 0) $x } }
}
$Cases['norm-mov'] = {
    $d = New-Case 'norm-mov'; Put "$d\a.txt" 'PRECIOUS-19'; Put "$d\b.txt" 'other-19'
    @{ Asked = 'Confirm File Overwrite'; NotAsked = 'itself'; Dir = $d; Left = $d; Right = $StartDir; Focus = "$d\a.txt"; Cmd = 728; Text = "$d\b.txt"
       Check = { $x = Snap $d; Res ($x -ceq 'b.txt=PRECIOUS-19') ((Holders $d 'PRECIOUS-19').Count -eq 0) $x } }
}
$Cases['norm-cpy'] = {
    $d = New-Case 'norm-cpy'; NewDir "$d\s"; NewDir "$d\t"; Put "$d\s\a.txt" 'PRECIOUS-20'; Put "$d\t\a.txt" 'other-20'
    @{ Asked = 'Confirm File Overwrite'; NotAsked = 'itself'; Dir = $d; Left = "$d\s"; Right = "$d\t"; Focus = "$d\s\a.txt"; Cmd = 727; Text = "$d\t\"
       Check = { $x = (Snap "$d\s") + ' | ' + (Snap "$d\t"); Res ($x -ceq 'a.txt=PRECIOUS-20 | a.txt=PRECIOUS-20') ((Holders "$d\s" 'PRECIOUS-20').Count -eq 0) $x } }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc103_sf_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir; NewDir $DavBack
    Set-Config
    Set-Overwrite 1
    Out ("samefile_probe (feature 103) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    # the WebDAV server
    $script:DavOk = $false; $script:DavWhy = 'WebDAV not started'
    if (@(Get-Service WebClient -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }).Count -eq 0) { $script:DavWhy = 'the WebClient service is not running' }
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
