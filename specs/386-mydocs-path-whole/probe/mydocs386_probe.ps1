<#
.SYNOPSIS
    Feature 386 probe: the Documents drive must open the Documents folder whole - never the folder
    whose name is its first 259 bytes.

.DESCRIPTION
    The Documents folder is named by the Debug-only seam TC_PROBE_MYDOCS_FILE (feature 386,
    specs/386-mydocs-path-whole/contracts/salmydocs.md) - the user's real Documents is never touched.
    The drive bar's Documents button is pressed by WM_COMMAND CM_DRIVEBAR_MIN (3500) + its index,
    read from the TC_PROBE_DRIVES_DUMP seam (ALL idx=.. type=7 = drvtMyDocuments, features 246 / 289).
    The panel's location is read from the Change Directory field (Get-Loc).
      SHORT   control: Documents = <root>\docs_short; PASS = the panel shows it
      LONG    Documents = <root>\<90 CJK letters> (fewer than 260 UTF-16 units, more than 259 bytes
              of UTF-8); the folder named like its 259-byte prefix exists too.
              PASS = the panel shows the whole folder; FAIL = the prefix folder (the cut)
      LONG200 Documents = <root>\<200 CJK letters> (240 units, 640 bytes - more than the old
              520-byte intermediate buffer); PASS = the whole folder (before: the Desktop)
      RESCUE-SHORT / RESCUE-LONG  the rescue path "Documents": the left panel on a subst drive
              whose folder then denies listing to this user (icacls, removed at once), refresh
              (CM_LEFTREFRESH 724). SHORT PASS = the short folder; LONG PASS = not the prefix
              folder (the whole folder or a drive root - the rescue path holds MAX_PATH bytes)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Only,
    [switch]$DumpMsg   # debug: the code units of the first message after the button
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc386'
$StartDir = $Root + '\start'
$RegBackup = $env:TEMP + '\tc386_backup.reg'
$Long = -join (1..90 | ForEach-Object { [char](0x4E00 + $_) })
$LongDir = $Root + '\' + $Long
$ShortDir = $Root + '\docs_short'

# the longest prefix of 's' (whole characters) whose UTF-8 form holds at most 'max' bytes
function Cut-U8([string]$s, [int]$max) {
    $n = $s.Length
    while ($n -gt 0 -and (U8Len $s.Substring(0, $n)) -gt $max) { $n-- }
    return $s.Substring(0, $n)
}
$PrefixDir = Cut-U8 $LongDir 259
# review 1 of 386, SHOULD 2: 200 letters (240 units, 640 bytes) - more than the old 520-byte
# intermediate buffer held: the old code gave the Desktop even to the long-path drive bar route
$Long200Dir = $Root + '\' + (-join (1..200 | ForEach-Object { [char](0x4E00 + $_) }))
# a free letter for the RESCUE rows' subst drive: not listed, not remembered as a network drive
$usedLetters = @([IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpper() })
$remembered = @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName.ToUpper() })
$script:SubstLetter = @([char[]]'YXWVUTSRQPONMLKJ' | ForEach-Object { [string]$_ } | Where-Object { $usedLetters -notcontains $_ -and $remembered -notcontains $_ } | Select-Object -First 1)
if ($script:SubstLetter.Count) { $script:SubstLetter = $script:SubstLetter[0] } else { $script:SubstLetter = $null }
$script:SubstMade = $false; $script:DenyOn = $null

