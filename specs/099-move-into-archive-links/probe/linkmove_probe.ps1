<#
.SYNOPSIS
    Feature 099 probe: F6 (move) from a disk panel into an existing ZIP / 7z archive
    open in the other panel must never delete a file that lies behind a link.

.DESCRIPTION
    Fixtures under %TEMP%\tc099_mv (removed at the end; junctions/symlinks are removed
    with rmdir BEFORE their targets' parents; an icacls deny is removed before the delete).
    X\x.txt lies outside the source folder S. Cases (each into ZIP and into 7z):
      jdir    S\B holds the junction J -> X (and b.txt); selection B
      jnest   S\B\sub\J -> X; selection B
      jself   the selection is the junction S\J -> X itself
      symd    S\B holds a directory symbolic link L -> X (mklink /D: refused without the
              privilege - then NOT DRIVEN)
      unread  S\B\U cannot be listed (icacls deny of "list folder" for the current user);
              selection B (098 rule: what the scan cannot check counts as a link)
      plain   S\B with b.txt and sub\c.txt, no link: packed and deleted as before
    Per case: start with -l S -r <archive> (the archive opens in the right panel), select
    the item, F6 (728), OK with the default target (the archive panel), answer the windows
    (OK / Yes), then read: X\x.txt exists?, the source left on disk, the archive's names.

    Expected with the fix: link cases - the link warning (IDS_DELFILESAFTERPACKINGNOLINKS),
    nothing packed, nothing deleted, X\x.txt kept; plain - packed and deleted.
    The build before 099 is the control (link cases: X\x.txt deleted).

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
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc099_mv'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$script:Links = New-Object System.Collections.ArrayList   # junctions / symlinks to remove first
$script:Denied = New-Object System.Collections.ArrayList  # folders with an icacls deny to lift
$Me = [Security.Principal.WindowsIdentity]::GetCurrent().Name

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
function New-Link([string]$Kind, [string]$Link, [string]$Target) {
    $r = Cmd ("mklink {0} `"{1}`" `"{2}`"" -f $Kind, $Link, $Target)
    if ($r.Rc -eq 0) { [void]$script:Links.Add($Link) }
    return $r
}
function Remove-Links {
    foreach ($d in @($script:Denied)) { [void](Cmd ("icacls `"{0}`" /remove:d `"{1}`"" -f $d, $Me)) }
    $script:Denied.Clear()
    foreach ($l in @($script:Links)) {
        if ([IO.Directory]::Exists($l)) { [void](Cmd ("rmdir `"{0}`"" -f $l)) }
        if ([IO.Directory]::Exists($l)) { Out ('Link: COULD NOT REMOVE ' + $l) }
    }
    $script:Links.Clear()
}
function Arc-Names([string]$Arc) {
    if (-not [IO.File]::Exists($Arc)) { return '(no archive)' }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $l = & $SevenZip l -ba -slt $Arc 2>&1; $ErrorActionPreference = $old
    return ((@($l | Where-Object { $_ -match '^Path = ' } | ForEach-Object { $_ -replace '^Path = ', '' }) | Sort-Object) -join ', ')
}
function Disk-Names([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return '(gone)' }
    $n = @()
    foreach ($e in [IO.Directory]::GetFileSystemEntries($LP + $Dir, '*', [IO.SearchOption]::TopDirectoryOnly)) {
        $n += [IO.Path]::GetFileName($e)
    }
    return (($n | Sort-Object) -join ', ')
}

function Run-Case([string]$Case, [string]$Fmt, [string]$Kind) {
    $base = $Root + '\' + $Case
    $src = $base + '\S'
    $x = $base + '\X'
    NewDir $x; WriteFile ($x + '\x.txt') "outside the selection`r`n"
    NewDir $src
    $sel = 'B'
    switch ($Kind) {
        'jdir' { NewDir ($src + '\B'); WriteFile ($src + '\B\b.txt') "b`r`n"; $r = New-Link '/J' ($src + '\B\J') $x }
        'jnest' { NewDir ($src + '\B\sub'); WriteFile ($src + '\B\b.txt') "b`r`n"; $r = New-Link '/J' ($src + '\B\sub\J') $x }
        'jself' { $sel = 'J'; $r = New-Link '/J' ($src + '\J') $x }
        'symd' { NewDir ($src + '\B'); WriteFile ($src + '\B\b.txt') "b`r`n"; $r = New-Link '/D' ($src + '\B\L') $x }
        'unread' {
            NewDir ($src + '\B\U'); WriteFile ($src + '\B\b.txt') "b`r`n"; WriteFile ($src + '\B\U\u.txt') "u`r`n"
            $r = Cmd ("icacls `"{0}`" /deny `"{1}`":(RD)" -f ($src + '\B\U'), $Me)
            if ($r.Rc -eq 0) { [void]$script:Denied.Add($src + '\B\U') }
        }
        'plain' { NewDir ($src + '\B\sub'); WriteFile ($src + '\B\b.txt') "b`r`n"; WriteFile ($src + '\B\sub\c.txt') "c`r`n"; $r = [pscustomobject]@{ Rc = 0; Text = '' } }
    }
    if ($r.Rc -ne 0) { Row $Case 'MOVE' 'NOT DRIVEN' ('fixture refused: ' + $r.Text); Remove-Links; return }
    if ($Kind -eq 'unread') {
        try { [void][IO.Directory]::GetFileSystemEntries($src + '\B\U'); Row $Case 'MOVE' 'NOT DRIVEN' 'icacls deny did not make the folder unreadable'; Remove-Links; return } catch { }
    }
    # the existing archive with seed.txt
    $arc = $OutDir + '\' + $Case + '.' + $Fmt
    $seedDir = $OutDir + '\seed_' + $Case; NewDir $seedDir; WriteFile ($seedDir + '\seed.txt') "seed`r`n"
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $seedDir
    try { $o = & $SevenZip a ('-t' + $Fmt) $arc 'seed.txt' 2>&1 } finally { Pop-Location; $ErrorActionPreference = $old }
    $before = Reports; $id = 0; $fatal = $null
    $script:StartDirSave = $StartDir
    try {
        $StartDir = $arc   # Start-Tc puts the right panel on $StartDir: the archive
        $id = Start-Tc $src
        $StartDir = $script:StartDirSave
        # focus the item: Home, then Down until the item (the list holds ".." and the one item)
        Key $id 0x24; Key $id 0x23
        $dlg = Open-ByCmd $id 728
        if ($dlg -eq [IntPtr]::Zero) { throw 'Move (728) opened no window' }
        $fld = Find-Ctl $dlg 210
        $target = [Drv098f]::GetText($fld, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 120
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $warned = @($r.Messages | Where-Object { $_ -match 'link to directory' }).Count
        # feature 101: an unreadable folder gets its own text (IDS_DELFILESAFTERPACKINGUNREADABLE)
        # instead of the link text; the same refusal (nothing packed, nothing deleted)
        if ($Kind -eq 'unread') { $warned += @($r.Messages | Where-Object { $_ -match 'cannot be read, so it' }).Count }
        $xAlive = [IO.File]::Exists($LP + $x + '\x.txt')
        $left = Disk-Names $src
        $names = Arc-Names $arc
        $msgs = (@($r.Messages | ForEach-Object { if ($_.Length -gt 150) { $_.Substring(0, 150) + '...' } else { $_ } }) -join ' || ')
        if ($Kind -eq 'plain') {
            $ok = (-not $fatal) -and $warned -eq 0 -and ($names -match 'B\\b\.txt') -and ($names -match 'B\\sub\\c\.txt') -and ($left -notmatch '(^|, )B(,|$)')
        }
        else {
            $ok = (-not $fatal) -and $xAlive -and $warned -ge 1 -and ($left -match '(^|, )' + $sel + '(,|$)') -and ($names -eq 'seed.txt')
        }
        Row $Case 'MOVE' (V $ok) ("F6 of {0} to the default target '{1}'; link warning {2}; X\x.txt survives: {3}; left in S: [{4}]; archive: [{5}]; windows: {6}{7}" -f $sel, (Esc $target), $warned, $xAlive, (Esc $left), (Esc $names), $(if ($msgs) { $msgs } else { 'none' }), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { $StartDir = $script:StartDirSave; if ($id) { End-Row $Case $id $fatal $before }; Remove-Links }
}

# ---- main --------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc099_mv_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir
    Set-Config
    Out ("linkmove_probe (feature 099) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; user {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, (Esc $Me))
    Out ''
    foreach ($k in 'jdir', 'jnest', 'jself', 'symd', 'unread', 'plain') {
        foreach ($fmt in 'zip', '7z') { $n = $k + $fmt; if (Want $n) { Run-Case $n $fmt $k } }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    try { Remove-Links } catch { Out ('Links: ' + $_.Exception.Message) }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
