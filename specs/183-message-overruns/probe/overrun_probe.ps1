<#
.SYNOPSIS
    Feature 183 probe: message boxes and dialogs fed with long paths do not overrun the stack.

.DESCRIPTION
      UNPACK-LONG  the left panel inside a.zip (made by 7z.exe), the right panel in a folder whose
                   path has more than 979 bytes (three levels of 170 Czech letters), F5 (727): the
                   unpack dialog opens (before: strcpy of the right panel's path into a 980-byte
                   buffer) - cancelled.
      EMAIL-DEEP   a folder tree whose deepest folder has a path over 620 bytes and holds a broken
                   junction (its target does not exist - listing it fails with 3); the top folder
                   selected, Email files (733): the "cannot read directory" box names the path
                   (before: sprintf into 2 * MAX_PATH + 100). NOT DRIVEN when no MAPI client is
                   installed (the command stops before it lists anything).
    PASS = the box / dialog shown, the program alive, no fatal window, no bug report.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc183'
$StartDir = $Root + '\start'
function C([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
$Cz = (C @(0x10D, 0x159, 0x17E, 0x161, 0x11B)) * 34   # 170 Czech letters = 340 bytes

function Run-Unpack {
    if (-not (Want 'UNPACK-LONG')) { return }
    $src = $Root + '\arc'; NewDir $src
    WriteFile ($src + '\x.txt') 'x'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $src; [void](& $SevenZip a -tzip a.zip x.txt 2>&1); Pop-Location
    $ErrorActionPreference = $old
    $long = $Root + '\' + $Cz + '\' + $Cz + '\' + $Cz
    NewDir $long
    $id = 0; $before = Reports; $fatal = $null
    try {
        $id = Start-Tc $src
        # the right panel into the long folder (a start parameter that long is not taken): Tab,
        # Change Directory, Tab back
        Key $id 0x09
        [void](Do-ChangeDir $id $long)
        [void](Serve $id 5 @(2))
        $right = Get-Loc $id
        Key $id 0x09
        [void](Do-ChangeDir $id ($src + '\a.zip\'))   # into the archive
        Start-Sleep -Milliseconds 1500
        [void](Serve $id 5 @(2))
        $inArc = Get-Loc $id
        Out ('           left panel: ' + (Esc $inArc))
        Key $id 0x23   # End: x.txt (the first item is "..")
        $dlg = Open-ByCmd $id 727 10
        $fatal = Fatal-Win $id
        $d = $(if ($dlg -ne [IntPtr]::Zero) { WinDesc $dlg } else { 'no window' })
        if ($dlg -ne [IntPtr]::Zero -and -not $fatal) { Close-Win $dlg }
        $r = Serve $id 5 @(2)
        if (-not $fatal) { $fatal = $r.Fatal }
        End-Row 'UNPACK-LONG' $id $fatal $before; $id = 0
        Row 'UNPACK-LONG' 'DIALOG' (V (($d -match 'Unpack|Rozbal|from archive|z archivu|Copy|Kop') -and $inArc -match 'a.zip' -and -not $fatal -and $right.TrimEnd('\') -ieq $long)) ("right panel {0} bytes (in it: {1}); window: {2}{3}" -f (U8Len $long), ($right.TrimEnd('\') -ieq $long), (Tail $d 160), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row 'UNPACK-LONG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row 'UNPACK-LONG' $id $fatal $before } }
}

function Run-Email {
    if (-not (Want 'EMAIL-DEEP')) { return }
    $top = $Root + '\mail'
    $deep = $top + '\' + $Cz + '\' + $Cz
    NewDir $deep
    # a broken junction, made short and moved in
    $jt = $Root + '\jt'; NewDir $jt
    & cmd.exe /c "mklink /J `"$Root\j`" `"$jt`"" | Out-Null
    [IO.Directory]::Delete($LP + $jt)
    [IO.Directory]::Move($LP + $Root + '\j', $LP + $deep + '\j')
    $id = 0; $before = Reports; $fatal = $null
    try {
        $id = Start-Tc $Root
        [void](Do-ChangeDir $id ($top))
        [void](Serve $id 5 @(2))
        Post-Cmd (Get-Main $id) 733
        # the box: OK = go on; anything else recorded
        $r = Serve $id 25 @(2)
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $m = Msgs $r
        End-Row 'EMAIL-DEEP' $id $fatal $before; $id = 0
        if ($m -notmatch '\(3\)' -and -not $fatal) { Row 'EMAIL-DEEP' 'BOX' 'NOT DRIVEN' ("no listing error box (no MAPI client?): " + (Tail $m 200)) }
        else { Row 'EMAIL-DEEP' 'BOX' (V (-not $fatal)) ("deepest folder {0} bytes; windows: {1}{2}" -f (U8Len ($deep + '\j')), (Tail $m 200), $(if ($fatal) { '; FATAL ' + $fatal } else { '' })) }
    }
    catch { Row 'EMAIL-DEEP' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { End-Row 'EMAIL-DEEP' $id $fatal $before }
        try { [IO.Directory]::Delete($LP + $deep + '\j') } catch { }   # the junction itself (not followed)
    }
}

$backup = Join-Path $env:TEMP 'tc183_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("overrun_probe (feature 183), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    Run-Unpack
    Run-Email
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
if ($Expect -eq 'before') { exit 0 }
exit $nf
