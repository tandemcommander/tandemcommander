<#
.SYNOPSIS
    Feature 390 probe: the Registry Editor plug-in's Move (F6) of a key seen through
    HKEY_CLASSES_ROOT (the merged view of the machine's and the user's classes) into the user's
    Classes key.

.DESCRIPTION
    A real extension key of this machine held only by the machine's half (HKLM\Software\Classes\<X>,
    not in HKCU\Software\Classes; one value at least, exactly one subkey) is only read: the probe
    never runs elevated, so the machine's half cannot be written or deleted. Its user copy (made by
    the Move) is removed after each row.

    Fixture (created before each row, removed at the end):
      HKCU\Software\Classes\TcProbe390\Zdroj\<K>   value v = ALPHA, subkey <P> with w = BETA
      HKCU\Software\Classes\TcProbe390\Cil         empty
      HKCU\Software\TcProbe390\Cil                 empty
    <K> = "Klic zlutoucky", <P> = "podklic", each with its Czech accents. Through the merged view the
    first is HKEY_CLASSES_ROOT\TcProbe390\... (only in the user's half).

      MACHUSER   F6 of HKCR\<X> (focused at the HKCR root by Backspace from it) into
                 \HKEY_CURRENT_USER\Software\Classes\, every box answered Cancel: the copy is made in
                 the user's half, then the source is deleted in the MACHINE's half - without
                 elevation "Unable to remove the original registry key." naming
                 HKEY_LOCAL_MACHINE\Software\Classes\<X>\<sub> (access denied); the machine's half
                 unchanged; the user's copy equals the machine's key (an honest copy, not a silent
                 no-op). Before the fix: no box, the user's copy deleted again, nothing changed
      MACHUSERU  the same into \HKEY_USERS\<SID>_Classes\ (the same key under another root)
      USERMOVE   (control) F6 of HKCR\TcProbe390\Zdroj\<K> (only in the user's half) into
                 \HKEY_CURRENT_USER\Software\TcProbe390\Cil\: no box; moved whole; the source gone
      USERHKCR   (control) F6 of the same into \HKEY_CLASSES_ROOT\TcProbe390\Cil\: no box; moved
                 whole into the user's TcProbe390\Cil; the source gone
      END        each instance ends with exit code 0, no stray window, no report

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lang = 'english'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$Root = $TempRoot + '\tc390'
$StartDir = $Root + '\start'
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# Czech names (pure ASCII source); no variable may share a name with another ignoring case
$K = 'Kl' + (Chars @(0x00ED, 0x010D)) + ' ' + [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD
$Sub = 'podkl' + (Chars @(0x00ED, 0x010D))
$Sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$RegName = 'TcProbe390'
$ClsPs = 'HKCU:\Software\Classes\' + $RegName                    # HKCR\TcProbe390 (user's half only)
$PlainPs = 'HKCU:\Software\' + $RegName
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P {
    $a = @('-t', 'T390', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $proc = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($proc.Id); [void]$proc.Handle; $script:Procs[$proc.Id] = $proc
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $proc.Id) -and (Get-Main $proc.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $proc.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $proc.Id).Path -ine $Exe) { throw "pid $($proc.Id) is not $Exe" }
    try { [void]$proc.WaitForInputIdle(30000) } catch { }
    Sync $proc.Id
    Start-Sleep -Milliseconds 1500
    return $proc.Id
}
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\Settings\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
function Template([int]$Id, [string]$English) {
    if ($Lang -eq 'english') { return $English }
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $RepoRoot ("translations\{0}\regedt.slt" -f $Lang)), $Utf8)) {
        if ($line -match ('^' + $Id + ',\d+,"(.*)"\s*$')) { return $Matches[1].Replace('""', '"').Replace('\n', "`n").Replace('\t', "`t").Replace('\\', '\') }
    }
    throw "id $Id not found in the $Lang translation"
}
function End-P([string]$Case, [int]$Id, $Before) { $fatal = Fatal-Win $Id; End-Row $Case $Id $fatal $Before }
function Box-Text([IntPtr]$H) {
    $st = Kid $H 2477                                            # the program's message box
    if ($st) { return [Drv098f]::GetText($st, 5000).Replace("`r", '') }
    return (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::Cls($_) -ne 'Button' } | ForEach-Object { [Drv098f]::GetText($_, 5000).Replace("`r", '') } | Where-Object { $_ }) -join "`n")
}
function New-Boxes([int]$Id, $Known, [double]$Seconds = 8) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $n = @(Get-Tops $Id | Where-Object { $Known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' })
        if ($n.Count) { Start-Sleep -Milliseconds 700; return $n }
        Start-Sleep -Milliseconds 150
    }
    return @()
}
function Press([IntPtr]$H, [int[]]$Ids) {
    if ($H -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($H)) { return }
    $b = $null
    foreach ($want in $Ids) { $b = Buttons $H | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1; if ($b) { break } }
    if ($b) { Click $b } else { Close-Win $H }
    Start-Sleep -Milliseconds 600
}
function Close-Boxes([int]$Id) {
    for ($i = 0; $i -lt 6; $i++) {
        $b = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })
        if (-not $b.Count) { return }
        foreach ($h in $b) { Press $h @(2, 7, 1) }
    }
}
function Go([int]$Id, [string]$Path) { [void](Do-ChangeDir $Id $Path); Sync $Id; Start-Sleep -Milliseconds 1200 }

