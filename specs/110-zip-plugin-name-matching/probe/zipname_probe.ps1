<#
.SYNOPSIS
    Feature 110 probe: the ZIP plug-in's name matching. A member is replaced, deleted, extracted
    or updated only when its name IS the name of the file the operation means - by the file
    system's rule for UTF-8 names (ordinal, case-insensitive), by the old rule for legacy text.

.DESCRIPTION
    Every case: an archive written by zipfix.py (own writer: UTF-8 names with bit 11, OEM names
    without it, raw non-UTF-8 bytes with it, FAT / Unix host), member i holding
    "content-of-member-<i>", source files holding "content-of-source-<tag>". One instance of
    -Exe per case, driven by window messages on the hidden desktop. Routes:
      copy  F5 (727) of everything in the left panel (a folder holding the source files) into
            the archive shown in the right panel (its root or a folder in it); every ZIP
            "Confirm File Overwrite" is counted, its two names recorded, and answered from the
            case's list (6 Yes, 173 Skip; Yes when the list is used up)
      move  the same with F6 (728); the source must then be gone from disk
      del   F8 (729) on one named member (found by F3: the viewer's title), Yes
      ext   F5 of one named member from the archive (left) to an empty folder (right)
      edit  F4 (743) on named members (the F4 editor is configured, inside the registry
            backup/restore, as cmd.exe /c echo edited110>>"$(FullName)"), leave the archive,
            Update, overwrite questions answered from the case's list
    The archive is read back by zipfix.py (own central-directory reader, CRC checked); a row
    PASSes when the FILE entries are exactly the expected set (name -> content tag [+ edits]),
    the expected folder entries exist, and - where given - the number of overwrite questions
    matches. The expectations are this feature's rule; the build before shows the losses.
    -Scratch <folder>: fixtures and the registry backup go there (default %TEMP%\tc110).
    MUST be started through tools\run_on_hidden_desktop.ps1. Refuses to run while another
    tandemcommander.exe is running. HKCU\Software\Tandem Commander exported before, restored
    and verified after. Pure ASCII; Windows PowerShell 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [string]$Scratch = ''   # scratch folder (default %TEMP%\tc110); fixtures in <Scratch>\zn, registry backup in <Scratch>\reg
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not $Scratch) { $Scratch = $TempRoot + '\tc110' }
$Scratch = [IO.Path]::GetFullPath($Scratch).TrimEnd('\')
$Root = $Scratch + '\zn'
$StartDir = $Root
$RegCfg = 'HKCU\Software\Tandem Commander\0.1'
$Marker = 'edited110'
$ZipFix = Join-Path $PSScriptRoot 'zipfix.py'
$script:Table = New-Object System.Collections.ArrayList

function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }

function Set-ProbeConfig {
    & cmd.exe /c "reg query `"$RegCfg\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    & reg.exe add "$RegCfg\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
    & reg.exe add "$RegCfg\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add "$RegCfg\Configuration\Confirmation" /v 'Close Archive' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add "$RegCfg\Plugins Configuration\ZIP" /v 'Show Extended Options' /t REG_DWORD /d 0 /f | Out-Null
    & cmd.exe /c "reg delete `"$RegCfg\Editors`" /f >nul 2>&1"
    $k = "$RegCfg\Editors\1"
    & reg.exe add $k /v 'Masks' /t REG_SZ /d '*.*' /f | Out-Null
    & reg.exe add $k /v 'Command' /t REG_SZ /d (Join-Path $env:SystemRoot 'System32\cmd.exe') /f | Out-Null
    Set-ItemProperty -LiteralPath ('Registry::' + $k.Replace('HKCU\', 'HKEY_CURRENT_USER\')) -Name 'Arguments' -Value ('/c echo ' + $Marker + '>>"$(FullName)"')
    & reg.exe add $k /v 'Initial Directory' /t REG_SZ /d (Join-Path $env:SystemRoot 'System32') /f | Out-Null
    return $true
}

function Invoke-ZipFix([string]$Verb, [string]$Arc, $Members, $Files) {
    $spec = Join-Path $Root 'spec.json'
    $m = @(); foreach ($x in @($Members)) { $m += (ConvertTo-Json $x -Compress) }
    $f = @(); foreach ($x in @($Files)) { $f += (ConvertTo-Json $x -Compress) }
    $json = '{"arc": ' + (ConvertTo-Json $Arc) + ', "members": [' + ($m -join ', ') + '], "files": [' + ($f -join ', ') + ']}'
    [IO.File]::WriteAllText($spec, $json, $Utf8)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    if ($Verb -eq 'make') { $o = & $Python $ZipFix make $spec 2>&1 } else { $o = & $Python $ZipFix read $spec $Marker 2>&1 }
    $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ("zipfix.py $Verb failed: " + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return @($o | ForEach-Object { "$_" })
}
function Tree([string]$Dir) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $ZipFix tree $Dir $Marker 2>&1; $ErrorActionPreference = $old
    return @($o | ForEach-Object { "$_" })
}

function Start-Two([string]$Left, [string]$Right) {
    $a = @('-t', 'T110', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2500
    return $p.Id
}
function Title([int]$Id) { return [Drv098f]::Txt((Get-Main $Id)) }
function Settle([int]$Id, [int]$Ms) {
    $m = Get-Main $Id; if ($m -eq [IntPtr]::Zero) { return }
    [void][Drv098f]::Send($m, 0, 0, 0, 20000); Start-Sleep -Milliseconds $Ms; [void][Drv098f]::Send($m, 0, 0, 0, 20000)
}
function PostKey([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv098f]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L)
}

# serves the windows of an operation; ZIP/core "Confirm File Overwrite" (has button 173) answered
# from $Answers in turn (Yes = 6 when used up), recorded with its two names; everything else
# OK / Yes / Update; a "temporary directories" question No
function Drive([int]$Id, [int[]]$Answers, [double]$Seconds = 60) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false; Q = 0; QText = New-Object System.Collections.ArrayList }
    $seen = @{}; $idleSince = $null; $packFailed = $false
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
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
            if ($ids -contains 173 -and $ids -contains 6) {
                $a = 6; if ($r.Q -lt $Answers.Count) { $a = $Answers[$r.Q] }
                $r.Q++
                $n1 = ''; $n2 = ''
                foreach ($c in [Drv098f]::Kids($h)) { $cid = [Drv098f]::GetDlgCtrlID($c); if ($cid -eq 181) { $n1 = [Drv098f]::Txt($c) } elseif ($cid -eq 183) { $n2 = [Drv098f]::Txt($c) } }
                $q = ("Q{0}: {1} -> {2}" -f $r.Q, (FullText $h), @{ 6 = 'Yes'; 185 = 'All'; 173 = 'Skip'; 174 = 'Skip All'; 2 = 'Cancel' }[$a])
                [void]$r.QText.Add($q); [void]$r.Messages.Add($q)
                $b = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $a } | Select-Object -First 1
                if ($b) { Click $b } else { Close-Win $h }
                Start-Sleep -Milliseconds 500; continue
            }
            $want = @(1, 6)
            if ($d -match 'temporary director') { $want = @(7) }
            elseif ($d -match 'Packing of updated file') { $want = @(7); $packFailed = $true }
            elseif ($packFailed -and [Drv098f]::Txt($h) -eq 'Archive Update') { $want = @(2) }
            [void]$r.Messages.Add($d)
            $pick = $btn | Where-Object { $want -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function DMsgs($r) { if ($r.Messages.Count) { return ((@($r.Messages | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) + '...' } else { $_ } })) -join ' || ') } else { return 'no window' } }

# F3 on panel position $k of the left panel: the viewer's title (then closed)
function View-Title([int]$Id, [int]$K) {
    Key $Id 0x24; for ($i = 0; $i -lt $K; $i++) { Key $Id 0x28 }
    Settle $Id 300
    $w = Open-ByCmd $Id 742 6
    if ($w -eq [IntPtr]::Zero) { return '' }
    Start-Sleep -Milliseconds 600
    $t = [Drv098f]::Txt($w)
    if ([Drv098f]::Cls($w) -eq '#32770') { Click-Ok $w; return ('<message> ' + $t) }
    [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 5 -and [Drv098f]::IsWindow($w)) { Start-Sleep -Milliseconds 100 }
    Start-Sleep -Milliseconds 300
    return $t
}
# the panel position (1..$Max) whose F3 title names $Name exactly (ordinal), or -1
$script:Seen = @()
function Find-Pos([int]$Id, [string]$Name, [int]$Max) {
    $script:Seen = @()
    for ($k = 1; $k -le $Max; $k++) {
        $t = View-Title $Id $k
        $script:Seen += (Esc $t)
        $leaf = $t.Substring($t.LastIndexOf('\') + 1)   # "<path>\<name> [Plain Text] - Code Viewer" or "<path>\<name> - Viewer"
        $cut = $leaf.IndexOf(' ['); if ($cut -lt 0) { $cut = $leaf.LastIndexOf(' - ') }; if ($cut -ge 0) { $leaf = $leaf.Substring(0, $cut) }
        if ([string]::Equals($leaf, $Name, [StringComparison]::Ordinal)) { return $k }
    }
    return -1
}
# Enter on the folder at panel position $k whose title then ends with $Name (ordinal); $true on success
function Enter-Folder([int]$Id, [string]$Name, [int]$Max) {
    $script:Seen = @()
    for ($k = 1; $k -le $Max; $k++) {
        $t0 = Title $Id
        Key $Id 0x24; for ($i = 0; $i -lt $k; $i++) { Key $Id 0x28 }
        PostKey $Id 0x0D; Start-Sleep -Milliseconds 1000
        [void](Drive $Id @() 15)
        $t = Title $Id
        $script:Seen += (Esc $t)
        if ($t -ne $t0) {
            if ($t.EndsWith('\' + $Name, [StringComparison]::Ordinal) -or [string]::Equals($t, $Name, [StringComparison]::Ordinal) -or $t.StartsWith($Name + ' ', [StringComparison]::Ordinal) -or $t.Contains('\' + $Name + ' ') -or $t.Contains(' - ' + $Name + ' - ')) { return $true }
            PostKey $Id 0x08; Start-Sleep -Milliseconds 1000; [void](Drive $Id @() 15)
        }
    }
    return $false
}

function Quit([int]$Id) {
    $notes = @()
    if (-not (Test-Alive $Id)) { return 'not running' }
    [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) { $d = WinDesc $h; if ($d -notmatch 'monitored handles') { $notes += ('at exit: ' + $d) }; $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
        Start-Sleep -Milliseconds 200
    }
    if (Test-Alive $Id) { Kill-Mine $Id; $notes += 'did not exit in 30 s - ended by the probe' }
    Start-Sleep -Milliseconds 500
    return ('exit ' + (ExitCodeOf $Id) + $(if ($notes.Count) { '; ' + ($notes -join ' || ') } else { '' }))
}

# compares the archive's read-back with the expectation. $Expect: ordered list of
# "name=tag" or "name=tag+edits" (file entries, exact set); $Dirs: folder entries that must exist
function Judge($Read, [string[]]$Expect, [string[]]$Dirs, [bool]$Edits) {
    $why = @()
    $files = @(); $dirsSeen = @()
    foreach ($l in $Read) {
        $m = [regex]::Match($l, '^ENTRY (.*) raw=(\S+) utf8=(\d) host=(\d+) kind=(\w+) tag=(\S+) markers=(\d+)$')
        if (-not $m.Success) { continue }
        if ($m.Groups[5].Value -eq 'dir') { $dirsSeen += $m.Groups[1].Value; continue }
        $n = $m.Groups[1].Value; if ($n -eq '<undecodable>') { $n = 'raw:' + $m.Groups[2].Value }
        $files += $(if ($Edits) { '{0}={1}+{2}' -f $n, $m.Groups[6].Value, $m.Groups[7].Value } else { '{0}={1}' -f $n, $m.Groups[6].Value })
    }
    $chk = @($Read | Where-Object { $_ -like 'CHECK *' })
    if (-not $chk.Count -or $chk[0] -ne 'CHECK ok') { $why += ('archive check: ' + ($chk -join ' ')) }
    $exp = @($Expect | ForEach-Object { $_ })
    foreach ($e in $exp) { if (@($files | Where-Object { [string]::Equals($_, $e, [StringComparison]::Ordinal) }).Count -ne 1) { $why += ('expected ' + $e) } }
    foreach ($f in $files) { if (@($exp | Where-Object { [string]::Equals($_, $f, [StringComparison]::Ordinal) }).Count -ne 1) { $why += ('unexpected ' + $f) } }
    foreach ($d in @($Dirs)) { if ($d -and @($dirsSeen | Where-Object { [string]::Equals($_, $d, [StringComparison]::Ordinal) }).Count -lt 1) { $why += ('folder entry missing ' + $d) } }
    return [pscustomobject]@{ Why = $why; Files = ($files -join ' '); Dirs = ($dirsSeen -join ' ') }
}

function Run-Case($c) {
    if (-not (Want $c.N)) { return }
    $dir = $Root + '\' + $c.N
    [void][IO.Directory]::CreateDirectory($dir)
    $arc = $dir + '\arc.zip'
    $src = $dir + '\src'; $out = $dir + '\out'
    [void][IO.Directory]::CreateDirectory($src); [void][IO.Directory]::CreateDirectory($out)
    $files = @(); foreach ($s in @($c.Src)) { if ($s) { $files += @{ path = ($src + '\' + $s.P.Replace('/', '\')); tag = $s.T } } }
    [void](Invoke-ZipFix 'make' $arc $c.Members $files)
    $tmpBefore = @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp'))
    $rep = Reports
    Out ''
    Out ("--- {0} [{1}] {2}" -f $c.N, $c.Route, $c.What)
    $row = [ordered]@{ Case = $c.N; Route = $c.Route; Verdict = 'NOT DRIVEN'; Q = '-'; Facts = ''; Why = '' }
    $id = 0
    try {
        $answers = @(); if ($c.Answers) { $answers = @($c.Answers) }
        switch ($c.Route) {
            { $_ -eq 'copy' -or $_ -eq 'move' } {
                $right = $arc; if ($c.Inside) { $right = $arc + '\' + $c.Inside }
                $id = Start-Two $src $right
                $r0 = Drive $id @() 6; if ($r0.Messages.Count) { Out ('   at start: ' + (DMsgs $r0)) }
                Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 600
                $dlg = Open-ByCmd $id $(if ($c.Route -eq 'move') { 728 } else { 727 })
                if ($dlg -eq [IntPtr]::Zero) { throw 'Copy/Move opened no window' }
                $t = [Drv098f]::GetText((Find-Ctl $dlg 210), 5000)
                Click-Ok $dlg; Start-Sleep -Milliseconds 400
                $r = Drive $id $answers 60
                Out ("   F5 target '{0}'; windows: {1}" -f (Tail $t 60), (DMsgs $r))
            }
            'del' {
                $id = Start-Two $arc $out
                [void](Drive $id @() 6)
                if ($c.Inside) { if (-not (Enter-Folder $id $c.Inside 4)) { throw ('folder ' + (Esc $c.Inside) + ' not entered; titles: ' + ($script:Seen -join ' | ')) } }
                $pos = Find-Pos $id $c.Target 4
                if ($pos -lt 0) { throw ('member ' + (Esc $c.Target) + ' not found in the panel; F3 titles: ' + ($script:Seen -join ' | ')) }
                Key $id 0x24; for ($i = 0; $i -lt $pos; $i++) { Key $id 0x28 }
                Settle $id 300
                Post-Cmd (Get-Main $id) 729; Start-Sleep -Milliseconds 400
                $r = Drive $id $answers 40
                Out ("   F8 on '{0}' (position {1}); windows: {2}" -f (Esc $c.Target), $pos, (DMsgs $r))
            }
            'ext' {
                $id = Start-Two $arc $out
                [void](Drive $id @() 6)
                $pos = Find-Pos $id $c.Target 4
                if ($pos -lt 0) { throw ('member ' + (Esc $c.Target) + ' not found in the panel; F3 titles: ' + ($script:Seen -join ' | ')) }
                Key $id 0x24; for ($i = 0; $i -lt $pos; $i++) { Key $id 0x28 }
                Settle $id 300
                $dlg = Open-ByCmd $id 727
                if ($dlg -eq [IntPtr]::Zero) { throw 'Copy (727) opened no window' }
                Click-Ok $dlg; Start-Sleep -Milliseconds 400
                $r = Drive $id $answers 40
                Out ("   F5 of '{0}' (position {1}) to out; windows: {2}" -f (Esc $c.Target), $pos, (DMsgs $r))
            }
            'edit' {
                $id = Start-Two $arc $out
                [void](Drive $id @() 6)
                $inFolder = ''
                $step = 0
                foreach ($e in @($c.Edits)) {
                    $step++
                    $f = ''; $n = $e
                    if ($e.Contains('/')) { $f = $e.Substring(0, $e.LastIndexOf('/')); $n = $e.Substring($e.LastIndexOf('/') + 1) }
                    if ($inFolder -ne $f) {
                        if ($inFolder) { PostKey $id 0x08; Start-Sleep -Milliseconds 1000; [void](Drive $id @() 15); $inFolder = '' }
                        if ($f) { if (-not (Enter-Folder $id $f 5)) { throw ('folder ' + (Esc $f) + ' not entered; titles: ' + ($script:Seen -join ' | ')) }; $inFolder = $f }
                    }
                    $pos = Find-Pos $id $n 5
                    if ($pos -lt 0) { throw ('member ' + (Esc $e) + ' not found in the panel; F3 titles: ' + ($script:Seen -join ' | ')) }
                    $sum0 = 0; foreach ($d in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp') | Where-Object { $tmpBefore -notcontains $_ })) { foreach ($x in [IO.Directory]::GetFiles($d, '*', 'AllDirectories')) { try { $sum0 += ([regex]::Matches([IO.File]::ReadAllText($x), $Marker)).Count } catch { } } }
                    Key $id 0x24; for ($i = 0; $i -lt $pos; $i++) { Key $id 0x28 }
                    Settle $id 600
                    Post-Cmd (Get-Main $id) 743
                    $sw = [Diagnostics.Stopwatch]::StartNew(); $done = $false
                    while ($sw.Elapsed.TotalSeconds -lt 10 -and -not $done) {
                        Start-Sleep -Milliseconds 300
                        $sum = 0; foreach ($d in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp') | Where-Object { $tmpBefore -notcontains $_ })) { foreach ($x in [IO.Directory]::GetFiles($d, '*', 'AllDirectories')) { try { $sum += ([regex]::Matches([IO.File]::ReadAllText($x), $Marker)).Count } catch { } } }
                        if ($sum -gt $sum0) { $done = $true }
                    }
                    Start-Sleep -Milliseconds 1200
                    $r = Drive $id @() 15
                    $copies = @(); foreach ($d in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp') | Where-Object { $tmpBefore -notcontains $_ })) { foreach ($x in [IO.Directory]::GetFiles($d, '*', 'AllDirectories')) { $copies += ([IO.Path]::GetFileName($d) + '\' + (Esc $x.Substring($d.Length + 1))) } }
                    Out ("   EDIT {0} '{1}' (position {2}): edited {3}; temporary copies: {4}; windows: {5}" -f $step, (Esc $e), $pos, $done, ($copies -join ', '), (DMsgs $r))
                }
                if ($inFolder) { PostKey $id 0x08; Start-Sleep -Milliseconds 1000; [void](Drive $id @() 15) }
                PostKey $id 0x08; Start-Sleep -Milliseconds 1000
                $r = Drive $id $answers 60
                Out ("   LEAVE: windows: {0}" -f (DMsgs $r))
            }
        }
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        if ($fatal) { throw ('FATAL ' + $fatal) }
        $q = $r.Q
        $ex = Quit $id
        $newRep = @((Reports) | Where-Object { $rep -notcontains $_ })
        foreach ($n in $newRep) { Remove-Item -LiteralPath (Join-Path $ReportDir $n) -Force -ErrorAction SilentlyContinue }
        $read = Invoke-ZipFix 'read' $arc $c.Members @()
        foreach ($l in $read) { Out ('          ' + $l) }
        $j = Judge $read $c.Expect $c.Dirs ($c.Route -eq 'edit')
        $why = @($j.Why)
        if ($c.Route -eq 'ext') {
            $t = Tree $out
            foreach ($l in $t) { Out ('          out: ' + $l) }
            $want = @($c.ExpectOut)
            $got = @($t | ForEach-Object { $_ -replace '^FILE (.*) tag=(\S+) markers=\d+$', '$1=$2' })
            foreach ($w in $want) { if (@($got | Where-Object { [string]::Equals($_, $w, [StringComparison]::Ordinal) }).Count -ne 1) { $why += ('out: expected ' + $w) } }
            foreach ($g in $got) { if (@($want | Where-Object { [string]::Equals($_, $g, [StringComparison]::Ordinal) }).Count -ne 1) { $why += ('out: unexpected ' + $g) } }
        }
        if ($c.Route -eq 'move') {   # the moved source: stored above, so it must be gone from disk
            $leftSrc = @([IO.Directory]::GetFiles($src, '*', 'AllDirectories'))
            Out ('          source folder after the Move: ' + $(if ($leftSrc.Count) { ($leftSrc | ForEach-Object { Esc ([IO.Path]::GetFileName($_)) }) -join ', ' } else { 'empty' }))
            if ($leftSrc.Count) { $why += 'source not deleted by the Move' }
        }
        if ($null -ne $c.Q -and $q -ne $c.Q) { $why += ("{0} overwrite question(s), expected {1}" -f $q, $c.Q) }
        if ($r.TimedOut) { $why += 'timed out' }
        if ($newRep.Count) { $why += "$($newRep.Count) crash report(s)" }
        if ($ex -notmatch '^exit 0x00000000') { $why += $ex }
        $row.Verdict = $(if ($why.Count) { 'FAIL' } else { 'PASS' })
        $row.Q = $q
        $row.Facts = $j.Files + $(if ($j.Dirs) { ' | dirs ' + $j.Dirs } else { '' })
        $row.Why = ($why -join '; ')
        Out ("   END: {0}; questions {1}: {2}" -f $ex, $q, (($r.QText) -join ' / '))
        Out ("   VERDICT: {0} {1}" -f $row.Verdict, $row.Why)
    }
    catch {
        Out ('   exception: ' + $_.Exception.Message); $row.Why = 'NOT DRIVEN: ' + $_.Exception.Message
    }
    finally {
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        Start-Sleep -Milliseconds 300
        foreach ($t in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp') | Where-Object { $tmpBefore -notcontains $_ })) {
            Out ("   left in the temp folder by the test instance, removed: {0}" -f [IO.Path]::GetFileName($t))
            try { [IO.Directory]::Delete($t, $true) } catch { }
        }
        [void]$script:Table.Add([pscustomobject]$row)
    }
}

# ---- main ---------------------------------------------------------------------
$backupDir = $Scratch + '\reg'
[void][IO.Directory]::CreateDirectory($backupDir)
$backup = Join-Path $backupDir 'backup.reg'
$existed = Backup-Reg $backup
$restored = $false
try {
    if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $cfg = Set-ProbeConfig
    Out ("zipname_probe (feature 110) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; OEM {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), (& $Python -c 'import ctypes;print(ctypes.windll.kernel32.GetOEMCP())'))
    if (-not $cfg) { throw 'no stored configuration - the probe cannot configure the program' }
    $hc = S 0x125; $Lu = S 0x139                     # h-circumflex / L-acute: C4 A5 / C4 B9 (old: one name)
    $Ia = S 0xCD; $Ya = S 0xDD                       # I-acute / Y-acute (Czech)
    $zc = S 0x17E; $zd = S 0x17C                     # z-caron / z-dot
    $nine = S 0x4E5D; $zha = S 0x4E4D                # CJK
    $em = S 0x43C; $oo = S 0x43E                     # Cyrillic em / o
    $CcU = S 0x10C; $CcL = S 0x10D                   # C-caron / c-caron (case pair)
    $AbU = S 0x23A; $AbL = S 0x2C65                  # A-stroke 2 bytes / a-stroke 3 bytes (case pair)
    $eNfc = S 0xE9; $eNfd = 'e' + (S 0x301)
    $sl = 'slo' + $zc + 'ka'
    $x1 = $CcL + 'x'; $x2 = $CcU + 'x'; $x3 = $CcU + 'X'   # c-caron-x / C-caron-x / C-caron-X: one name for Windows
    function M([string]$n) { return @{ name = $n } }
    function MO([string]$n) { return @{ name = $n; enc = 'oem' } }
    function MU([string]$n) { return @{ name = $n; host = 'unix' } }
    function SR([string]$p, [string]$t = 'S1') { return @{ P = $p; T = $t } }
    $cases = @(
        # ---- copy (F5 into the archive): pairs the old comparison took for one name
        @{ N = 'c_hL'; Route = 'copy'; What = "F5 h-circ.txt into {L-acute.txt}"; Members = @((M "$Lu.txt")); Src = @((SR "$hc.txt")); Q = 0; Expect = @("\u0139.txt=m1", "\u0125.txt=sS1") },
        @{ N = 'c_hLboth'; Route = 'copy'; What = "F5 h-circ.txt into {h-circ.txt, L-acute.txt}"; Members = @((M "$hc.txt"), (M "$Lu.txt")); Src = @((SR "$hc.txt")); Q = 1; Expect = @("\u0125.txt=sS1", "\u0139.txt=m2") },
        @{ N = 'c_hLskip'; Route = 'copy'; What = "as c_hLboth, the overwrite questions answered Yes, then Skip"; Members = @((M "$hc.txt"), (M "$Lu.txt")); Src = @((SR "$hc.txt")); Answers = @(6, 173); Q = 1; Expect = @("\u0125.txt=sS1", "\u0139.txt=m2") },
        @{ N = 'c_IY'; Route = 'copy'; What = "F5 I-acute-tem.txt into {Y-acute-tem.txt}"; Members = @((M "${Ya}tem.txt")); Src = @((SR "${Ia}tem.txt")); Q = 0; Expect = @("\u00DDtem.txt=m1", "\u00CDtem.txt=sS1") },
        @{ N = 'c_zz'; Route = 'copy'; What = "F5 z-caron.txt into {z-dot.txt}"; Members = @((M "$zd.txt")); Src = @((SR "$zc.txt")); Q = 0; Expect = @("\u017C.txt=m1", "\u017E.txt=sS1") },
        @{ N = 'c_cjk'; Route = 'copy'; What = "F5 U+4E5D.txt into {U+4E4D.txt}"; Members = @((M "$zha.txt")); Src = @((SR "$nine.txt")); Q = 0; Expect = @("\u4E4D.txt=m1", "\u4E5D.txt=sS1") },
        @{ N = 'c_cyr'; Route = 'copy'; What = "F5 em.txt into {o.txt} (Cyrillic)"; Members = @((M "$oo.txt")); Src = @((SR "$em.txt")); Q = 0; Expect = @("\u043E.txt=m1", "\u043C.txt=sS1") },
        @{ N = 'c_sub'; Route = 'copy'; What = "F5 of folder d (holding h-circ.txt) into {d/L-acute.txt}"; Members = @((M "d/$Lu.txt")); Src = @((SR "d/$hc.txt")); Q = 0; Expect = @("d/\u0139.txt=m1", "d/\u0125.txt=sS1") },
        @{ N = 'c_inside'; Route = 'copy'; What = "F5 h-circ.txt into the archive folder slozka holding L-acute.txt"; Members = @((M "$sl/$Lu.txt")); Src = @((SR "$hc.txt")); Inside = $sl; Q = 0; Expect = @("slo\u017Eka/\u0139.txt=m1", "slo\u017Eka/\u0125.txt=sS1") },
        @{ N = 'c_unixhL'; Route = 'copy'; What = "F5 h-circ.txt into a Unix ZIP {L-acute.txt}"; Members = @((MU "$Lu.txt")); Src = @((SR "$hc.txt")); Q = 0; Expect = @("\u0139.txt=m1", "\u0125.txt=sS1") },
        @{ N = 'c_oemhL'; Route = 'copy'; What = "F5 h-circ.txt into an OEM-named ZIP {L-acute.txt}"; Members = @((MO "$Lu.txt")); Src = @((SR "$hc.txt")); Q = 0; Expect = @("\u0139.txt=m1", "\u0125.txt=sS1") },
        @{ N = 'c_merged'; Route = 'copy'; What = "F5 x.txt into folder h-circ of {h-circ/a.txt, L-acute/x.txt} (the core's listing merges the two folders)"; Members = @((M "$hc/a.txt"), (M "$Lu/x.txt")); Src = @((SR 'x.txt')); Inside = $hc; Q = 0; Expect = @("\u0125/a.txt=m1", "\u0139/x.txt=m2", "\u0125/x.txt=sS1") },
        # ---- copy: names that ARE one name for Windows
        @{ N = 'c_Cc'; Route = 'copy'; What = "F5 c-caron.txt into {C-caron.txt} (case pair outside ASCII)"; Members = @((M "$CcU.txt")); Src = @((SR "$CcL.txt")); Q = 1; Expect = @("\u010D.txt=sS1") },
        @{ N = 'c_len'; Route = 'copy'; What = "F5 a-stroke.txt (3 bytes) into {A-stroke.txt} (2 bytes)"; Members = @((M "$AbU.txt")); Src = @((SR "$AbL.txt")); Q = 1; Expect = @("\u2C65.txt=sS1") },
        @{ N = 'c_oemCc'; Route = 'copy'; What = "F5 c-caron.txt into an OEM-named ZIP {C-caron.txt}"; Members = @((MO "$CcU.txt")); Src = @((SR "$CcL.txt")); Q = 1; Expect = @("\u010D.txt=sS1") },
        # ---- copy: unchanged behaviour
        @{ N = 'c_Aa'; Route = 'copy'; What = "F5 a.txt into {A.txt} (ASCII case)"; Members = @((M 'A.txt')); Src = @((SR 'a.txt')); Q = 1; Expect = @("a.txt=sS1") },
        @{ N = 'c_same'; Route = 'copy'; What = "F5 x.txt into {x.txt, y.txt}"; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt')); Q = 1; Expect = @("x.txt=sS1", "y.txt=m2") },
        @{ N = 'c_skip'; Route = 'copy'; What = "F5 x.txt into {x.txt}, Skip"; Members = @((M 'x.txt')); Src = @((SR 'x.txt')); Answers = @(173); Q = 1; Expect = @("x.txt=m1") },
        @{ N = 'c_Cc2'; Route = 'copy'; What = "F5 c-caron.txt into {c-caron.txt}"; Members = @((M "$CcL.txt")); Src = @((SR "$CcL.txt")); Q = 1; Expect = @("\u010D.txt=sS1") },
        @{ N = 'c_nfc'; Route = 'copy'; What = "F5 e-acute (NFC).txt into {e + combining acute (NFD).txt}"; Members = @((M "$eNfd.txt")); Src = @((SR "$eNfc.txt")); Q = 0; Expect = @("e\u0301.txt=m1", "\u00E9.txt=sS1") },
        @{ N = 'c_oem'; Route = 'copy'; What = "F5 c-caron.txt into an OEM-named ZIP {c-caron.txt}"; Members = @((MO "$CcL.txt")); Src = @((SR "$CcL.txt")); Q = 1; Expect = @("\u010D.txt=sS1") },
        @{ N = 'c_raw'; Route = 'copy'; What = "F5 c-caron.txt into a ZIP whose member is the CP1250 byte of c-caron flagged UTF-8 (not UTF-8)"; Members = @(@{ name = 'x'; enc = 'raw'; raw = 'e82e747874' }); Src = @((SR "$CcL.txt")); Q = 0; Expect = @("raw:e82e747874=m1", "\u010D.txt=sS1") },
        @{ N = 'c_unixAa'; Route = 'copy'; What = "F5 a.txt into a Unix ZIP {A.txt} (the added file takes the member's spelling)"; Members = @((MU 'A.txt')); Src = @((SR 'a.txt')); Q = 1; Expect = @("A.txt=sS1") },
        @{ N = 'c_unixlen'; Route = 'copy'; What = "F5 A-stroke.txt (2 bytes) into a Unix ZIP {a-stroke.txt} (3 bytes): the added file takes the member's longer spelling"; Members = @((MU "$AbL.txt")); Src = @((SR "$AbU.txt")); Q = 1; Expect = @("\u2C65.txt=sS1") },
        # ---- review SF1: several members one name with the added file, mixed answers - a member is
        #      deleted only if the added file replacing it is stored (members m1 cx, m2 Cx, m3 CX);
        #      a second, unrelated file (other.txt) keeps the operation from being "nothing to do"
        #      (with nothing left to add the plug-in skips the deletions too)
        @{ N = 'r_3ys'; Route = 'copy'; What = "F5 c-caron-x.txt into {c-caron-x, C-caron-x, C-caron-X}.txt, Yes / Skip / Skip"; Members = @((M "$x1.txt"), (M "$x2.txt"), (M "$x3.txt")); Src = @((SR "$x1.txt"), (SR 'other.txt' 'S2')); Answers = @(6, 173, 173); Q = 3; Expect = @("$x2.txt=m2", "$x3.txt=m3", "$x1.txt=sS1", 'other.txt=sS2') },
        @{ N = 'r_3ysA'; Route = 'copy'; What = "F5 ax.txt into {ax, Ax, AX}.txt (ASCII), Yes / Skip / Skip"; Members = @((M 'ax.txt'), (M 'Ax.txt'), (M 'AX.txt')); Src = @((SR 'ax.txt'), (SR 'other.txt' 'S2')); Answers = @(6, 173, 173); Q = 3; Expect = @('Ax.txt=m2', 'AX.txt=m3', 'ax.txt=sS1', 'other.txt=sS2') },
        @{ N = 'r_3ysy'; Route = 'copy'; What = "as r_3ys, Yes / Skip / Yes"; Members = @((M "$x1.txt"), (M "$x2.txt"), (M "$x3.txt")); Src = @((SR "$x1.txt"), (SR 'other.txt' 'S2')); Answers = @(6, 173, 6); Q = 3; Expect = @("$x2.txt=m2", "$x1.txt=sS1", 'other.txt=sS2') },
        @{ N = 'r_3yyy'; Route = 'copy'; What = "as r_3ys, Yes / Yes / Yes"; Members = @((M "$x1.txt"), (M "$x2.txt"), (M "$x3.txt")); Src = @((SR "$x1.txt"), (SR 'other.txt' 'S2')); Answers = @(6, 6, 6); Q = 3; Expect = @("$x1.txt=sS1", 'other.txt=sS2') },
        @{ N = 'r_3all'; Route = 'copy'; What = "as r_3ys, All"; Members = @((M "$x1.txt"), (M "$x2.txt"), (M "$x3.txt")); Src = @((SR "$x1.txt"), (SR 'other.txt' 'S2')); Answers = @(185); Q = 1; Expect = @("$x1.txt=sS1", 'other.txt=sS2') },
        @{ N = 'r_3s'; Route = 'copy'; What = "as r_3ys, Skip"; Members = @((M "$x1.txt"), (M "$x2.txt"), (M "$x3.txt")); Src = @((SR "$x1.txt"), (SR 'other.txt' 'S2')); Answers = @(173); Q = 1; Expect = @("$x1.txt=m1", "$x2.txt=m2", "$x3.txt=m3", 'other.txt=sS2') },
        @{ N = 'r_3sa'; Route = 'copy'; What = "as r_3ys, Skip All"; Members = @((M "$x1.txt"), (M "$x2.txt"), (M "$x3.txt")); Src = @((SR "$x1.txt"), (SR 'other.txt' 'S2')); Answers = @(174); Q = 1; Expect = @("$x1.txt=m1", "$x2.txt=m2", "$x3.txt=m3", 'other.txt=sS2') },
        @{ N = 'r_3yskipall'; Route = 'copy'; What = "as r_3ys, Yes / Skip All (case folder names must differ on NTFS by more than case)"; Members = @((M "$x1.txt"), (M "$x2.txt"), (M "$x3.txt")); Src = @((SR "$x1.txt"), (SR 'other.txt' 'S2')); Answers = @(6, 174); Q = 2; Expect = @("$x2.txt=m2", "$x3.txt=m3", "$x1.txt=sS1", 'other.txt=sS2') },
        @{ N = 'r_3yc'; Route = 'copy'; What = "as r_3ys, Yes / Cancel"; Members = @((M "$x1.txt"), (M "$x2.txt"), (M "$x3.txt")); Src = @((SR "$x1.txt"), (SR 'other.txt' 'S2')); Answers = @(6, 2); Q = 2; Expect = @("$x1.txt=m1", "$x2.txt=m2", "$x3.txt=m3") },
        @{ N = 'r_3ysAU'; Route = 'copy'; What = "F5 ax.txt into a Unix ZIP {ax, Ax, AX}.txt, Skip / Yes (Unix asks again after a Skip)"; Members = @((MU 'ax.txt'), (MU 'Ax.txt'), (MU 'AX.txt')); Src = @((SR 'ax.txt'), (SR 'other.txt' 'S2')); Answers = @(173, 6); Q = 2; Expect = @('ax.txt=m1', 'Ax.txt=sS1', 'AX.txt=m3', 'other.txt=sS2') },
        @{ N = 'r_3ysAM'; Route = 'move'; What = "F6 (Move) ax.txt into {ax, Ax, AX}.txt, Yes / Skip / Skip: the source is stored, then deleted"; Members = @((M 'ax.txt'), (M 'Ax.txt'), (M 'AX.txt')); Src = @((SR 'ax.txt'), (SR 'other.txt' 'S2')); Answers = @(6, 173, 173); Q = 3; Expect = @('Ax.txt=m2', 'AX.txt=m3', 'ax.txt=sS1', 'other.txt=sS2') },
        # ---- delete / extract
        @{ N = 'd_hL'; Route = 'del'; What = "F8 on h-circ.txt in {h-circ.txt, L-acute.txt}"; Members = @((M "$hc.txt"), (M "$Lu.txt")); Target = "$hc.txt"; Expect = @("\u0139.txt=m2") },
        @{ N = 'd_unixDir'; Route = 'del'; What = "Unix ZIP {Dir/a.txt, DIR/b.txt}: in Dir, F8 on a.txt - Dir stays as an empty folder"; Members = @((MU 'Dir/a.txt'), (MU 'DIR/b.txt')); Inside = 'Dir'; Target = 'a.txt'; Expect = @("DIR/b.txt=m2"); Dirs = @('Dir/') },
        @{ N = 'e_hL'; Route = 'ext'; What = "F5 of h-circ.txt from {h-circ.txt, L-acute.txt} to an empty folder"; Members = @((M "$hc.txt"), (M "$Lu.txt")); Target = "$hc.txt"; Expect = @("\u0125.txt=m1", "\u0139.txt=m2"); ExpectOut = @("\u0125.txt=m1") },
        # ---- F4 edit, pack back
        @{ N = 'f_hL1'; Route = 'edit'; What = "edit h-circ.txt of {h-circ.txt, L-acute.txt}"; Members = @((M "$hc.txt"), (M "$Lu.txt")); Edits = @("$hc.txt"); Expect = @("\u0125.txt=m1+1", "\u0139.txt=m2+0") },
        @{ N = 'f_hL2'; Route = 'edit'; What = "edit L-acute.txt of {h-circ.txt, L-acute.txt}"; Members = @((M "$hc.txt"), (M "$Lu.txt")); Edits = @("$Lu.txt"); Expect = @("\u0125.txt=m1+0", "\u0139.txt=m2+1") },
        @{ N = 'f_split'; Route = 'edit'; What = "edit d/L-acute.txt, then h-circ.txt, then L-acute.txt (108 review row split_zip)"; Members = @((M "d/$Lu.txt"), (M "$hc.txt"), (M "$Lu.txt")); Edits = @("d/$Lu.txt", "$hc.txt", "$Lu.txt"); Expect = @("d/\u0139.txt=m1+1", "\u0125.txt=m2+1", "\u0139.txt=m3+1") },
        @{ N = 'f_skip'; Route = 'edit'; What = "edit both of {h-circ.txt, L-acute.txt}, overwrite questions Yes, then Skip"; Members = @((M "$hc.txt"), (M "$Lu.txt")); Edits = @("$hc.txt", "$Lu.txt"); Answers = @(6, 173); Expect = @("\u0125.txt=m1+1", "\u0139.txt=m2+0") }
    )
    foreach ($c in $cases) {
        $c.Expect = @($c.Expect | ForEach-Object { [regex]::Unescape($_) | ForEach-Object { Esc $_ } })
        if ($c.ExpectOut) { $c.ExpectOut = @($c.ExpectOut | ForEach-Object { Esc ([regex]::Unescape($_)) }) }
        Run-Case $c
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 500
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    if ($restored -and (Test-Path -LiteralPath $backupDir)) { Remove-Item -LiteralPath $backupDir -Recurse -Force }
    try { if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) } } catch { Out ("Fixture : could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    Out ''
    Out '=== summary ==='
    foreach ($t in $script:Table) { Out ('{0,-11} {1,-5} {2,-10} Q={3} {4}{5}' -f $t.Case, $t.Route, $t.Verdict, $t.Q, $t.Facts, $(if ($t.Why) { ' | ' + $t.Why } else { '' })) }
    $np = @($script:Table | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Table | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Table | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ("TOTAL: {0} PASS / {1} FAIL / {2} NOT DRIVEN" -f $np, $nf, $nn)
    Out ("Left running: {0}; fixture removed: {1}; registry restored+identical: {2}" -f $leftover.Count, (-not [IO.Directory]::Exists($Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit 0
