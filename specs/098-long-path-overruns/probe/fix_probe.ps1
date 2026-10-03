<#
.SYNOPSIS
    Feature 098 probe (stages S1-S4): long paths after the fixes, with the build
    before the feature (Debug_x64_pre098) as the negative control.

.DESCRIPTION
    D1  directory line: chains of disk folders of about 8,000 / 15,000 / 32,000
        UTF-16 units (ASCII 'p' and three-byte U+20AC components of 200
        characters; the last six components are 20 characters, so the visible
        tail of the directory line shows several of them). Per case:
          GO     Change Directory to the deepest folder (wide WM_SETTEXT)
          PATH   the location read back from the Change Directory field
          CLICK  a hot-track click on the directory line just right of the
                 "root..." ellipsis (WM_MOUSEMOVE + WM_LBUTTONDOWN/UP posted to
                 the directory-line window): the panel must land on a folder
                 of the chain that is a proper prefix at a component boundary,
                 inside the visible tail (not the root, not the last component)
          UP     Backspace up to the root of the chain, the location read back
          END    alive, WM_NULL answered, no stray window, no new crash report,
                 exit code 0
        The directory-line text itself cannot be read (custom window without a
        window text) - the location comes from the Change Directory field.
    D2  Change Directory with the full path of a FILE of 300 / 1,000 bytes
        (ASCII, and with U+0159 folders): the panel is in the folder (read
        back) and the file is focused (F3: the viewer title names the file).
        PASTE: a 600-byte path on the clipboard, CM_CLIPPASTE (775): one "too
        long" message, the panel unchanged; PASTEU / PASTEC: a short path with
        U+0159 / with U+4E2D: the panel lands there. The user's clipboard text
        is saved and restored; when the clipboard holds anything but text the
        paste rows are not driven.
    D4  packing from a source folder of 300 / 1,000 bytes (ASCII and U+0159)
        holding a.txt, sub1\b.txt, sub1\sub2\c.txt (accented variant: the last
        one is sub1\sub2\U+010D.txt): select all (842), Alt+F5 (850) into a new
        ZIP / 7z archive at a short path with the plug-in packer; and F5 (727)
        of the selection into an existing archive "<arc>\". Read back with
        7z.exe: every file present, content equal.
    D3  an ISO image (IMAPI2) at a path of about 2,100 bytes: F3 (the UnISO
        viewer: no run-time check, the caption); a 7z with one store-only item
        made corrupt (CRC): unpack (851): the plug-in's error message names the
        item (the bounded format of extract.cpp).

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while another
    tandemcommander.exe runs. HKCU\Software\Tandem Commander exported before
    and restored + SHA-256-verified after. Scratch: %TEMP%\tc098_fix (removed).

.NOTES
    Windows PowerShell 5.1; pure ASCII. Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe',
    [int]$ClickX = 90
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot 'fix_probe_lib.ps1')