# ---- the machine-only key (only read) -------------------------------------------------------
function Pick-MachineOnly {
    foreach ($k in @(Get-ChildItem -LiteralPath 'HKLM:\Software\Classes' -ErrorAction SilentlyContinue | Sort-Object PSChildName)) {
        $n = $k.PSChildName
        if ($n -cnotmatch '^\.[a-z0-9]{2,5}$') { continue }
        if ($k.ValueCount -lt 1 -or $k.SubKeyCount -ne 1) { continue }
        if (Test-Path -LiteralPath ('HKCU:\Software\Classes\' + $n)) { continue }
        $all = @(Get-ChildItem -LiteralPath $k.PSPath -Recurse -ErrorAction SilentlyContinue)
        if ($all.Count -ne 1 -or $all[0].SubKeyCount -ne 0) { continue }
        return $n
    }
    return $null
}
# every key of a tree: relative path, class-free values (sorted); '(missing)' when absent
function Snap-Tree([string]$PsTop) {
    if (-not (Test-Path -LiteralPath $PsTop)) { return '(missing)' }
    $top = Get-Item -LiteralPath $PsTop
    $out = @()
    foreach ($item in @(@($top) + @(Get-ChildItem -LiteralPath $PsTop -Recurse -ErrorAction SilentlyContinue))) {
        $rel = $(if ($item.Name.Length -gt $top.Name.Length) { $item.Name.Substring($top.Name.Length + 1) } else { '.' })
        $vals = @($item.GetValueNames() | Sort-Object | ForEach-Object { $_ + '=' + $item.GetValueKind($_) + ':' + (@($item.GetValue($_, $null, 'DoNotExpandEnvironmentNames')) -join ',') }) -join ';'
        $out += ('{0}|{1}' -f $rel, $vals)
    }
    return (@($out | Sort-Object) -join "`n")
}

# ---- the fixture ---------------------------------------------------------------------------
function New-Key([string]$PsPath) { [void](New-Item -Path $PsPath -Force) }
function Remove-Fixture { foreach ($top in @($ClsPs, $PlainPs)) { Remove-Item -LiteralPath $top -Recurse -Force -ErrorAction SilentlyContinue } }
function Make-Fixture {
    NewDir $StartDir
    Remove-Fixture
    New-Key ($ClsPs + '\Zdroj\' + $K + '\' + $Sub)
    [void](New-ItemProperty -LiteralPath ($ClsPs + '\Zdroj\' + $K) -Name 'v' -Value 'ALPHA' -PropertyType String -Force)
    [void](New-ItemProperty -LiteralPath ($ClsPs + '\Zdroj\' + $K + '\' + $Sub) -Name 'w' -Value 'BETA' -PropertyType String -Force)
    New-Key ($ClsPs + '\Cil')
    New-Key ($PlainPs + '\Cil')
}
function Snapshot { return ('C:' + (Snap-Tree $ClsPs) + "`nP:" + (Snap-Tree $PlainPs)) }
function Moved-Into([string]$PsTarget) {
    return ((Snap-Tree ($PsTarget + '\' + $K)) -ceq (".|v=String:ALPHA`n" + $Sub + '|w=String:BETA')) -and -not (Test-Path -LiteralPath ($ClsPs + '\Zdroj\' + $K))
}

# one Move (728) from the panel path $From, the item focused by $Keys (or by Backspace from
# $script:GoUpFrom), to the typed target $Target; every box that comes is recorded and answered with
# the first of $Answer it has (Cancel when none)
function Run-Op([int]$Cmd, [string]$From, [int[]]$Keys, [string]$Target, [int[]]$Answer) {
    $res = @{ Boxes = @(); Pre = $null }
    $id = Start-P
    $res.Id = $id
    if ($script:GoUpFrom) {
        Go $id $script:GoUpFrom
        Key $id 0x08                                               # Backspace: the parent, the key focused
        Sync $id; Start-Sleep -Milliseconds 1500
    }
    else { Go $id $From }
    foreach ($vk in $Keys) { Key $id $vk }
    $known = Get-Tops $id
    Post-Cmd (Get-Main $id) $Cmd
    $dlg = Wait-NewWin $id $known 10
    if ($dlg -eq [IntPtr]::Zero) { throw 'Move opened no dialog' }
    $edit = @([Drv098f]::Kids($dlg) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) }) | Select-Object -First 1
    if (-not $edit) { throw ('no edit field in the dialog: ' + (WinDesc $dlg)) }
    $res.Pre = [Drv098f]::GetText($edit, 5000)
    [void][Drv098f]::SetText($edit, $Target, 5000)
    $known2 = Get-Tops $id
    Click-Ok $dlg
    for ($i = 0; $i -lt 5; $i++) {
        $boxes = New-Boxes $id $known2 $(if ($i -eq 0) { 8 } else { 4 })
        if (-not $boxes.Count) { break }
        $h = $boxes[0]
        $res.Boxes += @{ Desc = (WinDesc $h); Text = (Box-Text $h) }
        Press $h $(if ($Answer) { $Answer } else { @(2) })
        $known2 = @($known2) + $h
    }
    Sync $id
    Start-Sleep -Milliseconds 1500
    Close-Boxes $id
    return $res
}

function Row-Op([string]$Case, [int]$Cmd, [string]$From, [int[]]$Keys, [string]$Target, [int[]]$Answer, [scriptblock]$Judge) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        Make-Fixture
        $r = @{}
        $snap0 = Snapshot
        $mach0 = $(if ($script:MachName) { Snap-Tree ('HKLM:\Software\Classes\' + $script:MachName) } else { '' })
        $r = Run-Op $Cmd $From $Keys $Target $Answer
        $id = $r.Id
        $r.Snap = Snapshot
        $r.Unchanged = ($snap0 -ceq $r.Snap)
        if ($script:MachName) {
            $r.Mach0 = $mach0
            $r.Mach1 = Snap-Tree ('HKLM:\Software\Classes\' + $script:MachName)
            $r.User1 = Snap-Tree ('HKCU:\Software\Classes\' + $script:MachName)
        }
        & $Judge $r
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { Close-Boxes $id; End-P $Case $id $before }
        if ($script:MachName -and -not $script:UserHadIt) { Remove-Item -LiteralPath ('HKCU:\Software\Classes\' + $script:MachName) -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function Box-Facts($r) {
    if (-not $r.Boxes.Count) { return 'boxes: none' }
    return ('boxes: ' + (($r.Boxes | ForEach-Object { "{0}; text '{1}'" -f $_.Desc, (Esc $_.Text) }) -join ' || '))
}
$Removesrc = Template 1061 'Unable to remove the original registry key. '
$FocusK = @(0x24, 0x28)                                            # "..", then <K> (the only key)
$script:GoUpFrom = $null
$script:MachName = $null
$script:UserHadIt = $true

function Mach-Row([string]$Case, [string]$Target) {
    if (-not (Want $Case)) { return }
    if ($IsAdmin) { Row $Case 'RUN' 'NOT DRIVEN' 'the probe runs elevated: a fixed build would really move the machine key'; return }
    if (-not $script:MachName) { Row $Case 'RUN' 'NOT DRIVEN' 'no machine-only extension key with values and one subkey on this machine'; return }
    $x = $script:MachName
    $script:GoUpFrom = 'reg:\HKEY_CLASSES_ROOT\' + $x
    $script:UserHadIt = Test-Path -LiteralPath ('HKCU:\Software\Classes\' + $x)
    if ($script:UserHadIt) { Row $Case 'RUN' 'NOT DRIVEN' ("the user's half holds '{0}' now" -f $x); $script:GoUpFrom = $null; return }
    $subName = @(Get-ChildItem -LiteralPath ('HKLM:\Software\Classes\' + $x))[0].PSChildName
    $want = 'HKEY_LOCAL_MACHINE\Software\Classes\' + $x + '\' + $subName
    Row-Op $Case 728 'reg:\HKEY_CLASSES_ROOT' $null $Target @(2) {
        param($r)
        $first = $(if ($r.Boxes.Count -ge 1) { $r.Boxes[0].Text } else { '' })
        $named = ($null -ne $first) -and $first.Contains($Removesrc.Trim()) -and $first.Contains($want)
        Row $Case 'TEXT' (V $named) ("key '{0}' (machine's half only); expected the first box '{1}' naming '{2}'; {3}" -f $x, (Esc $Removesrc), $want, (Box-Facts $r))
        $kept = $r.Mach0 -ceq $r.Mach1
        $copy = $r.User1 -ceq $r.Mach1
        Row $Case 'STATE' (V ($kept -and $copy -and $r.Unchanged)) ("machine's half unchanged: {0}; the user's copy equals it: {1} (user's half: '{2}'); fixture unchanged: {3}" -f $kept, $copy, (Esc $r.User1), $r.Unchanged)
    }
    $script:GoUpFrom = $null
    $script:UserHadIt = $true
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc390_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    $script:MachName = Pick-MachineOnly
    Out ("hkcr390_probe (feature 390), language: {0}" -f $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; elevated {3}; registry key existed {4}; export SHA-256 {5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $IsAdmin, $existed, $regHash)
    Out ("Machine : {0} = {1}" -f $script:MachName, $(if ($script:MachName) { Esc (Snap-Tree ('HKLM:\Software\Classes\' + $script:MachName)) } else { '-' }))
    Out ("Fixture : {0}" -f (Esc (Snapshot)))
    Out ''

    Mach-Row 'MACHUSER' '\HKEY_CURRENT_USER\Software\Classes\'
    Mach-Row 'MACHUSERU' ('\HKEY_USERS\' + $Sid + '_Classes\')
    $mn = $script:MachName; $script:MachName = $null
    Row-Op 'USERMOVE' 728 ('reg:\HKEY_CLASSES_ROOT\' + $RegName + '\Zdroj') $FocusK ('\HKEY_CURRENT_USER\Software\' + $RegName + '\Cil\') $null {
        param($r)
        $m = Moved-Into ($PlainPs + '\Cil')
        Row 'USERMOVE' 'STATE' (V ($m -and $r.Boxes.Count -eq 0)) ("moved whole, source gone: {0}; {1}; keys: {2}" -f $m, (Box-Facts $r), (Esc $r.Snap))
    }
    Row-Op 'USERHKCR' 728 ('reg:\HKEY_CLASSES_ROOT\' + $RegName + '\Zdroj') $FocusK ('\HKEY_CLASSES_ROOT\' + $RegName + '\Cil\') $null {
        param($r)
        $m = Moved-Into ($ClsPs + '\Cil')
        Row 'USERHKCR' 'STATE' (V ($m -and $r.Boxes.Count -eq 0)) ("moved whole into the user's half, source gone: {0}; {1}; keys: {2}" -f $m, (Box-Facts $r), (Esc $r.Snap))
    }
    $script:MachName = $mn
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($sp in @($Started)) { if (Test-Alive $sp) { Stop-Process -Id $sp -Force } }
    Start-Sleep -Milliseconds 600
    Remove-Fixture
    $userLeft = $false
    if ($script:MachName) { $userLeft = Test-Path -LiteralPath ('HKCU:\Software\Classes\' + $script:MachName) }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture keys removed: {4}; user copy of the machine key left: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, $leftover.Count, (-not ((Test-Path -LiteralPath $ClsPs) -or (Test-Path -LiteralPath $PlainPs))), $userLeft, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