function Dump-Lines([string]$f) { if (Test-Path -LiteralPath $f) { return @([IO.File]::ReadAllLines($f, $Utf8)) } else { return @() } }
# index of the Documents item (type 7) in the last drive bar 1 build of the dump, or -1
function Docs-Index([string]$f) {
    $l = Dump-Lines $f
    $start = -1
    for ($i = $l.Count - 1; $i -ge 0; $i--) { if ($l[$i] -like 'BUILD bar=1 copy=0 *') { $start = $i; break } }
    if ($start -lt 0) { return -1 }
    # the ALL lines of that build (feature 289) list the whole list - drives, Documents, ...
    for ($i = $start + 1; $i -lt $l.Count; $i++) {
        if ($l[$i] -like 'BUILD *') { break }
        $m = [regex]::Match($l[$i], '^ALL idx=(\d+) type=(\d+) ')
        if ($m.Success -and [int]$m.Groups[2].Value -eq 7) { return [int]$m.Groups[1].Value }
    }
    return -1
}
function Start-Row([string]$Docs, [string]$Left, [string]$Dump) {
    # the seam takes a file (ASCII path) holding the folder in UTF-8: the program copies its
    # environment through the code page at start, a CJK value would arrive as '?' (measured)
    $docsFile = $Root + '\docs.txt'
    [IO.File]::WriteAllText($docsFile, $Docs, $Utf8)
    $env:TC_PROBE_MYDOCS_FILE = $docsFile
    $env:TC_PROBE_DRIVES_DUMP = $Dump
    try {
        $a = @('-t', 'T386', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
        $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    }
    finally { Remove-Item Env:\TC_PROBE_MYDOCS_FILE -ErrorAction SilentlyContinue; Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue }
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    $r = Serve $p.Id 30
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return @{ Id = $p.Id; Start = $r }
}
function Loc-Name([string]$loc) {
    if ($loc -ceq $LongDir -or $loc -ceq ($LongDir + '\')) { return 'the whole Documents folder' }
    if ($loc -ceq $PrefixDir -or $loc -ceq ($PrefixDir + '\')) { return 'the PREFIX folder (cut path)' }
    if ($loc -ceq $ShortDir -or $loc -ceq ($ShortDir + '\')) { return 'the short Documents folder' }
    if ($loc -ceq $Long200Dir -or $loc -ceq ($Long200Dir + '\')) { return 'the whole 200-letter Documents folder' }
    return 'other'
}
function Press-Docs([int]$Id, [string]$Dump) {
    $idx = Docs-Index $Dump
    if ($idx -lt 0) {
        $l = @(Dump-Lines $Dump | Where-Object { $_ -like 'BUILD*' -or $_ -like 'ITEM*' -or $_ -like 'ALL*' } | Select-Object -First 40)
        foreach ($x in $l) { Out ('  dump: ' + (Esc $x)) }
        return @{ Ok = $false; Facts = ('no Documents item on drive bar 1 in the dump ({0} lines)' -f (Dump-Lines $Dump).Count) }
    }
    Post-Cmd (Get-Main $Id) (3500 + $idx)   # CM_DRIVEBAR_MIN + index
    if ($DumpMsg) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 10) {
            $w = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
            if ($w.Count) {
                foreach ($c in [Drv098f]::Kids($w[0])) {
                    $t = [Drv098f]::Txt($c)
                    if ($t.Length -gt 20) { Out ('  msg units: ' + (($t.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ')) }
                }
                break
            }
            Start-Sleep -Milliseconds 100
        }
    }
    $r = Serve $Id 30
    Start-Sleep -Milliseconds 800
    return @{ Ok = $true; Facts = ('button idx {0}; windows: {1}' -f $idx, (Msgs $r)) }
}

$existed = $false; $regOk = $true; $backedUp = $false
try {
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath ($LP + $Root) -Recurse -Force }
    NewDir $StartDir; NewDir $ShortDir; NewDir $LongDir; NewDir $PrefixDir
    Out ("386 probe, exe {0}" -f $Exe)
    Out ("Documents LONG: {0} units, {1} bytes of UTF-8; prefix folder {2} units, {3} bytes" -f $LongDir.Length, (U8Len $LongDir), $PrefixDir.Length, (U8Len $PrefixDir))
    $existed = Backup-Reg $RegBackup
    $backedUp = $true
    Set-Config
    & cmd.exe /c "reg query `"$RegKey\Settings\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) {
        & reg.exe add "$RegKey\Settings\Configuration" /v 'Show Drive Bar' /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "$RegKey\Settings\Configuration" /v 'If Path Is Inaccessible Go To My Docs' /t REG_DWORD /d 1 /f | Out-Null
    }

    foreach ($row in @(@{ Case = 'SHORT'; Docs = $ShortDir; Want = $ShortDir }, @{ Case = 'LONG'; Docs = $LongDir; Want = $LongDir },
            @{ Case = 'LONG200'; Docs = $Long200Dir; Want = $Long200Dir })) {
        if (-not (Want $row.Case)) { continue }
        if ($row.Case -eq 'LONG200' -and -not (Test-Path -LiteralPath ($LP + $Long200Dir))) { NewDir $Long200Dir }
        $dump = $Root + '\dump_' + $row.Case + '.txt'
        $s = Start-Row $row.Docs $StartDir $dump
        try {
            $before = Get-Loc $s.Id
            $p = Press-Docs $s.Id $dump
            $loc = Get-Loc $s.Id
            $ok = $p.Ok -and ($loc -ceq $row.Want -or $loc -ceq ($row.Want + '\'))
            Row $row.Case 'DRIVE' (V $ok) ('{0}; panel before {1}; after: {2} = {3}' -f $p.Facts, (Tail $before), (Loc-Name $loc), (Tail $loc 60))
        }
        finally { Stop-Tc $s.Id }
    }

    # RESCUE (review 1 of 386, SHOULD 1): a root that exists but cannot be listed - a subst drive
    # on <root>\substroot, the left panel on it, then the listing right of that folder denied to
    # this user and the panel refreshed (CM_LEFTREFRESH 724); the panel takes the rescue path
    # "Documents". (A drive letter that does not exist only gives "path invalid".)
    if ((Want 'RESCUE') -and $script:SubstLetter) {
        $subT = $Root + '\substroot'
        NewDir $subT
        $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        & subst.exe ($script:SubstLetter + ':') $subT | Out-Null
        if ($LASTEXITCODE -ne 0) { Row 'RESCUE' 'SUBST' 'FAIL' ('subst {0}: failed' -f $script:SubstLetter) }
        else {
            $script:SubstMade = $true
            try {
                foreach ($row in @(@{ Case = 'RESCUE-SHORT'; Docs = $ShortDir }, @{ Case = 'RESCUE-LONG'; Docs = $LongDir })) {
                    if (-not (Want $row.Case)) { continue }
                    $dump = $Root + '\dump_' + $row.Case + '.txt'
                    $s = Start-Row $row.Docs ($script:SubstLetter + ':\') $dump
                    try {
                        $start = Get-Loc $s.Id
                        & icacls.exe $subT /deny ($me + ':(RD)') | Out-Null
                        $script:DenyOn = $subT
                        Post-Cmd (Get-Main $s.Id) 724   # CM_LEFTREFRESH
                        Start-Sleep -Milliseconds 1500
                        $r = Serve $s.Id 10
                        & icacls.exe $subT /remove:d $me | Out-Null
                        $script:DenyOn = $null
                        $loc = Get-Loc $s.Id
                        $name = Loc-Name $loc
                        if ($row.Case -eq 'RESCUE-SHORT') { $ok = $name -eq 'the short Documents folder' }
                        else { $ok = $name -ne 'the PREFIX folder (cut path)' -and ($name -eq 'the whole Documents folder' -or $loc -match '^[A-Za-z]:\\$') }
                        Row $row.Case 'RESCUE' (V $ok) ('start {0}; windows: {1}; panel: {2} = {3}' -f (Tail $start 20), (Msgs $r), $name, (Tail $loc 60))
                    }
                    finally {
                        if ($script:DenyOn) { & icacls.exe $script:DenyOn /remove:d $me | Out-Null; $script:DenyOn = $null }
                        Stop-Tc $s.Id
                    }
                }
            }
            finally { & subst.exe ($script:SubstLetter + ':') /d | Out-Null; $script:SubstMade = $false }
        }
    }
    elseif (Want 'RESCUE') { Row 'RESCUE' 'SUBST' 'FAIL' 'no free drive letter for subst' }
}
catch { Row 'PROBE' 'ERROR' 'FAIL' $_.Exception.Message }
finally {
    foreach ($id in $Started) { if (Test-Alive $id) { Kill-Mine $id } }
    if ($script:DenyOn) { & icacls.exe $script:DenyOn /remove:d ([Security.Principal.WindowsIdentity]::GetCurrent().Name) | Out-Null }
    if ($script:SubstMade) { & subst.exe ($script:SubstLetter + ':') /d | Out-Null }
    if ($backedUp) { $regOk = Restore-Reg $RegBackup $existed }
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath ($LP + $Root) -Recurse -Force -ErrorAction SilentlyContinue }
}
$fails = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
if (-not $regOk) { $fails++ }
Out ("RESULT: {0} row(s), {1} FAIL; registry restored {2}" -f $script:Rows.Count, $fails, $regOk)
exit $fails