# ---- D1 ----------------------------------------------------------------------
# chain root\<200 x ch>\...\<20 x ch> x6 with a total length of about $Units UTF-16 units
function Chain([string]$Base, [string]$Ch, [int]$Units) {
    $short = @(1..6 | ForEach-Object { ([string]$_) + ($Ch * 19) })
    $tailLen = 6 * 21
    $p = $Base
    while ($p.Length + 201 + $tailLen -le $Units) { $p += '\' + ($Ch * 200) }
    $rest = $Units - $tailLen - $p.Length - 1
    if ($rest -gt 0) { $p += '\' + ($Ch * [Math]::Min($rest, 200)) }
    foreach ($s in $short) { $p += '\' + $s }
    return $p
}
function Run-D1([string]$Case, [string]$Ch, [int]$Units) {
    $base = $Root + '\d1' + $Case
    $deep = Chain $base $Ch $Units
    NewDir $deep
    $comps = $deep.Substring($base.Length + 1).Split('\').Count
    Out ("--- {0}: chain of {1} components, deepest {2} UTF-16 units / {3} bytes" -f $Case, $comps, $deep.Length, (U8Len $deep))
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-Tc $StartDir
        $held = Do-ChangeDir $id $deep
        $r = Serve $id 60
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        Row $Case 'GO' (V (-not $fatal -and -not $r.Died)) ("field held the text: {0}; windows: {1}{2}" -f $held, (Msgs $r), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
        if ($fatal -or $r.Died) { return }
        $loc = Get-Loc $id
        Row $Case 'PATH' (V ($loc -ceq $deep)) ("location {0} units: {1}" -f $loc.Length, (Tail $loc))
        # CLICK: on the directory line just right of the drive toolbar and "root..."
        $line = Find-DirLine $id
        if ($line -eq [IntPtr]::Zero) { Row $Case 'CLICK' 'NOT DRIVEN' 'directory-line window not found' }
        else {
            $cr = New-Object Drv098f+RECT; [void][Drv098f]::GetClientRect($line, [ref]$cr)
            $x = $ClickX; $y = [int](($cr.Bottom - $cr.Top) / 2)
            Post-Click $line $x $y
            Start-Sleep -Milliseconds 800
            $r = Serve $id 30
            $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
            if ($fatal) { Row $Case 'CLICK' 'FAIL' ('FATAL ' + $fatal); return }
            $loc2 = Get-Loc $id
            $isPrefix = $loc2.Length -lt $deep.Length -and $deep.StartsWith($loc2, [StringComparison]::Ordinal) -and $deep[$loc2.Length] -eq '\'
            $up = 0; if ($isPrefix) { $up = $deep.Substring($loc2.Length).Split('\').Count - 1 }
            # the visible tail of the line is the same text at every depth (the six short components),
            # so the click must land as many components up as in the shallow reference case
            $refKey = $Ch
            if ($Units -le 2000) { $script:ClickRef[$refKey] = $up }
            $ref = $script:ClickRef[$refKey]
            $okClick = $isPrefix -and $up -ge 1 -and $loc2.Length -gt $base.Length -and ($null -eq $ref -or $up -eq $ref)
            Row $Case 'CLICK' (V $okClick) ("client width {0} px, click x={1}; landed {2} component(s) above the deepest ({3} units shorter){4}; windows: {5}; location {6}" -f ($cr.Right - $cr.Left), $x, $up, ($deep.Length - $loc2.Length), $(if ($null -ne $ref) { '; reference ' + $ref } else { '' }), (Msgs $r), (Tail $loc2))
            if (-not $isPrefix) { $loc2 = $deep }
            # UP: Backspace to the root of the chain
            $steps = $loc2.Substring($base.Length).Split('\').Count - 1
            for ($i = 0; $i -lt $steps; $i++) {
                Key $id 0x08
                if (($i % 20) -eq 19) { $f = Fatal-Win $id; if ($f) { $fatal = $f; break } }
            }
            if (-not $fatal) { $f = Fatal-Win $id; if ($f) { $fatal = $f } }
            if ($fatal) { Row $Case 'UP' 'FAIL' ('FATAL ' + $fatal); return }
            $loc3 = Get-Loc $id
            Row $Case 'UP' (V ($loc3 -ceq $base)) ("{0} x Backspace; location {1}" -f $steps, (Tail $loc3))
        }
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- D2 ----------------------------------------------------------------------
function Run-D2([string]$Case, [string]$Ch, [int]$Bytes) {
    $base = $Root + '\d2' + $Case
    $per = U8Len $Ch
    $dir = $base
    $need = $Bytes - (U8Len $base) - 6   # '\f.txt'
    while ($need -gt 0) {
        $k = [Math]::Min(200, [Math]::Floor(($need - 1) / $per))
        if ($k -lt 1) { $dir += '\' + ('x' * ($need - 1)); break }
        $dir += '\' + ($Ch * $k); $need -= (1 + $k * $per)
        if ($need -gt 0 -and $need -lt 2) { $dir += 'x'; $need-- }
    }
    NewDir $dir
    $file = $dir + '\f.txt'
    WriteFile $file "f`r`n"
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-Tc $StartDir
        $held = Do-ChangeDir $id $file
        $r = Serve $id 30
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        Row $Case 'GO' (V (-not $fatal)) ("file path {0} bytes / {1} units; field held the text: {2}; windows: {3}{4}" -f (U8Len $file), $file.Length, $held, (Msgs $r), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
        if ($fatal) { return }
        $loc = Get-Loc $id
        Row $Case 'FOLDER' (V ($loc -ceq $dir)) ("location {0}" -f (Tail $loc))
        $vt = Which-Viewer $id
        Row $Case 'FOCUS' (V ($vt -match 'f\.txt' -and $vt -notmatch '^<')) ("viewer title: {0}" -f (Tail $vt 80))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}
function Run-Paste([string]$Case, [string]$Target, [bool]$ExpectRefusal) {
    if (-not $script:ClipOk) { Row $Case 'PASTE' 'NOT DRIVEN' 'the clipboard cannot be opened from this session (OpenClipboard: access denied) - read only'; return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-Tc $StartDir
        $loc0 = Get-Loc $id
        [Windows.Forms.Clipboard]::SetText($Target)
        Post-Cmd (Get-Main $id) 775
        Start-Sleep -Milliseconds 800
        $r = Serve $id 30
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $loc1 = Get-Loc $id
        $refused = @($r.Messages | Where-Object { $_ -match 'too long' }).Count
        if ($ExpectRefusal) { $ok = (-not $fatal) -and $refused -eq 1 -and $r.Messages.Count -eq 1 -and ($loc1 -ceq $loc0) }
        else { $ok = (-not $fatal) -and $r.Messages.Count -eq 0 -and ($loc1 -ceq $Target) }
        Row $Case 'PASTE' (V $ok) ("pasted {0} bytes / {1} units; windows: {2}; location before {3}, after {4}{5}" -f (U8Len $Target), $Target.Length, (Msgs $r), (Tail $loc0 30), (Tail $loc1 40), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- D4 ----------------------------------------------------------------------
function SrcDir([string]$Case, [string]$Ch, [int]$Bytes) {
    $base = $Root + '\d4' + $Case
    $per = U8Len $Ch
    $dir = $base; $need = $Bytes - (U8Len $base)
    while ($need -gt 0) {
        $k = [Math]::Min(200, [Math]::Floor(($need - 1) / $per))
        if ($k -lt 1) { $dir += '\' + ('x' * ($need - 1)); break }
        $dir += '\' + ($Ch * $k); $need -= (1 + $k * $per)
        if ($need -gt 0 -and $need -lt 2) { $dir += 'x'; $need-- }
    }
    return $dir
}
function Make-Src([string]$Dir, [bool]$Accented) {
    NewDir ($Dir + '\sub1\sub2')
    WriteFile ($Dir + '\a.txt') "content of a`r`n"
    WriteFile ($Dir + '\sub1\b.txt') "content of b`r`n"
    $c = 'c.txt'; if ($Accented) { $c = $Cc + '.txt' }
    WriteFile ($Dir + '\sub1\sub2\' + $c) "content of c`r`n"
    return @{ 'a.txt' = "content of a`r`n"; 'sub1/b.txt' = "content of b`r`n"; ('sub1/sub2/' + $c) = "content of c`r`n" }
}
function Read-Back([string]$Arc, $Expect) {
    $x = $OutDir + '\x_' + [IO.Path]::GetFileNameWithoutExtension($Arc)
    if ([IO.Directory]::Exists($x)) { [IO.Directory]::Delete($x, $true) }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $SevenZip x $Arc ('-o' + $x) -y 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0 -or -not [IO.Directory]::Exists($x)) { return [pscustomobject]@{ Ok = $false; Text = ('7z x rc ' + $rc) } }
    $files = @([IO.Directory]::GetFiles($x, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($x.Length + 1).Replace('\', '/') } | Sort-Object)
    $missing = @(); $wrong = @()
    foreach ($k in $Expect.Keys) {
        $p = $x + '\' + $k.Replace('/', '\')
        if (-not [IO.File]::Exists($p)) { $missing += $k } elseif ([IO.File]::ReadAllText($p) -cne $Expect[$k]) { $wrong += $k }
    }
    return [pscustomobject]@{ Ok = ($missing.Count -eq 0 -and $wrong.Count -eq 0); Text = ('archive holds [{0}]; missing [{1}]; content differs [{2}]' -f ((($files | ForEach-Object { Esc $_ }) -join ', ')), (($missing | ForEach-Object { Esc $_ }) -join ', '), (($wrong | ForEach-Object { Esc $_ }) -join ', ')) }
}
function Run-D4([string]$Case, [string]$Ch, [int]$Bytes, [string]$Fmt, [string]$Mode) {
    $dir = SrcDir ($Case) $Ch $Bytes
    $expect = Make-Src $dir ($Ch -ne 'p')
    $arc = $OutDir + '\' + $Case + '.' + $Fmt
    if ($Mode -eq 'copy') {
        # an existing archive with seed.txt as the target of F5
        $seedDir = $OutDir + '\seed_' + $Case; NewDir $seedDir; WriteFile ($seedDir + '\seed.txt') "seed`r`n"
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        Push-Location -LiteralPath $seedDir
        try { $o = & $SevenZip a ('-t' + $Fmt) $arc 'seed.txt' 2>&1 } finally { Pop-Location; $ErrorActionPreference = $old }
        $expect['seed.txt'] = "seed`r`n"
    }
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-Tc $StartDir
        $held = Do-ChangeDir $id $dir
        $r = Serve $id 30
        $fatal = $r.Fatal; if ($fatal) { Row $Case 'GO' 'FAIL' ('FATAL ' + $fatal); return }
        Post-Cmd (Get-Main $id) 842   # select all
        Start-Sleep -Milliseconds 500
        if ($Mode -eq 'pack') {
            $dlg = Open-ByCmd $id 850
            if ($dlg -eq [IntPtr]::Zero) { throw 'Pack (850) opened no window' }
            $packer = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 511 }) | Select-Object -First 1
            $items = @()
            if ($packer) {
                $res = [IntPtr]::Zero; [void][Drv098f]::SendMessageTimeoutW($packer, 0x0146, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)
                for ($i = 0; $i -lt [int]$res.ToInt64(); $i++) {
                    $buf = New-Object char[] 512; $r2 = [IntPtr]::Zero
                    [void][Drv098f]::SendGetText($packer, 0x0148, [IntPtr]$i, $buf, 0, 5000, [ref]$r2)
                    $items += (New-Object string($buf, 0, [Math]::Max(0, [int]$r2.ToInt64())))
                }
            }
            $rx = '^ZIP'; if ($Fmt -eq '7z') { $rx = '^7' }
            $ix = -1; for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i] -match $rx -and $items[$i] -match '(?i)plug') { $ix = $i; break } }
            if ($ix -lt 0) { Close-Win $dlg; throw ('no plug-in packer for ' + $Fmt + ' among: ' + ($items -join ' ; ')) }
            [void][Drv098f]::Send($packer, 0x014E, $ix, 0, 5000)
            [void][Drv098f]::Send($dlg, 0x0111, ((1 -shl 16) -bor 511), $packer.ToInt64(), 5000)
            [void][Drv098f]::SetText((Find-Ctl $dlg 210), $arc, 5000)
            Click-Ok $dlg
            $how = 'Alt+F5 into ' + $items[$ix]
        }
        else {
            $dlg = Open-ByCmd $id 727
            if ($dlg -eq [IntPtr]::Zero) { throw 'Copy (727) opened no window' }
            [void][Drv098f]::SetText((Find-Ctl $dlg 210), ($arc + '\'), 5000)
            Click-Ok $dlg
            $how = 'F5 into "' + $Case + '.' + $Fmt + '\"'
        }
        Start-Sleep -Milliseconds 800
        $r = Serve $id 90
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $rb = Read-Back $arc $expect
        $opts = @($r.Messages | Where-Object { $_ -match "^\[#32770 '(Create New Archive|Add Files to Archive)'\]" })
        $other = @($r.Messages | Where-Object { $_ -notmatch "^\[#32770 '(Create New Archive|Add Files to Archive)'\]" })
        Row $Case 'PACK' (V ((-not $fatal) -and $rb.Ok -and $other.Count -eq 0)) ("source {0} bytes; {1}; {2}; packer options dialog answered OK: {3}; other windows: {4}{5}" -f (U8Len $dir), $how, $rb.Text, $opts.Count, $(if ($other.Count) { $other -join ' || ' } else { 'none' }), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- D3 ----------------------------------------------------------------------
function Run-Iso([string]$Case, [string]$Ch, [int]$Bytes) {
    $st = $Root + '\isostage'; NewDir $st; WriteFile ($st + '\readme.txt') "iso content`r`n"
    $iso = $OutDir + '\img.iso'
    if (-not [IO.File]::Exists($iso)) {
        $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
        $fsi.FileSystemsToCreate = 1
        $fsi.Root.AddTree($st, $false)
        [Drv098f]::SaveStream($fsi.CreateResultImage().ImageStream, $iso)
    }
    $dir = SrcDir ('3' + $Case) $Ch ($Bytes - 8)
    NewDir $dir
    [IO.File]::Copy($LP + $iso, $LP + $dir + '\img.iso', $true)
    $full = $dir + '\img.iso'
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-Tc $StartDir
        [void](Do-ChangeDir $id $dir)
        $r = Serve $id 30
        $fatal = $r.Fatal; if ($fatal) { Row $Case 'VIEW' 'FAIL' ('FATAL ' + $fatal); return }
        Key $id 0x23
        $vt = Which-Viewer $id
        $f = Fatal-Win $id; if ($f) { $fatal = $f }
        Row $Case 'VIEW' (V ((-not $fatal) -and $vt -notmatch '^<')) ("ISO {0} bytes / {1} units; viewer title ({2} units): {3}" -f (U8Len $full), $full.Length, $vt.Length, (Tail $vt 90))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}
function Run-Crc([string]$Case) {
    $st = $Root + '\crcstage'
    $rel = (('L' * 60) + '\' + ('M' * 60)) + '\item.bin'
    NewDir ($st + '\' + ('L' * 60) + '\' + ('M' * 60))
    $bytes = New-Object byte[] 4096; (New-Object Random 98).NextBytes($bytes)
    [IO.File]::WriteAllBytes($LP + $st + '\' + $rel, $bytes)
    $panel = $Root + '\d3crc'; NewDir $panel
    $arc = $panel + '\crc.7z'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $st
    try { $o = & $SevenZip a -t7z -mx0 $arc ('L' * 60) -r 2>&1 } finally { Pop-Location; $ErrorActionPreference = $old }
    $raw = [IO.File]::ReadAllBytes($arc)
    for ($i = 64; $i -lt 64 + 128; $i++) { $raw[$i] = $raw[$i] -bxor 0x5A }
    [IO.File]::WriteAllBytes($arc, $raw)
    $x = $OutDir + '\crcx'; NewDir $x
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-Tc $panel
        Key $id 0x23
        $dlg = Open-ByCmd $id 851
        if ($dlg -eq [IntPtr]::Zero) { throw 'Unpack (851) opened no window' }
        [void][Drv098f]::SetText((Find-Ctl $dlg 210), $x, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 60 @(7, 1, 6)   # Keep (No) for the plug-in's delete-or-keep question
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $named = @($r.Messages | Where-Object { $_ -match 'item\.bin' -and $_ -match ('L{60}') }).Count
        Row $Case 'CRC' (V ((-not $fatal) -and $named -ge 1)) ("item path in the archive {0} bytes; message naming the whole item path: {1}; windows: {2}" -f (U8Len $rel), $named, (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- D5: review B1 - Move to archive with a junction in the selection ---------------
# S\A: 1,005 levels of "d" (sep: S\B holds the junction J -> X; same: the junction is A\J);
# ctl: no deep tree, only S\B\J. Alt+F5 with "Delete files from disk after packing" (512):
# the link warning must appear and X\x.txt must survive. f6: F6 (728) of S\B into an existing
# archive - that route never had a link check (informative, both builds).
$script:Junctions = New-Object System.Collections.ArrayList
function New-Junction([string]$Link, [string]$Target) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c "mklink /J `"$Link`" `"$Target`"" 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ('mklink /J failed: ' + ($o -join ' ')) }
    [void]$script:Junctions.Add($Link)
}
function Remove-Junctions {
    foreach ($j in @($script:Junctions)) {
        if ([IO.Directory]::Exists($j)) { & cmd.exe /c "rmdir `"$j`"" | Out-Null }
        if ([IO.Directory]::Exists($j)) { Out ('Junction: COULD NOT REMOVE ' + $j) }
    }
    $script:Junctions.Clear()
}
function Select-Packer([IntPtr]$Dlg, [string]$Fmt) {
    $packer = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 511 }) | Select-Object -First 1
    $items = @()
    $res = [IntPtr]::Zero; [void][Drv098f]::SendMessageTimeoutW($packer, 0x0146, [IntPtr]::Zero, [IntPtr]::Zero, 0, 5000, [ref]$res)
    for ($i = 0; $i -lt [int]$res.ToInt64(); $i++) {
        $buf = New-Object char[] 512; $r2 = [IntPtr]::Zero
        [void][Drv098f]::SendGetText($packer, 0x0148, [IntPtr]$i, $buf, 0, 5000, [ref]$r2)
        $items += (New-Object string($buf, 0, [Math]::Max(0, [int]$r2.ToInt64())))
    }
    $rx = '^ZIP'; if ($Fmt -eq '7z') { $rx = '^7' }
    $ix = -1; for ($i = 0; $i -lt $items.Count; $i++) { if ($items[$i] -match $rx -and $items[$i] -match '(?i)plug') { $ix = $i; break } }
    if ($ix -lt 0) { throw ('no plug-in packer for ' + $Fmt) }
    [void][Drv098f]::Send($packer, 0x014E, $ix, 0, 5000)
    [void][Drv098f]::Send($Dlg, 0x0111, ((1 -shl 16) -bor 511), $packer.ToInt64(), 5000)
    return $items[$ix]
}
function Run-Junction([string]$Case, [string]$Fmt, [string]$Variant) {
    $base = $Root + '\' + $Case
    $src = $base + '\S'
    $x = $base + '\X'
    NewDir $x; WriteFile ($x + '\x.txt') "outside the selection`r`n"
    if ($Variant -ne 'ctl' -and $Variant -ne 'f6') {
        $deep = $src + '\A' + ('\d' * 1005)
        NewDir $deep; WriteFile ($deep + '\deep.txt') "deep`r`n"
        WriteFile ($src + '\A\a.txt') "a`r`n"
    }
    if ($Variant -eq 'same') { New-Junction ($src + '\A\J') $x }
    else { NewDir ($src + '\B'); WriteFile ($src + '\B\b.txt') "b`r`n"; New-Junction ($src + '\B\J') $x }
    $arc = $OutDir + '\' + $Case + '.' + $Fmt
    if ($Variant -eq 'f6') {
        $seedDir = $OutDir + '\seed_' + $Case; NewDir $seedDir; WriteFile ($seedDir + '\seed.txt') "seed`r`n"
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        Push-Location -LiteralPath $seedDir
        try { $o = & $SevenZip a ('-t' + $Fmt) $arc 'seed.txt' 2>&1 } finally { Pop-Location; $ErrorActionPreference = $old }
    }
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-Tc $src
        Post-Cmd (Get-Main $id) 842   # select all
        Start-Sleep -Milliseconds 500
        if ($Variant -eq 'f6') {
            $dlg = Open-ByCmd $id 728
            if ($dlg -eq [IntPtr]::Zero) { throw 'Move (728) opened no window' }
            [void][Drv098f]::SetText((Find-Ctl $dlg 210), ($arc + '\'), 5000)
            Click-Ok $dlg
            $how = 'F6 (move) into "' + $Case + '.' + $Fmt + '\"'
        }
        else {
            $dlg = Open-ByCmd $id 850
            if ($dlg -eq [IntPtr]::Zero) { throw 'Pack (850) opened no window' }
            $pk = Select-Packer $dlg $Fmt
            [void][Drv098f]::SetText((Find-Ctl $dlg 210), $arc, 5000)
            $mv = @([Drv098f]::Kids($dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 512 }) | Select-Object -First 1
            [void][Drv098f]::Send($mv, 0x00F1, 1, 0, 5000)   # BM_SETCHECK: delete files after packing
            Click-Ok $dlg
            $how = 'Alt+F5 into ' + $pk + ' with "delete files after packing"'
        }
        Start-Sleep -Milliseconds 800
        $r = Serve $id 120
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $warned = @($r.Messages | Where-Object { $_ -match 'link to directory' }).Count
        $tooLong = @($r.Messages | Where-Object { $_ -match 'too long' }).Count
        $xAlive = [IO.File]::Exists($LP + $x + '\x.txt')
        $srcLeft = @(); foreach ($n in 'A', 'B') { if ([IO.Directory]::Exists($LP + $src + '\' + $n)) { $srcLeft += $n } }
        $names = '(no archive)'
        if ([IO.File]::Exists($arc)) {
            $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            $l = & $SevenZip l -ba -slt $arc 2>&1; $ErrorActionPreference = $old
            $names = (@($l | Where-Object { $_ -match '^Path = ' } | ForEach-Object { ($_ -replace '^Path = ', '') } | Where-Object { $_ -notmatch '\\d\\d\\d' }) -join ', ')
        }
        $msgs = (@($r.Messages | ForEach-Object { if ($_.Length -gt 140) { $_.Substring(0, 140) + '...' } else { $_ } }) -join ' || ')
        $facts = ("{0}; link warning shown {1}; 'too long' messages {2}; X\x.txt survives: {3}; left in S: [{4}]; archive (deep chain omitted): [{5}]; windows: {6}{7}" -f $how, $warned, $tooLong, $xAlive, ($srcLeft -join ','), (Esc $names), $msgs, $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
        if ($Variant -eq 'f6') { Row $Case 'MOVE' 'INFO' $facts }
        else { Row $Case 'MOVE' (V ((-not $fatal) -and $xAlive -and $warned -ge 1)) $facts }
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally { if ($id) { End-Row $Case $id $fatal $before }; Remove-Junctions }
}

# ---- main --------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc098_fix_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir
    Set-Config
    Out ("fix_probe (feature 098) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Save-Clip
    Out ''
    $script:ClickRef = @{}
    # WARM-UP: the first posted click of a run on a fresh hidden desktop has been seen to do nothing
    # (in both builds); one throwaway click in a throwaway instance first
    if (-not $Only -or @($Only | Where-Object { $_ -like 'd1*' }).Count -gt 0) {
        $wid = 0
        try {
            $wid = Start-Tc $StartDir
            $wl = Find-DirLine $wid
            if ($wl -ne [IntPtr]::Zero) { Post-Click $wl $ClickX 10; Start-Sleep -Milliseconds 800; $wr = Serve $wid 15 }
            Out ('warm-up: one click posted to the directory line of a throwaway instance')
        }
        catch { Out ('warm-up failed: ' + $_.Exception.Message) }
        finally { if ($wid) { $b = Reports; Stop-Tc $wid; [void](Take-Reports $b) } }
    }
    foreach ($c in @(@('a1k5', 'p', 1500), @('a8k', 'p', 8000), @('a15k', 'p', 15000), @('a32k', 'p', 32000), @('e1k5', $Euro, 1500), @('e8k', $Euro, 8000), @('e15k', $Euro, 15000), @('e32k', $Euro, 32000))) {
        if (Want ('d1' + $c[0])) { Run-D1 ('d1' + $c[0]) $c[1] $c[2] }
    }
    foreach ($c in @(@('a300', 'p', 300), @('a1000', 'p', 1000), @('u300', $Rz, 300), @('u1000', $Rz, 1000))) {
        if (Want ('d2' + $c[0])) { Run-D2 ('d2' + $c[0]) $c[1] $c[2] }
    }
    if (Want 'd2paste') {
        $p600 = $Root + '\d2paste'; while ((U8Len $p600) -lt 600) { $p600 += '\' + ('q' * [Math]::Min(150, 600 - (U8Len $p600) - 1)) }
        NewDir $p600
        Run-Paste 'd2paste' $p600 $true
        $pu = $Root + '\paste' + $Rz; NewDir $pu; Run-Paste 'd2pasteu' $pu $false
        $pc = $Root + '\paste' + $Zh; NewDir $pc; Run-Paste 'd2pastec' $pc $false
    }
    foreach ($c in @(@('a300', 'p', 300), @('a1000', 'p', 1000), @('u300', $Rz, 300), @('u1000', $Rz, 1000))) {
        foreach ($fmt in 'zip', '7z') {
            foreach ($mode in 'pack', 'copy') {
                $n = 'd4' + $c[0] + $fmt + $mode.Substring(0, 1)
                if (Want $n) { Run-D4 $n $c[1] $c[2] $fmt $mode }
            }
        }
    }
    if (Want 'd3isoa') { Run-Iso 'd3isoa' 'p' 2100 }
    if (Want 'd3isoe') { Run-Iso 'd3isoe' $Euro 2100 }
    if (Want 'd3crc') { Run-Crc 'd3crc' }
    foreach ($v in 'sep', 'same', 'ctl') { foreach ($fmt in 'zip', '7z') { $n = 'd5' + $v + $fmt; if (Want $n) { Run-Junction $n $fmt $v } } }
    if (Want 'd5f6zip') { Run-Junction 'd5f6zip' 'zip' 'f6' }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    Restore-Clip
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { Remove-Junctions } catch { Out ('Junctions: ' + $_.Exception.Message) }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count; $ni = @($script:Rows | Where-Object { $_.Verdict -eq 'INFO' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}, INFO {6}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored, $ni)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
