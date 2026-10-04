<#
.SYNOPSIS
    Feature 106 probe: a pack operation must never write its archive (or a volume of it) over
    a file that is one of the files being packed, and Move must never lose a source.

.DESCRIPTION
    Fixtures under %TEMP%\tc106\pk (removed at the end). Every case starts the program with
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

    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported/restored/verified.
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

$Root = $TempRoot + '\tc106\pk'
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

function Has-Ctl([IntPtr]$H, [int]$Id) { return (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $Id }).Count -gt 0) }
function Ctl([IntPtr]$H, [int]$Id) { return (@([Drv098f]::Kids($H) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $Id }) | Select-Object -First 1) }

# serves the windows of an operation. $Answer: 'add' / 'over' for the core's "already exists"
# question; $Vol: KB volume size for the ZIP options (0 = no multi-volume); $Prefer: button ids
# tried in order for every other window (none matching -> closed = Cancel)
function Drive([int]$Id, [string]$Answer, [int]$Vol, [int[]]$Prefer, [double]$Seconds = 90) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false; PackAgain = 0; Asked = 0; OverwriteQ = 0 }
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
function Run-Case([string]$Case, [object[]]$Files, [scriptblock]$Pre, [scriptblock]$Do, [string]$Arc, [scriptblock]$Expect, [string]$What) {
    if (-not (Want $Case)) { return }
    $script:P = $Root + '\' + $Case + '\packfolder_long'
    $script:O = $Root + '\' + $Case + '\out'
    NewDir $P; NewDir $O
    $seed = 1000
    foreach ($f in $Files) { $seed++; Rand-File ($P + '\' + $f.N) $f.S $seed }
    if ($Pre) { & $Pre }
    $before = @{}; foreach ($n in [IO.Directory]::GetFiles($P, '*', 'AllDirectories')) { $before[$n.Substring($P.Length + 1)] = Sha $n }
    $otherBefore = @{}; foreach ($n in [IO.Directory]::GetFiles($O)) { $otherBefore[[IO.Path]::GetFileName($n)] = Sha $n }
    if ($Arc.StartsWith('P\')) { $Arc = $P + $Arc.Substring(1) } elseif ($Arc.StartsWith('O\')) { $Arc = $O + $Arc.Substring(1) }
    $rep = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-Tc $P
        Post-Cmd (Get-Main $id) 842   # select all in the (active) left panel
        Start-Sleep -Milliseconds 600
        $r = & $Do $id
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        Start-Sleep -Milliseconds 500
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
            elseif ($now -ne $otherBefore[$n]) { $loss++;$state += ('out\' + $n + ': ' + $(if ($now) { 'CHANGED' } else { 'GONE' })) } else { $state += ('out\' + $n + ': intact') }
        }
        $res = [pscustomobject]@{ R = $r; Loss = $loss; Intact = $intact; InArc = $inArc; Content = $content; P = (Disk-Names $P); O = (Disk-Names $O); Fatal = $fatal }
        $e = & $Expect $res
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and $loss -eq 0 -and $e[0]
        $msgs = (@($r.Messages | ForEach-Object { if ($_.Length -gt 420) { $_.Substring(0, 420) + '...' } else { $_ } }) -join ' || ')
        Row $Case 'RUN' (V $ok) ("{0} | sources: {1} | loss {2} | archive: {3} [{4}] | P: [{5}] | out: [{6}] | expected: {7} | windows: {8}{9}{10}" -f $What, ($state -join '; '), $loss,
                $(if ($content.Ok) { 'tests OK' } elseif ($content.Note) { $content.Note } else { 'fails' }), ((@($content.Files.Keys) | Sort-Object) -join ','), (Esc $res.P), (Esc $res.O), $e[1],
                $(if ($msgs) { $msgs } else { 'none' }), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $rep } }
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

# ---- main --------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc106_pk_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config; Set-ProbeConfig
    Out ("packself_probe (feature 106) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; 7z {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, (Test-Path -LiteralPath $SevenZip))
    Out ''
    $ZipRx = '^ZIP'; $SzRx = '^7-Zip'
    $two = @(@{ N = 'src.zip'; S = 40000 }, @{ N = 'b.bin'; S = 3000 })

    # ---- A: core "Overwrite" of a selected file
    $aExp = { param($res) @(((Saw $res $Refused) -and $res.Intact -eq 2), 'refused (to itself), both sources intact') }
    Run-Case 'A-zip-same-copy' $two $null { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $false 'over' 0 @(1, 6) } 'P\src.zip' $aExp 'Pack (ZIP) into src.zip = a selected file, Overwrite, copy'
    Run-Case 'A-zip-same-move' $two $null { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $true 'over' 0 @(1, 6) } 'P\src.zip' $aExp 'Pack (ZIP) into src.zip = a selected file, Overwrite, MOVE'
    Run-Case 'A-zip-case-copy' $two $null { param($id) Pack-Dlg $id $ZipRx ($P + '\SRC.ZIP') $false 'over' 0 @(1, 6) } 'P\src.zip' $aExp 'Pack (ZIP) into SRC.ZIP (case), Overwrite, copy'
    $long = @(@{ N = 'longsourcename.zip'; S = 40000 }, @{ N = 'b.bin'; S = 3000 })
    Run-Case 'A-zip-short-move' $long $null { param($id) $s = [IO.Path]::GetFileName([Drv106]::Short($P + '\longsourcename.zip')); Pack-Dlg $id $ZipRx ($P + '\' + $s) $true 'over' 0 @(1, 6) } 'P\longsourcename.zip' $aExp 'Pack (ZIP) into the 8.3 name of the selected file, Overwrite, MOVE'
    Run-Case 'A-zip-unc-move' $two $null { param($id) Pack-Dlg $id $ZipRx (Unc ($P + '\src.zip')) $true 'over' 0 @(1, 6) } 'P\src.zip' $aExp 'Pack (ZIP) into \\localhost\C$\...\src.zip, Overwrite, MOVE'
    $two7 = @(@{ N = 'src.7z'; S = 40000 }, @{ N = 'b.bin'; S = 3000 })
    Run-Case 'A-7z-same-move' $two7 $null { param($id) Pack-Dlg $id $SzRx ($P + '\src.7z') $true 'over' 0 @(1, 6) } 'P\src.7z' $aExp 'Pack (7-Zip) into src.7z = a selected file, Overwrite, MOVE'
    # the archive lies inside a selected FOLDER: deleting it would delete a file of the packed tree
    $dirFiles = @(@{ N = 'b.bin'; S = 3000 })
    $mkDir = { NewDir ($P + '\D'); Rand-File ($P + '\D\x.zip') 30000 55; Rand-File ($P + '\D\c.bin') 2000 56 }
    $aDirExp = { param($res) @(((Saw $res $Refused) -and $res.Intact -eq 3), 'refused (to itself); D\x.zip, D\c.bin and b.bin intact') }
    Run-Case 'A-zip-dir-move' $dirFiles $mkDir { param($id) Pack-Dlg $id $ZipRx ($P + '\D\x.zip') $true 'over' 0 @(1, 6) } 'P\D\x.zip' $aDirExp 'Pack (ZIP) of D + b.bin into D\x.zip (inside the selected folder D), Overwrite, MOVE'
    # "Overwrite" of an existing archive that is NOT one of the sources still works
    $unrel = @(@{ N = 'p.bin'; S = 9000 }, @{ N = 'q.bin'; S = 7000 })
    $aUnExp = { param($res) @(($res.Content.Ok -and $res.Content.Files.Count -eq 2 -and $res.Content.Files.ContainsKey('p.bin') -and $res.R.PackAgain -eq 0), 'overwritten: the new archive holds exactly the two sources') }
    Run-Case 'A-zip-unrelated-over' $unrel { Rand-File ($O + '\old.zip') 5000 66 } { param($id) Pack-Dlg $id $ZipRx ($O + '\old.zip') $false 'over' 0 @(1, 6) } 'O\old.zip' $aUnExp 'Pack (ZIP) into out\old.zip (exists, not selected), Overwrite, copy'
    # review N2: "without asking next time" ticked with a refused Overwrite is not stored - the next
    # Pack into the same name asks again (the build before: refused nothing, so the row shows its loss)
    $noAsk = { param($id)
        $r1 = Pack-Dlg $id $ZipRx ($P + '\src.zip') $false 'over+noask' 0 @(1, 6)
        $r2 = Pack-Dlg $id $ZipRx ($P + '\src.zip') $false 'over' 0 @(1, 6)
        foreach ($m in $r2.Messages) { [void]$r1.Messages.Add('(2nd) ' + $m) }
        $r1.Asked += $r2.Asked; $r1.PackAgain += $r2.PackAgain; if ($r2.Fatal) { $r1.Fatal = $r2.Fatal }; if ($r2.TimedOut) { $r1.TimedOut = $true }
        return $r1 }
    Run-Case 'A-zip-noask-refused' $two $null $noAsk 'P\src.zip' { param($res) @(((Saw $res $Refused) -and $res.Intact -eq 2 -and $res.R.Asked -eq 2), 'refused twice; the question asked again the second time (the tick was not stored)') } 'Pack into src.zip (selected), Overwrite with "without asking next time" ticked, then the same Pack again'

    # ---- B: core "Add" into an existing archive that is a selected file
    $mk = { $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; Remove-Item -LiteralPath ($P + '\src.zip') -Force; Push-Location -LiteralPath $P; try { [void](& $SevenZip a -tzip 'src.zip' 'b.bin' 2>&1) } finally { Pop-Location; $ErrorActionPreference = $old } }
    $mk7 = { $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; Remove-Item -LiteralPath ($P + '\src.7z') -Force; Push-Location -LiteralPath $P; try { [void](& $SevenZip a -t7z 'src.7z' 'b.bin' 2>&1) } finally { Pop-Location; $ErrorActionPreference = $old } }
    $bExp = { param($res) @(($res.Content.Ok), 'no loss; the archive tests OK') }
    Run-Case 'B-zip-add-copy' $two $mk { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $false 'add' 0 @(173, 1, 6) } 'P\src.zip' $bExp 'Pack (ZIP) into the selected existing src.zip, Add, copy (Skip on errors)'
    Run-Case 'B-zip-add-move' $two $mk { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $true 'add' 0 @(173, 1, 6) } 'P\src.zip' $bExp 'Pack (ZIP) into the selected existing src.zip, Add, MOVE (Skip on errors)'
    Run-Case 'B-zip-add-move-inplace' $two { & $mk; Set-BackupZip 0 } { param($id) Pack-Dlg $id $ZipRx ($P + '\src.zip') $true 'add' 0 @(173, 1, 6) } 'P\src.zip' $bExp 'as B-zip-add-move with Backup ZIP off (update in place)'
    Set-BackupZip 1
    Run-Case 'B-7z-add-copy' $two7 $mk7 { param($id) Pack-Dlg $id $SzRx ($P + '\src.7z') $false 'add' 0 @(173, 1, 6) } 'P\src.7z' $bExp 'Pack (7-Zip) into the selected existing src.7z, Add, copy'
    Run-Case 'B-7z-add-move' $two7 $mk7 { param($id) Pack-Dlg $id $SzRx ($P + '\src.7z') $true 'add' 0 @(173, 1, 6) } 'P\src.7z' $bExp 'Pack (7-Zip) into the selected existing src.7z, Add, MOVE'

    # ---- C: multi-volume, a selected source has the FIRST volume's name
    $c = @(@{ N = 'a.z01'; S = 8000 }, @{ N = 'b.bin'; S = 8000 })
    $cExp = { param($res) @(((Saw $res $Refused) -and $res.Intact -eq 2 -and $res.R.OverwriteQ -eq 0), 'refused before any overwrite question, both sources intact') }
    Run-Case 'C-same-copy' $c $null { param($id) Pack-Dlg $id $ZipRx ($P + '\a.zip') $false '' 4 @(138, 1) } 'P\a.zip' $cExp 'multi-volume a.zip (volume 1 = a.z01 = a selected file), copy, overwrite -> Yes'
    Run-Case 'C-same-move' $c $null { param($id) Pack-Dlg $id $ZipRx ($P + '\a.zip') $true '' 4 @(138, 1) } 'P\a.zip' $cExp 'as C-same-copy, MOVE'
    Run-Case 'C-case-copy' $c $null { param($id) Pack-Dlg $id $ZipRx ($P + '\A.ZIP') $false '' 4 @(138, 1) } 'P\A.zip' $cExp 'multi-volume A.ZIP (volume A.z01), copy'
    Run-Case 'C-short-move' $c $null { param($id) Pack-Dlg $id $ZipRx ([Drv106]::Short($P) + '\a.zip') $true '' 4 @(138, 1) } 'P\a.zip' $cExp 'multi-volume through the folder 8.3 name, MOVE'
    Run-Case 'C-unc-copy' $c $null { param($id) Pack-Dlg $id $ZipRx (Unc ($P + '\a.zip')) $false '' 4 @(138, 1) } 'P\a.zip' $cExp 'multi-volume through \\localhost\C$, copy'
    Run-Case 'C-unc-move' $c $null { param($id) Pack-Dlg $id $ZipRx (Unc ($P + '\a.zip')) $true '' 4 @(138, 1) } 'P\a.zip' $cExp 'multi-volume through \\localhost\C$, MOVE'

    # a volume name that is a HARD LINK of a selected source in another folder (mklink /H)
    $hl = @(@{ N = 'x.bin'; S = 8000 }, @{ N = 'b.bin'; S = 8000 })
    $mkHl = { [void](& cmd.exe /c ('mklink /H "{0}" "{1}"' -f ($O + '\h.z01'), ($P + '\x.bin')) 2>&1) }
    $hlExp = { param($res) @(((Saw $res $Refused) -and $res.Intact -eq 2 -and $res.R.OverwriteQ -eq 0), 'refused before any overwrite question (out\h.z01 is a hard link of x.bin), sources intact') }
    Run-Case 'C-hardlink-copy' $hl $mkHl { param($id) Pack-Dlg $id $ZipRx ($O + '\h.zip') $false '' 4 @(138, 1) } 'O\h.zip' $hlExp 'multi-volume out\h.zip; out\h.z01 is a hard link of the selected x.bin, copy, overwrite -> Yes'
    # review SF-1: the hard link written through after the folder was listed - the panel lists x.bin
    # with its stale size (NTFS updates the entry of the name written through only)
    $mkHlStale = { & $mkHl; $fs = [IO.File]::Open(($O + '\h.z01'), 'Append', 'Write'); $fs.Write((New-Object byte[] 3000), 0, 3000); $fs.Close() }
    Run-Case 'C-hardlink-stale' $hl $mkHlStale { param($id) Pack-Dlg $id $ZipRx ($O + '\h.zip') $false '' 4 @(138, 1) } 'O\h.zip' $hlExp 'as C-hardlink-copy, 3,000 bytes appended through out\h.z01 after the panel listed x.bin (stale listed size), overwrite -> Yes'

    # ---- D: a selected source has a LATER volume's name (created while packing)
    $dd = @(@{ N = 'a.z04'; S = 8000 }, @{ N = 'b.bin'; S = 12000 })
    $ddExp = { param($res) @(((Saw $res $Refused) -and $res.Intact -eq 2 -and $res.R.OverwriteQ -eq 0), 'refused at volume 4 before its overwrite question, both sources intact (volumes 1-3 of the refused archive stay, as after any failed multi-volume pack)') }
    Run-Case 'D-later-copy' $dd $null { param($id) Pack-Dlg $id $ZipRx ($P + '\a.zip') $false '' 4 @(138, 1) } 'P\a.zip' $ddExp 'multi-volume a.zip, volume 4 = a.z04 = a selected file, copy, overwrite -> Yes'
    Run-Case 'D-later-move' $dd $null { param($id) Pack-Dlg $id $ZipRx ($P + '\a.zip') $true '' 4 @(138, 1) } 'P\a.zip' $ddExp 'as D-later-copy, MOVE'

    # ---- E: an unrelated existing volume name in the target folder, the question answered Cancel
    $e = @(@{ N = 'x.bin'; S = 12000 })
    $eExp = { param($res) @(($res.R.OverwriteQ -ge 1), 'the overwrite question was asked; the declined file stays') }
    Run-Case 'E-decline-vol2' $e { Rand-File ($O + '\a.z02') 5000 77 } { param($id) Pack-Dlg $id $ZipRx ($O + '\a.zip') $false '' 4 @(2) } 'O\a.zip' $eExp 'multi-volume into out\a.zip, out\a.z02 exists (not selected), overwrite -> Cancel'
    Run-Case 'E-decline-vol1' $e { Rand-File ($O + '\a.z01') 5000 78 } { param($id) Pack-Dlg $id $ZipRx ($O + '\a.zip') $false '' 4 @(2) } 'O\a.zip' $eExp 'multi-volume into out\a.zip, out\a.z01 exists (not selected), overwrite -> Cancel'

    # ---- F / G: ordinary packing still works
    $fg = @(@{ N = 'p.bin'; S = 9000 }, @{ N = 'q.bin'; S = 7000 })
    $okExp = { param($res) @(($res.Content.Ok -and $res.Content.Files.Count -eq 2), 'packed, the archive tests OK and holds both files') }
    Run-Case 'F-multivol-copy' $fg $null { param($id) Pack-Dlg $id $ZipRx ($O + '\m.zip') $false '' 4 @(1) } 'O\m.zip' $okExp 'multi-volume into out\m.zip, no collision, copy'
    Run-Case 'F-multivol-move' $fg $null { param($id) Pack-Dlg $id $ZipRx ($O + '\m.zip') $true '' 4 @(1) } 'O\m.zip' $okExp 'multi-volume into out\m.zip, no collision, MOVE'
    Run-Case 'G-plain-copy' $fg $null { param($id) Pack-Dlg $id $ZipRx ($O + '\n.zip') $false '' 0 @(1) } 'O\n.zip' $okExp 'plain ZIP into out\n.zip, copy'
    Run-Case 'G-plain-move' $fg $null { param($id) Pack-Dlg $id $ZipRx ($O + '\n.zip') $true '' 0 @(1) } 'O\n.zip' $okExp 'plain ZIP into out\n.zip, MOVE'
    Run-Case 'G-plain-7z' $fg $null { param($id) Pack-Dlg $id $SzRx ($O + '\n.7z') $true '' 0 @(1) } 'O\n.7z' $okExp 'plain 7-Zip into out\n.7z, MOVE'

    # ---- H: F5 / F6 into the archive shown in the right panel, which is one of the selected files
    $hRun = {
        param([string]$Case, [string]$Ext, [bool]$Move, [scriptblock]$Mk)
        $files = @(@{ N = ('src.' + $Ext); S = 100 }, @{ N = 'b.bin'; S = 3000 })
        $save = $StartDir
        Run-Case $Case $files { & $Mk; $script:StartDir = $P + '\src.' + $Ext } { param($id) Copy-Dlg $id $Move @(173, 1, 6) } ('P\src.' + $Ext) $bExp ('F' + $(if ($Move) { '6' } else { '5' }) + ' of src.' + $Ext + ' + b.bin into src.' + $Ext + ' (right panel)')
        $script:StartDir = $save
    }
    & $hRun 'H-zip-copy' 'zip' $false $mk
    & $hRun 'H-zip-move' 'zip' $true $mk
    & $hRun 'H-7z-copy' '7z' $false $mk7
    & $hRun 'H-7z-move' '7z' $true $mk7

    Row 'X-sfx' 'RUN' 'NOT DRIVEN' 'self-extracting archive (PackSelfExtract, PackMultiVol + SFX): no sfx package is shipped, the option is disabled ("no SFX installed") - same check compiled in, not reachable'
    Row 'X-rar' 'RUN' 'NOT DRIVEN' 'the RAR external packer: WinRAR is not installed here; the core refusal of route A runs before any packer'
    Row 'X-removable' 'RUN' 'NOT DRIVEN' 'multi-volume onto removable media (disk changes): no removable drive; the same CreateNextFile check applies'
    Row 'X-drag' 'RUN' 'NOT DRIVEN' 'drag and drop into an archive panel: the same core packer call as F5/F6 (route H), no overwrite question'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
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
