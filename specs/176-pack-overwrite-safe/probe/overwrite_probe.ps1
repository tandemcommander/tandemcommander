<#
.SYNOPSIS
    Feature 176 probe: Pack with "Overwrite" into an existing archive never loses that archive -
    when the pack fails or is cancelled, the old archive is still there; when it succeeds, the
    new archive is in its place and nothing else is left.

.DESCRIPTION
    Built on the feature 119 probe (packleft_probe.ps1): its helpers (Drive, Run-Case, Pack-Dlg,
    Arc-Content with 7z.exe) are kept, its cases replaced. Every case: the left panel on the
    case's folder P, everything in P selected (842), the core's Pack dialog (850) into out\k.*
    that exists and holds old.bin, the core's "already exists - Add or Overwrite?" -> Overwrite.
      O-fail-zip    ZIP, z9.bin held open by this script (cannot be read), the error -> Cancel:
                    out\k.zip must still hold old.bin (before: deleted by the core first)
      O-fail-7z     the same with the 7-Zip packer into out\k.7z
      O-fail-move   as O-fail-zip with Move: no source deleted, the old archive kept
      O-move-late-7z  7-Zip Move, z9.bin readable but not deletable: the plug-in packs, cannot
                    delete it, Cancel - the new archive holds the moved files and must stay; the
                    old one is kept as arc*.tmp (review of 176: a first version deleted the new one)
      O-ok-zip      no lock: out\k.zip holds the new files only; no other file left in out\
      O-ok-multi    multi-volume (4 KB) Overwrite (119's K-exist-over): the set created, its last
                    volume renamed to k.zip
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported/restored/verified.
    Pure ASCII. Exit code = number of FAIL rows (0 with -Expect before).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

# code review SF3: never on the user's desktop (the maintainer works on it) - only through
# tools\run_on_hidden_desktop.ps1
if (-not ('Desk119' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Desk119
{
    [DllImport("user32.dll")] public static extern IntPtr GetThreadDesktop(uint threadId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool GetUserObjectInformationW(IntPtr h, int index, StringBuilder info, int length, out int needed);
    public static string Name()
    {
        var sb = new StringBuilder(256); int needed;
        if (!GetUserObjectInformationW(GetThreadDesktop(GetCurrentThreadId()), 2, sb, sb.Capacity * 2, out needed)) return "";
        return sb.ToString();
    }
}
'@
}
$deskName = [Desk119]::Name()
# the same opt-out as fix_probe_lib.ps1, for a run the maintainer allowed on the visible desktop
if ($env:TC_PROBE_ALLOW_VISIBLE_DESKTOP -ne '1' -and (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon')) { Write-Output ("NOT RUN: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Drv106' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Drv106
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendSb(IntPtr h, uint msg, IntPtr w, StringBuilder l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendI(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern uint GetShortPathNameW(string l, StringBuilder s, uint n);
    public static string[] ComboItems(IntPtr cb, uint timeout)
    {
        IntPtr r; SendI(cb, 0x0146, IntPtr.Zero, IntPtr.Zero, 0, timeout, out r); // CB_GETCOUNT
        int n = (int)r.ToInt64(); if (n < 0) n = 0;
        var a = new string[n];
        for (int i = 0; i < n; i++) { var sb = new StringBuilder(1024); IntPtr q; SendSb(cb, 0x0148, (IntPtr)i, sb, 0, timeout, out q); a[i] = sb.ToString(); }
        return a;
    }
    public static string Short(string p) { var sb = new StringBuilder(1024); uint n = GetShortPathNameW(p, sb, 1024); return n == 0 ? "" : sb.ToString(); }
}
'@
}

$Root = $TempRoot + '\tc176\pk'
# Czech (CP1250) pieces of names: r-caron, i-acute, s-caron, z-caron, t-caron, c-caron
$CzA = 'p' + [char]0x0159 + [char]0x00ED + 'li' + [char]0x0161
$CzB = [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k'
$script:LockStreams = New-Object System.Collections.ArrayList
# held by this script while the operation runs: opened for writing with FileShare ReadWrite+Delete -
# the ZIP plug-in opens a source with FILE_SHARE_READ only, so it "cannot open" it
function Lock-Source([string]$Path) {
    $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    [void]$script:LockStreams.Add([IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, $share))
}
function Release-Locks {
    foreach ($fs in @($script:LockStreams)) { try { $fs.Dispose() } catch { } }
    $script:LockStreams.Clear()
}
# names in $Dir matching the wildcard $Like that were not there before (the run's $Before list)
function New-Names([string]$Dir, [string]$Like, $Before) {
    if (-not [IO.Directory]::Exists($Dir)) { return @() }
    return @([IO.Directory]::GetFiles($Dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { $_ -like $Like -and @($Before) -notcontains $_ } | Sort-Object)
}
$StartDir = $Root + '\start'
$RegCfg = 'HKCU\Software\Tandem Commander\Settings'

function Rand-File([string]$p, [int]$size, [int]$seed) {
    $b = New-Object byte[] $size; (New-Object Random($seed)).NextBytes($b); [IO.File]::WriteAllBytes($p, $b)
}
function Sha([string]$p) { if (-not [IO.File]::Exists($p)) { return '' }; return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash }
function Unc([string]$p) { return '\\localhost\' + $p.Substring(0, 1) + '$' + $p.Substring(2) }
function SevenZ([string[]]$a) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $SevenZip @a 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = @($o | ForEach-Object { "$_" }) }
}
function Disk-Names([string]$Dir) {
    if (-not [IO.Directory]::Exists($Dir)) { return '(gone)' }
    return ((@([IO.Directory]::GetFileSystemEntries($Dir) | ForEach-Object { [IO.Path]::GetFileName($_) }) | Sort-Object) -join ', ')
}
# extracts $Arc into a fresh folder; returns @{ Ok; Files (name -> sha); Note }
function Arc-Content([string]$Arc) {
    $r = @{ Ok = $false; Files = @{}; Note = '' }
    if (-not [IO.File]::Exists($Arc)) { $r.Note = 'no archive'; return $r }
    $x = $Root + '\_x'; if ([IO.Directory]::Exists($x)) { [IO.Directory]::Delete($x, $true) }; [void][IO.Directory]::CreateDirectory($x)
    $t = SevenZ @('x', '-y', '-p-', ('-o' + $x), $Arc)
    $r.Ok = ($t.Rc -eq 0)
    if (-not $r.Ok) { $r.Note = 'extract rc ' + $t.Rc + ': ' + ((@($t.Text | Where-Object { $_ -match 'ERROR|Error|error|Can not|Headers|Unexpected|Is not' }) | Select-Object -First 3) -join ' / ') }
    foreach ($f in [IO.Directory]::GetFiles($x, '*', 'AllDirectories')) { $r.Files[[IO.Path]::GetFileName($f)] = (Sha $f) }
    [IO.Directory]::Delete($x, $true)
    return $r
}

function Set-ProbeConfig {
    & reg.exe add "$RegCfg\Plugins Configuration\ZIP" /v 'Show Extended Options' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add "$RegCfg\Plugins Configuration\ZIP" /v 'Winzip Names' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add "$RegCfg\Plugins Configuration\ZIP" /v 'Backup ZIP' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add "$RegCfg\Plugins Configuration\7zip" /v 'Show Extended Options' /t REG_DWORD /d 1 /f | Out-Null
    & reg.exe add "$RegCfg\Configuration\Confirmation" /v 'Add To Archive' /t REG_DWORD /d 1 /f | Out-Null
}
function Set-BackupZip([int]$v) { & reg.exe add "$RegCfg\Plugins Configuration\ZIP" /v 'Backup ZIP' /t REG_DWORD /d $v /f | Out-Null }
function Set-AskAdd([int]$v) { & reg.exe add "$RegCfg\Configuration\Confirmation" /v 'Add To Archive' /t REG_DWORD /d $v /f | Out-Null }

function Has-Ctl([IntPtr]$H, [int]$Id) { return (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $Id }).Count -gt 0) }
function Ctl([IntPtr]$H, [int]$Id) { return (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $Id }) | Select-Object -First 1) }

# serves the windows of an operation. $Answer: 'add' / 'over' for the core's "already exists"
# question; $Vol: KB volume size for the ZIP options (0 = no multi-volume); $Prefer: button ids
# tried in order for every other window (none matching -> closed = Cancel)
function Drive([int]$Id, [string]$Answer, [int]$Vol, [int[]]$Prefer, [double]$Seconds = 90) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false; PackAgain = 0; Asked = 0; OverwriteQ = 0; ErrorQ = 0 }
    $seen = @{}; $idleSince = $null
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
            $title = [Drv098f]::Txt($h)
            if (Has-Ctl $h 511) {   # the core's Pack dialog again (after a refusal)
                $r.PackAgain++; [void]$r.Messages.Add('[Pack dialog shown again -> Cancel]'); Close-Win $h; Start-Sleep -Milliseconds 400; continue
            }
            if ((Has-Ctl $h 102) -and (Has-Ctl $h 111)) {   # ZIP Extended Pack Options
                $note = '[ZIP options'
                if ($Vol -gt 0) {
                    $mv = Ctl $h 102
                    [void][Drv098f]::Send($mv, 0x00F1, 1, 0, 5000)                                  # BM_SETCHECK
                    [void][Drv098f]::Send($h, 0x0111, 102, $mv.ToInt64(), 5000)                     # BN_CLICKED
                    $vs = Ctl $h 103; [void][Drv098f]::SetText($vs, ('' + $Vol), 5000)
                    $un = Ctl $h 111; [void][Drv098f]::Send($un, 0x014E, 0, 0, 5000)                 # CB_SETCURSEL KB
                    $note += (': multi-volume ' + $Vol + ' KB, name shown ' + (Esc ([Drv098f]::Txt((Ctl $h 101)))))
                }
                [void]$r.Messages.Add($note + ' -> OK]')
                Click-Ok $h; Start-Sleep -Milliseconds 500; continue
            }
            if ($title -match '^(Create New Archive|Add Files [Tt]o Archive)$') { [void]$r.Messages.Add('[' + $title + ' options -> OK]'); Click-Ok $h; Start-Sleep -Milliseconds 500; continue }
            $text = FullText $h
            if ($text -match 'already exists' -and $ids -contains 6 -and $ids -contains 7) {
                $r.Asked++
                $pick = if ($Answer -like 'over*') { 7 } elseif ($Answer -eq 'add') { 6 } else { 2 }
                if ($Answer -eq 'over+noask') {   # tick "Add into archive without asking next time" first
                    $na = Ctl $h 2478; [void][Drv098f]::Send($na, 0x00F1, 1, 0, 5000); [void][Drv098f]::Send($h, 0x0111, 2478, $na.ToInt64(), 5000)
                }
                [void]$r.Messages.Add($d + (' -> ' + @{ 6 = 'Add'; 7 = 'Overwrite'; 2 = 'Cancel' }[$pick]))
                $b = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $pick } | Select-Object -First 1
                if ($b) { Click $b } else { Close-Win $h }
                Start-Sleep -Milliseconds 500; continue
            }
            if ($ids -contains 138) { $r.OverwriteQ++ }   # the ZIP plug-in's "Confirm File Overwrite"
            if ($ids -contains 4) { $r.ErrorQ++ }         # an error box with Retry (cannot open a source)
            $pick = $null
            foreach ($p in $Prefer) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $p } | Select-Object -First 1; if ($pick) { break } }
            if ($pick) { [void]$r.Messages.Add($d + ' -> ' + [Drv098f]::GetDlgCtrlID($pick)); Click $pick } else { [void]$r.Messages.Add($d + ' -> closed'); Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}

