<#
.SYNOPSIS
    Feature 119 probe (extends the feature 106 probe packself_probe.ps1): a pack never writes its
    archive over a file it packs (106), a pack into an archive that is one of its own sources is
    refused for every packer and route before anything is touched, a failed or cancelled
    multi-volume ZIP pack leaves no volumes behind (and never touches a file it did not create),
    and a multi-volume pack never leaves its set ending with name.z0N because name.zip existed.

.DESCRIPTION
    Feature 119 changes against the 106 probe (rows of 106 kept, expectations updated):
      A  the core refuses BEFORE the "Add or Overwrite?" question (Asked 0), with the box that
         names the archive (CFileErrorDlg: "Name:" + "Cannot copy/move a file to itself.").
         The archive's name itself is drawn by CStaticText and is not readable by WM_GETTEXT;
         the probe checks the form ("Name:" label present), a person sees the name.
      B  "Add" into a selected archive - refused (before: ZIP sharing violation; 7-Zip packed the
         old archive into the new one, Move then "Delete Error" 32) - items 3 and 4.
      D  refused at volume 4: volumes 1-3 of the refused archive are deleted now (item 1).
      E  declined overwrite of a later volume: volume 1 of the abandoned set is deleted (item 1).
      H  F5 / F6 into the selected archive shown in the right panel - refused (items 3, 4).
    New rows:
      L  multi-volume pack that fails mid-way: a later source is held open by this script
         (FileShare ReadWrite+Delete, opened for writing - the plug-in cannot open it), the error
         answered Cancel. No volume of the set may remain; files in the target folder that this
         operation did not create stay byte-identical; Move deletes no source. One row answers
         "overwrite m.z01?" Yes first: that file's content is this operation's volume data from
         then on and it is deleted with the set (decision, spec Clarifications).
      K  multi-volume into out\k.zip that exists (not selected): Add -> refused with the plug-in's
         "Archive of the same file name already exists ... only like a new archive", nothing
         created; Overwrite -> the set is created and renamed to k.zip; the question switched off
         -> refused as Add (item 2).
      Czech names (rows *-cz): sources, archive and volumes named with characters of CP1250.
    Pure ASCII source: the Czech names are built from [char] codes.

    Fixtures under %TEMP%\tc119\pk (removed at the end). Every case starts the program with
    the left panel on the case's folder P ("packfolder_long", so it has an 8.3 alias), selects
    everything in it (842) and runs one route. Sources are random (incompressible) bytes, so a
    truncated or overwritten source is visible in its SHA-256.

    Routes (letters = rows):
      A  core Pack dialog (850), the archive name IS a selected file, the core asks "already
         exists - Add or Overwrite?" -> Overwrite. ZIP and 7-Zip packers.
      B  core Pack dialog, the archive name IS a selected existing archive -> Add.
      C  ZIP plug-in multi-volume (Extended Pack Options, 4 KB volumes), archive P\a.zip, a
         selected source is named like the FIRST volume (a.z01).
      D  as C, the selected source is named like a LATER volume (a.z04) - created mid-pack.
      E  multi-volume into folder O holding an unrelated (not selected) a.z02 / a.z01; the
         overwrite question is answered Cancel - the file must stay.
      F  multi-volume, no collision (archive in O) - must work; 7z.exe tests the set.
      G  plain ZIP, new archive in O - must work.
      H  F5 / F6 from P into the archive shown in the right panel while that archive is one
         of the selected files (core FilesAction route). ZIP and 7-Zip.
    Alias kinds of the typed archive name: same, case (upper-case), short (the folder's or the
    file's 8.3 name), unc (\\localhost\C$\...).

    Per row: the windows shown (and what the probe answered), then for every selected source:
    intact (byte-identical on disk), or - when it is gone - found byte-identical inside the
    resulting archive (7z.exe x). "LOSS" = a source neither intact nor in the archive, or
    changed on disk. Plus the row's own expectation (refused / packed).

    MUST run through tools\run_on_hidden_desktop.ps1 (refuses the Default / Winlogon desktop).
    Registry exported/restored/verified.
    Pure ASCII. Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
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
if (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon') { Write-Output ("NOT RUN: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 3 }

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

$Root = $TempRoot + '\tc119\pk'
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
$RegCfg = 'HKCU\Software\Tandem Commander\0.1'

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
$backup = Join-Path $env:TEMP 'tc119_pk_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config; Set-ProbeConfig
    Out ("packleft_probe (feature 119) {0}" -f $Label)
    Save-Clip   # the P rows hold the clipboard (shared with the visible desktop); restored at the end
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; 7z {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, (Test-Path -LiteralPath $SevenZip))
    Out ''
    $ZipRx = '^ZIP'; $SzRx = '^7-Zip'
    $two = @(@{ N = 'src.zip'; S = 40000 }, @{ N = 'b.bin'; S = 3000 })

    # ---- A: core Pack dialog, the archive name IS a selected file: refused BEFORE the "Add or
    #      Overwrite?" question (119; 106 refused the Overwrite answer), the box names the archive
    $aExp = { param($res) @(((Saw $res $Named) -and $res.Intact -eq 2 -and $res.R.Asked -eq 0), 'refused before the question, the box names the archive, both sources intact') }
    Run-Case 'A-zip-same-copy' $two $null { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $false 'over' 0 @(1, 6) } 'P\src.zip' $aExp 'Pack (ZIP) into src.zip = a selected file, copy'
    Run-Case 'A-zip-same-move' $two $null { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $true 'over' 0 @(1, 6) } 'P\src.zip' $aExp 'Pack (ZIP) into src.zip = a selected file, MOVE'
    Run-Case 'A-zip-case-copy' $two $null { param($id) Pack-Dlg $id $ZipRx ($P + '\SRC.ZIP') $false 'over' 0 @(1, 6) } 'P\src.zip' $aExp 'Pack (ZIP) into SRC.ZIP (case), copy'
    $long = @(@{ N = 'longsourcename.zip'; S = 40000 }, @{ N = 'b.bin'; S = 3000 })
    Run-Case 'A-zip-short-move' $long $null { param($id) $s = [IO.Path]::GetFileName([Drv106]::Short($P + '\longsourcename.zip')); Pack-Dlg $id $ZipRx ($P + '\' + $s) $true 'over' 0 @(1, 6) } 'P\longsourcename.zip' $aExp 'Pack (ZIP) into the 8.3 name of the selected file, MOVE'
    Run-Case 'A-zip-unc-move' $two $null { param($id) Pack-Dlg $id $ZipRx (Unc ($P + '\src.zip')) $true 'over' 0 @(1, 6) } 'P\src.zip' $aExp 'Pack (ZIP) into \\localhost\C$\...\src.zip, MOVE'
    $two7 = @(@{ N = 'src.7z'; S = 40000 }, @{ N = 'b.bin'; S = 3000 })
    Run-Case 'A-7z-same-move' $two7 $null { param($id) Pack-Dlg $id $SzRx ($P + '\src.7z') $true 'over' 0 @(1, 6) } 'P\src.7z' $aExp 'Pack (7-Zip) into src.7z = a selected file, MOVE'
    $dirFiles = @(@{ N = 'b.bin'; S = 3000 })
    $mkDir = { NewDir ($P + '\D'); Rand-File ($P + '\D\x.zip') 30000 55; Rand-File ($P + '\D\c.bin') 2000 56 }
    $aDirExp = { param($res) @(((Saw $res $Named) -and $res.Intact -eq 3 -and $res.R.Asked -eq 0), 'refused before the question; D\x.zip, D\c.bin and b.bin intact') }
    Run-Case 'A-zip-dir-move' $dirFiles $mkDir { param($id) Pack-Dlg $id $ZipRx ($P + '\D\x.zip') $true 'over' 0 @(1, 6) } 'P\D\x.zip' $aDirExp 'Pack (ZIP) of D + b.bin into D\x.zip (inside the selected folder D), MOVE'
    $unrel = @(@{ N = 'p.bin'; S = 9000 }, @{ N = 'q.bin'; S = 7000 })
    $aUnExp = { param($res) @(($res.Content.Ok -and $res.Content.Files.Count -eq 2 -and $res.Content.Files.ContainsKey('p.bin') -and $res.R.PackAgain -eq 0 -and $res.R.Asked -eq 1), 'asked, overwritten: the new archive holds exactly the two sources') }
    Run-Case 'A-zip-unrelated-over' $unrel { Rand-File ($O + '\old.zip') 5000 66 } { param($id) Pack-Dlg $id $ZipRx ($O + '\old.zip') $false 'over' 0 @(1, 6) } 'O\old.zip' $aUnExp 'Pack (ZIP) into out\old.zip (exists, not selected), Overwrite, copy'
    # 106 review N2 row: with 119 the question is never shown for a selected archive - refused twice, never asked
    $noAsk = { param($id)
        $r1 = Pack-Dlg $id $ZipRx ($P + '\src.zip') $false 'over+noask' 0 @(1, 6)
        $r2 = Pack-Dlg $id $ZipRx ($P + '\src.zip') $false 'over' 0 @(1, 6)
        foreach ($m in $r2.Messages) { [void]$r1.Messages.Add('(2nd) ' + $m) }
        $r1.Asked += $r2.Asked; $r1.PackAgain += $r2.PackAgain; if ($r2.Fatal) { $r1.Fatal = $r2.Fatal }; if ($r2.TimedOut) { $r1.TimedOut = $true }
        return $r1 }
    Run-Case 'A-zip-noask-refused' $two $null $noAsk 'P\src.zip' { param($res) @(((Saw $res $Named) -and $res.Intact -eq 2 -and $res.R.Asked -eq 0 -and $res.R.PackAgain -eq 2), 'refused twice before any question') } 'Pack into src.zip (selected) twice'

    # ---- B: core Pack dialog, "Add" into an existing archive that is a selected file (items 3, 4):
    #      refused before the question (before 119: ZIP sharing violation; 7-Zip packed the old archive
    #      into the new one, and a Move then failed with "Delete Error" 32)
    $mk = { Mk-Arc $P 'src.zip' 'zip' @('b.bin') }
    $mk7 = { Mk-Arc $P 'src.7z' '7z' @('b.bin') }
    $bExp = { param($res) @(((Saw $res $Named) -and $res.Intact -eq 2 -and $res.R.Asked -eq 0 -and $res.Content.Ok), 'refused before the question, named; both sources intact, the archive unchanged and tests OK') }
    Run-Case 'B-zip-add-copy' $two $mk { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $false 'add' 0 @(173, 1, 6) } 'P\src.zip' $bExp 'Pack (ZIP) into the selected existing src.zip, Add, copy'
    Run-Case 'B-zip-add-move' $two $mk { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $true 'add' 0 @(173, 1, 6) } 'P\src.zip' $bExp 'Pack (ZIP) into the selected existing src.zip, Add, MOVE'
    Run-Case 'B-zip-add-move-inplace' $two { & $mk; Set-BackupZip 0 } { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $true 'add' 0 @(173, 1, 6) } 'P\src.zip' $bExp 'as B-zip-add-move with Backup ZIP off (update in place)'
    Set-BackupZip 1
    Run-Case 'B-7z-add-copy' $two7 $mk7 { param($id) Pack-Dlg $id $SzRx ($P + '\src.7z') $false 'add' 0 @(173, 1, 6) } 'P\src.7z' $bExp 'Pack (7-Zip) into the selected existing src.7z, Add, copy'
    Run-Case 'B-7z-add-move' $two7 $mk7 { param($id) Pack-Dlg $id $SzRx ($P + '\src.7z') $true 'add' 0 @(173, 1, 6) } 'P\src.7z' $bExp 'Pack (7-Zip) into the selected existing src.7z, Add, MOVE'
    $cz7 = @(@{ N = ($CzA + '.7z'); S = 40000 }, @{ N = ($CzB + '.bin'); S = 3000 })
    Run-Case 'B-7z-cz-move' $cz7 { Mk-Arc $P ($CzA + '.7z') '7z' @($CzB + '.bin') } { param($id) Pack-Dlg $id $SzRx ($P + '\' + $CzA + '.7z') $true 'add' 0 @(173, 1, 6) } ('P\' + $CzA + '.7z') $bExp 'Czech names: Pack (7-Zip) into the selected existing <cz>.7z, Add, MOVE'
    $czz = @(@{ N = ($CzB + '.zip'); S = 40000 }, @{ N = ($CzA + '.bin'); S = 3000 })
    Run-Case 'B-zip-cz-copy' $czz { Mk-Arc $P ($CzB + '.zip') 'zip' @($CzA + '.bin') } { param($id) Pack-Dlg $id $ZipRx ($P + '\' + $CzB + '.zip') $false 'add' 0 @(173, 1, 6) } ('P\' + $CzB + '.zip') $bExp 'Czech names: Pack (ZIP) into the selected existing <cz>.zip, Add, copy'
    # the question switched off ("Add To Archive" confirmation 0): no question, still refused
    Run-Case 'B-zip-noask-move' $two { & $mk; Set-AskAdd 0 } { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $true 'add' 0 @(173, 1, 6) } 'P\src.zip' $bExp 'as B-zip-add-move with the add-to-archive question switched off'
    Set-AskAdd 1

    # ---- C: multi-volume, a selected source has the FIRST volume's name (106): refused, nothing created
    $c = @(@{ N = 'a.z01'; S = 8000 }, @{ N = 'b.bin'; S = 8000 })
    $cExp = { param($res) @(((Saw $res $Refused) -and $res.Intact -eq 2 -and $res.R.OverwriteQ -eq 0 -and (NoNew $res '*.z*')), 'refused before any overwrite question, both sources intact, no volume created') }
    Run-Case 'C-same-copy' $c $null { param($id) Pack-Dlg $id $ZipRx ($P + '\a.zip') $false '' 4 @(138, 1) } 'P\a.zip' $cExp 'multi-volume a.zip (volume 1 = a.z01 = a selected file), copy, overwrite -> Yes'
    Run-Case 'C-same-move' $c $null { param($id) Pack-Dlg $id $ZipRx ($P + '\a.zip') $true '' 4 @(138, 1) } 'P\a.zip' $cExp 'as C-same-copy, MOVE'
    Run-Case 'C-case-copy' $c $null { param($id) Pack-Dlg $id $ZipRx ($P + '\A.ZIP') $false '' 4 @(138, 1) } 'P\A.zip' $cExp 'multi-volume A.ZIP (volume A.z01), copy'
    Run-Case 'C-short-move' $c $null { param($id) Pack-Dlg $id $ZipRx ([Drv106]::Short($P) + '\a.zip') $true '' 4 @(138, 1) } 'P\a.zip' $cExp 'multi-volume through the folder 8.3 name, MOVE'
    Run-Case 'C-unc-copy' $c $null { param($id) Pack-Dlg $id $ZipRx (Unc ($P + '\a.zip')) $false '' 4 @(138, 1) } 'P\a.zip' $cExp 'multi-volume through \\localhost\C$, copy'
    Run-Case 'C-unc-move' $c $null { param($id) Pack-Dlg $id $ZipRx (Unc ($P + '\a.zip')) $true '' 4 @(138, 1) } 'P\a.zip' $cExp 'multi-volume through \\localhost\C$, MOVE'
    $hl = @(@{ N = 'x.bin'; S = 8000 }, @{ N = 'b.bin'; S = 8000 })
    $mkHl = { [void](& cmd.exe /c ('mklink /H "{0}" "{1}"' -f ($O + '\h.z01'), ($P + '\x.bin')) 2>&1) }
    $hlExp = { param($res) @(((Saw $res $Refused) -and $res.Intact -eq 2 -and $res.R.OverwriteQ -eq 0 -and (NoNew $res '*.z*')), 'refused before any overwrite question (out\h.z01 is a hard link of x.bin), sources intact, no volume created') }
    Run-Case 'C-hardlink-copy' $hl $mkHl { param($id) Pack-Dlg $id $ZipRx ($O + '\h.zip') $false '' 4 @(138, 1) } 'O\h.zip' $hlExp 'multi-volume out\h.zip; out\h.z01 is a hard link of the selected x.bin, copy, overwrite -> Yes'
    $mkHlStale = { & $mkHl; $fs = [IO.File]::Open(($O + '\h.z01'), 'Append', 'Write'); $fs.Write((New-Object byte[] 3000), 0, 3000); $fs.Close() }
    Run-Case 'C-hardlink-stale' $hl $mkHlStale { param($id) Pack-Dlg $id $ZipRx ($O + '\h.zip') $false '' 4 @(138, 1) } 'O\h.zip' $hlExp 'as C-hardlink-copy, 3,000 bytes appended through out\h.z01 after the panel listed x.bin (stale listed size), overwrite -> Yes'

    # ---- D: a selected source has a LATER volume's name: refused at volume 4 - and (119) volumes
    #      1-3 of the refused archive are deleted (before 119 they stayed)
    $dd = @(@{ N = 'a.z04'; S = 8000 }, @{ N = 'b.bin'; S = 12000 })
    $ddExp = { param($res) @(((Saw $res $Refused) -and $res.Intact -eq 2 -and $res.R.OverwriteQ -eq 0 -and (NoNew $res 'a.*')), 'refused at volume 4 before its overwrite question, both sources intact, no volume of the refused archive left') }
    Run-Case 'D-later-copy' $dd $null { param($id) Pack-Dlg $id $ZipRx ($P + '\a.zip') $false '' 4 @(138, 1) } 'P\a.zip' $ddExp 'multi-volume a.zip, volume 4 = a.z04 = a selected file, copy, overwrite -> Yes'
    Run-Case 'D-later-move' $dd $null { param($id) Pack-Dlg $id $ZipRx ($P + '\a.zip') $true '' 4 @(138, 1) } 'P\a.zip' $ddExp 'as D-later-copy, MOVE'

    # ---- E: an unrelated existing volume name in out\, the question answered Cancel: the declined file
    #      stays, and (119) the volumes this operation wrote before it are deleted
    $e = @(@{ N = 'x.bin'; S = 12000 })
    $eExp = { param($res) @(($res.R.OverwriteQ -ge 1 -and (NoNew $res 'a.*')), 'the overwrite question was asked; the declined file stays; no volume of the abandoned set left') }
    Run-Case 'E-decline-vol2' $e { Rand-File ($O + '\a.z02') 5000 77 } { param($id) Pack-Dlg $id $ZipRx ($O + '\a.zip') $false '' 4 @(2) } 'O\a.zip' $eExp 'multi-volume into out\a.zip, out\a.z02 exists (not selected), overwrite -> Cancel'
    Run-Case 'E-decline-vol1' $e { Rand-File ($O + '\a.z01') 5000 78 } { param($id) Pack-Dlg $id $ZipRx ($O + '\a.zip') $false '' 4 @(2) } 'O\a.zip' $eExp 'multi-volume into out\a.zip, out\a.z01 exists (not selected), overwrite -> Cancel'

    # ---- F / G: ordinary packing still works
    $fg = @(@{ N = 'p.bin'; S = 9000 }, @{ N = 'q.bin'; S = 7000 })
    $okExp = { param($res) @(($res.Content.Ok -and $res.Content.Files.Count -eq 2), 'packed, the archive tests OK and holds both files') }
    Run-Case 'F-multivol-copy' $fg $null { param($id) Pack-Dlg $id $ZipRx ($O + '\m.zip') $false '' 4 @(1) } 'O\m.zip' $okExp 'multi-volume into out\m.zip, no collision, copy'
    Run-Case 'F-multivol-move' $fg $null { param($id) Pack-Dlg $id $ZipRx ($O + '\m.zip') $true '' 4 @(1) } 'O\m.zip' $okExp 'multi-volume into out\m.zip, no collision, MOVE'
    $fgCz = @(@{ N = ($CzA + '.bin'); S = 9000 }, @{ N = ($CzB + '.bin'); S = 7000 })
    Run-Case 'F-multivol-cz' $fgCz $null { param($id) Pack-Dlg $id $ZipRx ($O + '\' + $CzA + '.zip') $false '' 4 @(1) } ('O\' + $CzA + '.zip') $okExp 'Czech names: multi-volume into out\<cz>.zip, copy'
    Run-Case 'G-plain-copy' $fg $null { param($id) Pack-Dlg $id $ZipRx ($O + '\n.zip') $false '' 0 @(1) } 'O\n.zip' $okExp 'plain ZIP into out\n.zip, copy'
    Run-Case 'G-plain-move' $fg $null { param($id) Pack-Dlg $id $ZipRx ($O + '\n.zip') $true '' 0 @(1) } 'O\n.zip' $okExp 'plain ZIP into out\n.zip, MOVE'
    Run-Case 'G-plain-7z' $fg $null { param($id) Pack-Dlg $id $SzRx ($O + '\n.7z') $true '' 0 @(1) } 'O\n.7z' $okExp 'plain 7-Zip into out\n.7z, MOVE'

    # ---- H: F5 / F6 into the archive shown in the right panel, which is one of the selected files:
    #      refused before the packer runs (items 3, 4)
    $hRun = {
        # (names that Run-Case does not use: its own $Arc would shadow an $Arc of this block inside $Pre)
        param([string]$HCase, [string]$HArc, [string]$HType, [string]$HOther, [bool]$HMove)
        $hFiles = @(@{ N = $HArc; S = 100 }, @{ N = $HOther; S = 3000 })
        $save = $StartDir
        Run-Case $HCase $hFiles { Mk-Arc $P $HArc $HType @($HOther); $script:StartDir = $P + '\' + $HArc } { param($id) Copy-Dlg $id $HMove @(173, 1, 6) } ('P\' + $HArc) $bExp ('F' + $(if ($HMove) { '6' } else { '5' }) + ' of ' + (Esc $HArc) + ' + ' + (Esc $HOther) + ' into ' + (Esc $HArc) + ' (right panel)')
        $script:StartDir = $save
    }
    & $hRun 'H-zip-copy' 'src.zip' 'zip' 'b.bin' $false
    & $hRun 'H-zip-move' 'src.zip' 'zip' 'b.bin' $true
    & $hRun 'H-7z-copy' 'src.7z' '7z' 'b.bin' $false
    & $hRun 'H-7z-move' 'src.7z' '7z' 'b.bin' $true
    & $hRun 'H-zip-cz-move' ($CzB + '.zip') 'zip' ($CzA + '.bin') $true
    & $hRun 'H-7z-cz-copy' ($CzA + '.7z') '7z' ($CzB + '.bin') $false
    # the archive lies inside a selected folder D: F5 of {D, b.bin} into D\x.7z (right panel)
    $save = $StartDir
    $hDirExp = { param($res) @(((Saw $res $Named) -and $res.Intact -eq 3 -and $res.Content.Ok), 'refused (the archive is inside the selected folder D), D\x.7z, D\c.bin and b.bin intact') }
    Run-Case 'H-7z-dir-copy' @(@{ N = 'b.bin'; S = 3000 }) { NewDir ($P + '\D'); Rand-File ($P + '\D\c.bin') 2000 56; Mk-Arc ($P + '\D') 'x.7z' '7z' @('c.bin'); $script:StartDir = $P + '\D\x.7z' } { param($id) Copy-Dlg $id $false @(173, 1, 6) } 'P\D\x.7z' $hDirExp 'F5 of D + b.bin into D\x.7z (inside the selected folder D, right panel)'
    $script:StartDir = $save

    # ---- P: copy / cut + paste into the archive (code review SF4): the paste builds the drag & drop
    #      operation (DragDropToArcOrFS - the same route as a drop on an archive panel). The left
    #      panel's selection is copied / cut (773 / 774), the same panel changes into the archive
    #      (Change Directory to P\<archive>) and pastes (775). Needs the clipboard - 098, 101 and 107
    #      found it cannot be opened from the hidden desktop: then NOT DRIVEN (by hand: quickstart.md)
    $pRun = {
        param([string]$PCase, [string]$PArc, [string]$PType, [string]$POther, [bool]$PMove)
        if (-not (Want $PCase)) { return }
        if (-not $script:ClipOk) { Row $PCase 'RUN' 'NOT DRIVEN' 'the clipboard cannot be opened from this session (hidden desktop, as in 098 / 101 / 107) - the drag & drop / paste refusal is a by-hand step (quickstart.md)'; return }
        $pFiles = @(@{ N = $PArc; S = 100 }, @{ N = $POther; S = 3000 })
        Run-Case $PCase $pFiles { Mk-Arc $P $PArc $PType @($POther) } {
            param($id)
            Post-Cmd (Get-Main $id) $(if ($PMove) { 774 } else { 773 })
            Start-Sleep -Milliseconds 1200
            $held = Do-ChangeDir $id ($P + '\' + $PArc)
            Start-Sleep -Milliseconds 1200
            Post-Cmd (Get-Main $id) 775
            Start-Sleep -Milliseconds 400
            $r = Drive $id '' 0 @(173, 1, 6)
            [void]$r.Messages.Insert(0, ('[Change Directory field held the archive path: {0}]' -f $held))
            return $r
        } ('P\' + $PArc) $bExp ($(if ($PMove) { 'cut' } else { 'copy' }) + ' + paste of ' + (Esc $PArc) + ' + ' + (Esc $POther) + ' into ' + (Esc $PArc) + ' (the panel changed into the archive)')
    }
    & $pRun 'P-zip-cutpaste' 'src.zip' 'zip' 'b.bin' $true
    & $pRun 'P-7z-copypaste' 'src.7z' '7z' 'b.bin' $false
    & $pRun 'P-zip-cz-cutpaste' ($CzA + '.zip') 'zip' ($CzB + '.bin') $true

    # ---- L: a multi-volume pack that fails mid-way (item 1): a later source is held open by this
    #      script, the error answered Cancel - no volume of the set may remain
    $lf = @(@{ N = 'a1.bin'; S = 12000 }, @{ N = 'z9.bin'; S = 3000 })
    $lExp = { param($res) @(($res.R.ErrorQ -ge 1 -and (NoNew $res 'm.*') -and $res.Intact -eq 2), 'the error was shown and cancelled; no volume of out\m.zip left (before 119: the volumes before the failing one stayed); both sources intact') }
    Run-Case 'L-lock-copy' $lf $null { param($id) Pack-Dlg $id $ZipRx ($O + '\m.zip') $false '' 4 @(2, 1) } 'O\m.zip' $lExp 'multi-volume into out\m.zip, z9.bin cannot be opened, Cancel, copy' @('z9.bin')
    Run-Case 'L-lock-move' $lf $null { param($id) Pack-Dlg $id $ZipRx ($O + '\m.zip') $true '' 4 @(2, 1) } 'O\m.zip' $lExp 'as L-lock-copy, MOVE (no source deleted)' @('z9.bin')
    # files in out\ this operation did not create stay byte-identical (a later volume's name, another name)
    Run-Case 'L-lock-keep' $lf { Rand-File ($O + '\m.z09') 5000 91; Rand-File ($O + '\m.txt') 700 92 } { param($id) Pack-Dlg $id $ZipRx ($O + '\m.zip') $false '' 4 @(2, 1) } 'O\m.zip' $lExp 'as L-lock-copy; out\m.z09 and out\m.txt exist (not reached, not selected) and must stay' @('z9.bin')
    # out\m.z01 exists, "overwrite?" Yes: from then on it holds this operation's volume data - deleted with the set
    $lYesExp = { param($res) @(($res.R.OverwriteQ -ge 1 -and $res.R.ErrorQ -ge 1 -and (NoNew $res 'm.*') -and -not [IO.File]::Exists($O + '\m.z01') -and $res.Intact -eq 2), 'asked, Yes; the error cancelled; the set incl. the overwritten out\m.z01 gone; sources intact') }
    Run-Case 'L-lock-yes-vol1' $lf { Rand-File ($O + '\m.z01') 5000 93 } { param($id) Pack-Dlg $id $ZipRx ($O + '\m.zip') $false '' 4 @(138, 2, 1) } 'O\m.zip' $lYesExp 'as L-lock-copy; out\m.z01 exists (not selected), overwrite -> Yes' @('z9.bin') @('m.z01')
    $lCz = @(@{ N = ($CzA + '.bin'); S = 12000 }, @{ N = ($CzB + '.bin'); S = 3000 })
    $lCzExp = { param($res) @(($res.R.ErrorQ -ge 1 -and (NoNew $res ($CzA + '*')) -and $res.Intact -eq 2), 'Czech names: the error cancelled; no volume left; sources intact') }
    Run-Case 'L-lock-cz-move' $lCz $null { param($id) Pack-Dlg $id $ZipRx ($O + '\' + $CzA + '_' + $CzB + '.zip') $true '' 4 @(2, 1) } ('O\' + $CzA + '_' + $CzB + '.zip') $lCzExp 'Czech names: multi-volume into out\<cz>.zip, <cz2>.bin cannot be opened, Cancel, MOVE' @($CzB + '.bin')

    # ---- K: multi-volume into out\k.zip that exists, not selected (item 2)
    $kf = @(@{ N = 'p.bin'; S = 9000 }, @{ N = 'q.bin'; S = 7000 })
    $mkK = { param([string]$Name) Rand-File ($O + '\old.bin') 2000 88; Mk-Arc $O $Name 'zip' @('old.bin'); Remove-Item -LiteralPath ($O + '\old.bin') -Force }
    $kExp = { param($res) @(((Saw $res $MultiVolTaken) -and (NoNew $res '*.z*') -and $res.Intact -eq 2 -and $res.Content.Ok -and $res.Content.Files.Count -eq 1 -and $res.Content.Files.ContainsKey('old.bin')), 'refused before anything is created ("only like a new archive"); the existing archive unchanged, no volume, sources intact') }
    Run-Case 'K-exist-add' $kf { & $mkK 'k.zip' } { param($id) Pack-Dlg $id $ZipRx ($O + '\k.zip') $false 'add' 4 @(1) } 'O\k.zip' $kExp 'multi-volume into the existing out\k.zip, Add, copy'
    Run-Case 'K-exist-add-move' $kf { & $mkK 'k.zip' } { param($id) Pack-Dlg $id $ZipRx ($O + '\k.zip') $true 'add' 4 @(1) } 'O\k.zip' $kExp 'as K-exist-add, MOVE'
    Run-Case 'K-exist-noask' $kf { & $mkK 'k.zip'; Set-AskAdd 0 } { param($id) Pack-Dlg $id $ZipRx ($O + '\k.zip') $true '' 4 @(1) } 'O\k.zip' $kExp 'as K-exist-add-move with the add-to-archive question switched off (no question)'
    Set-AskAdd 1
    Run-Case 'K-exist-cz' $kf { & $mkK ($CzB + '.zip') } { param($id) Pack-Dlg $id $ZipRx ($O + '\' + $CzB + '.zip') $false 'add' 4 @(1) } ('O\' + $CzB + '.zip') $kExp 'Czech name: multi-volume into the existing out\<cz>.zip, Add, copy'
    $kOverExp = { param($res) @(($res.R.Asked -eq 1 -and $res.Content.Ok -and $res.Content.Files.Count -eq 2 -and $res.Content.Files.ContainsKey('p.bin')), 'Overwrite: the old archive deleted by the core, the set created and its last volume renamed to k.zip; tests OK with both files') }
    Run-Case 'K-exist-over' $kf { & $mkK 'k.zip' } { param($id) Pack-Dlg $id $ZipRx ($O + '\k.zip') $false 'over' 4 @(1) } 'O\k.zip' $kOverExp 'multi-volume into the existing out\k.zip, Overwrite, copy'

    Row 'X-sfx' 'RUN' 'NOT DRIVEN' 'self-extracting archive (PackSelfExtract, PackMultiVol + SFX): no sfx package is shipped - the exe of a failed SFX multi-volume pack is not recorded (unchanged, unreachable)'
    Row 'X-rar' 'RUN' 'NOT DRIVEN' 'the RAR external packer: WinRAR is not installed here; the core refusal of routes A/B runs before any packer'
    Row 'X-removable' 'RUN' 'NOT DRIVEN' 'multi-volume onto removable media: no removable drive; a failure deletes only the current volume there (one name on every disk)'
    Row 'X-drag' 'RUN' 'NOT DRIVEN' 'a real mouse drag into an archive panel: DragDropToArcOrFS, the same call as the paste rows P'
    Row 'X-rename' 'RUN' 'NOT DRIVEN' 'the last volume''s rename failing at the end (name.zip appearing during the pack, removable media): reported, the set deleted - not reproducible on a fixed disk without a race'
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
exit $nf