# one case: $Files = ordered list of @{ N = name; S = size } created in P (all selected);
# $Pre: scriptblock run after the files exist (e.g. make an archive); $Do: scriptblock($id) that
# starts the route and returns the Drive result; $Arc: the final archive path to read;
# $Expect: scriptblock($res) -> @($ok, 'expectation text')
# feature 119: $Locks - names in P held open by this script during the run (released before the
# checks); $Consumed - names in out\ this operation may change or delete (a volume the user agreed
# to overwrite). $res.NewP / $res.NewO - names created in P / out\ and left behind.
function Run-Case([string]$Case, [object[]]$Files, [scriptblock]$Pre, [scriptblock]$Do, [string]$Arc, [scriptblock]$Expect, [string]$What, [string[]]$Locks = @(), [string[]]$Consumed = @()) {
    if (-not (Want $Case)) { return }
    $script:P = $Root + '\' + $Case + '\packfolder_long'
    $script:O = $Root + '\' + $Case + '\out'
    NewDir $P; NewDir $O
    $seed = 1000
    foreach ($f in $Files) { $seed++; Rand-File ($P + '\' + $f.N) $f.S $seed }
    if ($Pre) { & $Pre }
    $before = @{}; foreach ($n in [IO.Directory]::GetFiles($P, '*', 'AllDirectories')) { $before[$n.Substring($P.Length + 1)] = Sha $n }
    $otherBefore = @{}; foreach ($n in [IO.Directory]::GetFiles($O)) { $otherBefore[[IO.Path]::GetFileName($n)] = Sha $n }
    $namesP = @([IO.Directory]::GetFiles($P) | ForEach-Object { [IO.Path]::GetFileName($_) })
    $namesO = @($otherBefore.Keys)
    if ($Arc.StartsWith('P\')) { $Arc = $P + $Arc.Substring(1) } elseif ($Arc.StartsWith('O\')) { $Arc = $O + $Arc.Substring(1) }
    $rep = Reports; $id = 0; $fatal = $null
    try {
        foreach ($l in $Locks) { Lock-Source ($P + '\' + $l) }
        $id = Start-Tc $P
        Post-Cmd (Get-Main $id) 842   # select all in the (active) left panel
        Start-Sleep -Milliseconds 600
        $r = & $Do $id
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        Start-Sleep -Milliseconds 500
        Release-Locks
        # every source: intact, or gone and byte-identical inside the archive
        $content = Arc-Content $Arc
        $state = @(); $loss = 0; $intact = 0; $inArc = 0
        foreach ($n in ($before.Keys | Sort-Object)) {
            $now = Sha ($P + '\' + $n)
            $leaf = [IO.Path]::GetFileName($n)
            $packed = $content.Files.ContainsKey($leaf) -and $content.Files[$leaf] -eq $before[$n]
            if ($now -eq $before[$n]) { $intact++; $s = 'intact' }
            elseif ($now -eq '') { if ($packed) { $inArc++; $s = 'moved into the archive' } else { $loss++; $s = 'GONE (not in the archive)' } }
            # the archive itself as a source (7-Zip plug-in): updated, its old content is inside it
            elseif ([string]::Equals($P + '\' + $n, $Arc, [StringComparison]::OrdinalIgnoreCase) -and $content.Ok -and $packed) { $s = 'the archive itself, updated (its old content is inside it)' }
            else { if ($packed) { $s = 'CHANGED on disk (its data is in the archive)' } else { $s = 'CHANGED on disk' }; $loss++ }
            $state += ($n + ': ' + $s)
        }
        foreach ($n in ($otherBefore.Keys | Sort-Object)) {
            $now = Sha ($O + '\' + $n)
            if ($now -ne $otherBefore[$n] -and [string]::Equals($O + '\' + $n, $Arc, [StringComparison]::OrdinalIgnoreCase)) { $state += ('out\' + $n + ': the target archive, replaced as asked') }
            elseif ($now -ne $otherBefore[$n] -and $Consumed -contains $n) { $state += ('out\' + $n + ': ' + $(if ($now) { 'changed' } else { 'gone' }) + ' (overwritten as confirmed - allowed)') }
            elseif ($now -ne $otherBefore[$n]) { $loss++;$state += ('out\' + $n + ': ' + $(if ($now) { 'CHANGED' } else { 'GONE' })) } else { $state += ('out\' + $n + ': intact') }
        }
        $res = [pscustomobject]@{ R = $r; Loss = $loss; Intact = $intact; InArc = $inArc; Content = $content; P = (Disk-Names $P); O = (Disk-Names $O); Fatal = $fatal
                                  NewP = @(New-Names $P '*' $namesP); NewO = @(New-Names $O '*' $namesO) }
        $e = & $Expect $res
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and $loss -eq 0 -and $e[0]
        $msgs = (@($r.Messages | ForEach-Object { if ($_.Length -gt 420) { $_.Substring(0, 420) + '...' } else { $_ } }) -join ' || ')
        Row $Case 'RUN' (V $ok) ("{0} | sources: {1} | loss {2} | archive: {3} [{4}] | P: [{5}] | out: [{6}] | expected: {7} | windows: {8}{9}{10}" -f $What, ($state -join '; '), $loss,
                $(if ($content.Ok) { 'tests OK' } elseif ($content.Note) { $content.Note } else { 'fails' }), ((@($content.Files.Keys) | Sort-Object) -join ','), (Esc $res.P), (Esc $res.O), $e[1],
                $(if ($msgs) { $msgs } else { 'none' }), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { Release-Locks; if ($id) { End-Row $Case $id $fatal $rep } }
}

# the core's Pack dialog: packer, archive name, Move; then the windows
function Pack-Dlg([int]$Id, [string]$PackerRx, [string]$ArcText, [bool]$Move, [string]$Answer, [int]$Vol, [int[]]$Prefer) {
    $dlg = Open-ByCmd $Id 850
    if ($dlg -eq [IntPtr]::Zero) { throw 'Pack (850) opened no window' }
    $packer = Ctl $dlg 511
    $items = @([Drv106]::ComboItems($packer, 5000))
    $ix = -1; for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i] -match $PackerRx) { $ix = $i; break } }
    if ($ix -lt 0) { throw ('no packer ' + $PackerRx + ' among: ' + ($items -join ' ; ')) }
    [void][Drv098f]::Send($packer, 0x014E, $ix, 0, 5000)
    [void][Drv098f]::Send($dlg, 0x0111, ((1 -shl 16) -bor 511), $packer.ToInt64(), 5000)
    [void][Drv098f]::SetText((Find-Ctl $dlg 210), $ArcText, 5000)
    $mv = Ctl $dlg 512; [void][Drv098f]::Send($mv, 0x00F1, $(if ($Move) { 1 } else { 0 }), 0, 5000)
    Click-Ok $dlg
    Start-Sleep -Milliseconds 400
    return (Drive $Id $Answer $Vol $Prefer)
}
# F5 / F6 to the right panel (the archive)
function Copy-Dlg([int]$Id, [bool]$Move, [int[]]$Prefer) {
    $dlg = Open-ByCmd $Id $(if ($Move) { 728 } else { 727 })
    if ($dlg -eq [IntPtr]::Zero) { throw 'Copy/Move opened no window' }
    $t = [Drv098f]::GetText((Find-Ctl $dlg 210), 5000)
    Click-Ok $dlg
    Start-Sleep -Milliseconds 400
    $r = Drive $Id '' 0 $Prefer
    [void]$r.Messages.Insert(0, '[target ' + (Esc $t) + ']')
    return $r
}
function Saw($res, [string]$rx) { return (@($res.R.Messages | Where-Object { $_ -match $rx }).Count -gt 0) }
$Refused = 'to itself|being packed|one of the files'
# feature 119: the core's refusal names the archive - CFileErrorDlg (IDD_ERROR3): a "Name:" label and the
# to-itself text (the name itself is drawn by CStaticText, which WM_GETTEXT does not return); before 119 a
# plain message box without a name
$Named = 'Name:.*to itself'
# the ZIP plug-in's IDS_CANTMULTIVOL
$MultiVolTaken = 'only like a new archive'
# no file matching $Like was created (and left) in P or out\ by the run
function NoNew($res, [string]$Like) { return (@($res.NewP | Where-Object { $_ -like $Like }).Count -eq 0 -and @($res.NewO | Where-Object { $_ -like $Like }).Count -eq 0) }
# an archive made by 7z.exe in $Dir from the files $Names (in $Dir)
function Mk-Arc([string]$Dir, [string]$Name, [string]$Type, [string[]]$Names) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    if ([IO.File]::Exists($Dir + '\' + $Name)) { Remove-Item -LiteralPath ($Dir + '\' + $Name) -Force }
    Push-Location -LiteralPath $Dir
    try { [void](& $SevenZip a ('-t' + $Type) $Name @Names 2>&1) } finally { Pop-Location; $ErrorActionPreference = $old }
}

# ---- main --------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc176_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config; Set-ProbeConfig
    Out ("overwrite_probe (feature 176) {0}, expect: {1}" -f $Label, $Expect)
    Save-Clip   # the P rows hold the clipboard (shared with the visible desktop); restored at the end
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; 7z {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, (Test-Path -LiteralPath $SevenZip))
    Out ''
    $ZipRx = '^ZIP'; $SzRx = '^7-Zip'
    $kf = @(@{ N = 'a1.bin'; S = 12000 }, @{ N = 'z9.bin'; S = 3000 })
    $mkK = { param([string]$Name, [string]$Type) Rand-File ($O + '\old.bin') 2000 88; Mk-Arc $O $Name $Type @('old.bin'); Remove-Item -LiteralPath ($O + '\old.bin') -Force }
    # the old archive must be there, unchanged: it still holds old.bin only, nothing new left in out\
    $keepExp = { param($res) @(($res.R.Asked -eq 1 -and $res.R.ErrorQ -ge 1 -and $res.Content.Ok -and $res.Content.Files.Count -eq 1 -and $res.Content.Files.ContainsKey('old.bin') -and $res.NewO.Count -eq 0 -and $res.Intact -eq 2), 'asked, Overwrite; the error cancelled; the old archive still holds old.bin; nothing else left in out\; sources intact') }
    Run-Case 'O-fail-zip' $kf { & $mkK 'k.zip' 'zip' } { param($id) Pack-Dlg $id $ZipRx ($O + '\k.zip') $false 'over' 0 @(2, 1) } 'O\k.zip' $keepExp 'Pack (ZIP) into the existing out\k.zip, Overwrite, z9.bin cannot be read, Cancel, copy' @('z9.bin')
    Run-Case 'O-fail-7z' $kf { & $mkK 'k.7z' '7z' } { param($id) Pack-Dlg $id $SzRx ($O + '\k.7z') $false 'over' 0 @(2, 1) } 'O\k.7z' $keepExp 'Pack (7-Zip) into the existing out\k.7z, Overwrite, z9.bin cannot be read, Cancel, copy' @('z9.bin')
    Run-Case 'O-fail-move' $kf { & $mkK 'k.zip' 'zip' } { param($id) Pack-Dlg $id $ZipRx ($O + '\k.zip') $true 'over' 0 @(2, 1) } 'O\k.zip' $keepExp 'as O-fail-zip, MOVE (no source deleted)' @('z9.bin')
    # the review's case: a Move that fails AFTER the new archive holds the moved files - z9.bin can be
    # read but not deleted (held open with FileShare Read only), the 7-Zip plug-in's delete error ->
    # Cancel: the new archive must stay (sources are in it), the old one is kept aside (arc*.tmp)
    $mkHeld = { & $mkK 'k.7z' '7z'; [void]$script:LockStreams.Add([IO.File]::Open(($P + '\z9.bin'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)) }
    $bothExp = { param($res)
        $aside = @($res.NewO | Where-Object { $_ -like 'arc*.tmp' })
        $old = $(if ($aside.Count -eq 1) { Arc-Content ($O + '\' + $aside[0]) } else { $null })
        @(($res.Content.Ok -and $res.Content.Files.ContainsKey('a1.bin') -and $null -ne $old -and $old.Ok -and $old.Files.ContainsKey('old.bin')), ('the new k.7z holds the moved files; the old archive kept as ' + ($aside -join ',') + ' (holds old.bin: ' + $(if ($old) { $old.Files.ContainsKey('old.bin') } else { 'no file' }) + ')')) }
    Run-Case 'O-move-late-7z' $kf $mkHeld { param($id) Pack-Dlg $id $SzRx ($O + '\k.7z') $true 'over' 0 @(2, 1) } 'O\k.7z' $bothExp 'Pack (7-Zip) MOVE into the existing out\k.7z, Overwrite, z9.bin cannot be deleted after packing, Cancel'
    $okExp = { param($res) @(($res.R.Asked -eq 1 -and $res.Content.Ok -and $res.Content.Files.Count -eq 2 -and $res.Content.Files.ContainsKey('a1.bin') -and -not $res.Content.Files.ContainsKey('old.bin') -and $res.NewO.Count -eq 0), 'Overwrite: out\k.zip holds the two new files only; nothing else left in out\') }
    Run-Case 'O-ok-zip' $kf { & $mkK 'k.zip' 'zip' } { param($id) Pack-Dlg $id $ZipRx ($O + '\k.zip') $false 'over' 0 @(1) } 'O\k.zip' $okExp 'Pack (ZIP) into the existing out\k.zip, Overwrite, copy'
    $multiExp = { param($res) @(($res.R.Asked -eq 1 -and $res.Content.Ok -and $res.Content.Files.Count -eq 2 -and $res.Content.Files.ContainsKey('a1.bin')), 'multi-volume Overwrite: the set created and its last volume renamed to k.zip; tests OK with both files') }
    Run-Case 'O-ok-multi' $kf { & $mkK 'k.zip' 'zip' } { param($id) Pack-Dlg $id $ZipRx ($O + '\k.zip') $false 'over' 4 @(1) } 'O\k.zip' $multiExp 'multi-volume into the existing out\k.zip, Overwrite, copy'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    Release-Locks
    Restore-Clip
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
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
if ($Expect -eq 'before') { exit 0 }
exit $nf
