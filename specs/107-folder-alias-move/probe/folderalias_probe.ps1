<#
.SYNOPSIS
    Feature 107 probe: copying or moving a FOLDER onto another path of ITSELF (its own
    place, into itself, into one of its own subfolders) must never delete or change the
    source tree; a hard link reached through an alias is "the same file"; ordinary folder
    copies and moves between two really different folders work as before.

.DESCRIPTION
    Fixtures under %TEMP%\tc107\fa (removed at the end). The source tree (in every case):
        <case>\parentlong\F\a.txt, F\sub\b.txt, F\sub\deep\ (empty), F\empty\ (empty),
        F\<Cyrillic folder>\c.txt
    Shapes (the target folder T the copy/move goes INTO; F is placed as T\F):
        a   T = F itself                  (F into itself: T\F = F\F)
        b   T = the parent of F           (F onto itself, "the same place": T\F = F)
        c   T = F\sub                     (F into one of its own subfolders)
    Aliases of the target path:
        plain  the same path by name (the core's by-name checks; the control)
        unc    \\localhost\C$\...           ip     \\127.0.0.1\C$\...
        subst  a SUBST letter on <case>\parentlong (the first free of T,U,V,Q,R; removed)
        junc   <case>\j, a junction to <case>\parentlong (removed first)
        short  the 8.3 name of "parentlong"  case   "PARENTLONG"
        net    a drive letter mapped with "net use" to \\localhost\C$ (W or Y; removed)
        davx   WebDAV: the same server under \\localhost@port and \\127.0.0.1@port
        davn   WebDAV: the parent stored NFD ("cafe"+U+0301), typed NFC+case ("Caf"+U+00E9)
        davy   WebDAV: a drive letter mapped with "net use" to the share (Y, X or V; removed)
        davw   WebDAV: the \\host@port\DavWWWRoot\dav\... form of the same share
               on a server folding like macOS (103's davnorm.py)
    Routes: cpy = F5 (727), mov = F6 (728), pcpy / pmov = Copy (773) / Cut (774) in the
    source panel, Change Directory of the same panel to T, Paste (775) - the paste builds
    its script in DropCopyMove/BuildScriptMain2, the code drag & drop uses (an OLE drag
    with the mouse is NOT DRIVEN). Quick Rename cannot name another folder (the core
    refuses '\' and ':' in the new name): its only alias rows are the folder's own 8.3
    name and another case (qren rows).
    Hard links (hl-*): a.txt + its hard link b.txt in <case>\parentlong; F5/F6 of a.txt
    onto the SAME entry through an alias ("-same") or onto the OTHER link b.txt ("-other").
    Controls (norm-*): a folder copied / moved between two different folders (ASCII and
    Cyrillic names; also between two roots and with a merge into an existing folder).

    Every window is answered as a hurried user would: Yes / OK, else Skip; a re-opened
    Copy / Move / Change Directory dialog is cancelled. After the run the physical tree of
    the case (for WebDAV: the server's backing folder; links are not followed) is compared
    with the tree before: "lost" = a file content no file holds any more, "missing" =
    entries of the source tree that are gone (deleted folders included), "added" = new
    entries (a nested copy).

    Without -Expect107 a row FAILs when content is lost or the source tree lost an entry
    (the defects). With -Expect107 it also has to show the windows and the tree this
    feature expects.

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
    [int]$Port = 18107,
    [switch]$Expect107
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc107\fa'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$DavBack = $Root + '\dav'
$DavLog = $Root + '\davnorm.log'
$DavPy = Join-Path $PSScriptRoot '..\..\103-same-file-delete-guard\probe\davnorm.py'
$DavA = '\\localhost@' + $Port + '\dav'
$DavB = '\\127.0.0.1@' + $Port + '\dav'
$DavW = '\\localhost@' + $Port + '\DavWWWRoot\dav'   # the WebDAV redirector's root form of the same share
$Nfd = 'cafe' + [char]0x0301
$Nfc = 'Caf' + [char]0xE9
$Cyr = [string]([char]0x041F) + [char]0x0430 + [char]0x043F + [char]0x043A + [char]0x0430       # Papka
$CyrDoc = [string]([char]0x0414) + [char]0x043E + [char]0x043A + [char]0x0443 + [char]0x043C   # Dokum
$CyrTgt = [string]([char]0x0426) + [char]0x0435 + [char]0x043B + [char]0x044C                  # Tsel'
$ConfKey = 'HKCU:\Software\Tandem Commander\0.1\Configuration\Confirmation'
$script:Links = New-Object System.Collections.ArrayList
$script:Subst = $null
$script:Net = $null
$script:NetDav = $null
$script:Dav = $null

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
function Put([string]$p, [string]$text) { [IO.File]::WriteAllText($LP + $p, $text, (New-Object Text.ASCIIEncoding)) }
function Set-Overwrite([int]$v) {
    if (-not (Test-Path $ConfKey)) { [void](New-Item -Path $ConfKey -Force) }
    Set-ItemProperty -Path $ConfKey -Name 'File Overwrite' -Value $v -Type DWord
}
function Read-Shared([string]$p) {
    if (-not [IO.File]::Exists($p)) { return @() }
    $fs = New-Object IO.FileStream($p, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $sr = New-Object IO.StreamReader($fs); return @(($sr.ReadToEnd() -split "`r?`n") | Where-Object { $_ -ne '' }) } finally { $fs.Dispose() }
}
function Dav-Count { return @(Read-Shared $DavLog).Count }
function Dav-Lines([int]$From) {
    $all = @(Read-Shared $DavLog)
    if ($all.Count -le $From) { return @() }
    return @($all[$From..($all.Count - 1)] | Where-Object { $_ -match ' (MOVE|DELETE|PUT|COPY|MKCOL) ' -and $_ -notmatch '^\S+\s+  ' })
}

# ---- trees ---------------------------------------------------------------------------
# the physical tree under $Dir: "rel/" for a folder, "rel=content" for a file, links are
# recorded ("rel/ (link)") and never followed
function Tree([string]$Dir) {
    $out = New-Object System.Collections.ArrayList
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @('(gone)') }
    $stack = New-Object System.Collections.Stack; $stack.Push('')
    while ($stack.Count) {
        $rel = $stack.Pop()
        $full = $LP + $Dir + $(if ($rel) { '\' + $rel } else { '' })
        foreach ($e in [IO.Directory]::GetFileSystemEntries($full)) {
            $n = [IO.Path]::GetFileName($e); $r = $(if ($rel) { $rel + '\' + $n } else { $n })
            $isLink = ([IO.File]::GetAttributes($e) -band [IO.FileAttributes]::ReparsePoint) -ne 0
            if ([IO.Directory]::Exists($e)) {
                if ($isLink) { [void]$out.Add($r + '/ (link)') } else { [void]$out.Add($r + '/'); $stack.Push($r) }
            }
            else { $t = '<unreadable>'; try { $t = [IO.File]::ReadAllText($e) } catch { }; [void]$out.Add($r + '=' + $t) }
        }
    }
    return @($out | Sort-Object)
}
function Contents($t) { return @($t | Where-Object { $_ -match '=' } | ForEach-Object { $_.Substring($_.IndexOf('=') + 1) }) }
function Diff-Tree($Before, $After) {
    $missing = @($Before | Where-Object { $After -notcontains $_ })
    $added = @($After | Where-Object { $Before -notcontains $_ })
    $ca = Contents $After
    $lost = @(Contents $Before | Where-Object { $ca -notcontains $_ } | Select-Object -Unique)
    return [pscustomobject]@{ Missing = $missing; Added = $added; Lost = $lost }
}
function Show-List($l, [int]$max = 8) {
    $l = @($l); if (-not $l.Count) { return '-' }
    $s = (@($l | Select-Object -First $max | ForEach-Object { Esc $_ }) -join ', ')
    if ($l.Count -gt $max) { $s += (' ... (+' + ($l.Count - $max) + ')') }
    return $s
}

# ---- serving the windows -----------------------------------------------------------
function Serve107([int]$Id, [double]$Seconds = 120) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.5) { break }
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
            if ($ids -contains 157 -and $ids -contains 158) { continue }   # the operation's progress window (Minimize, Pause)
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            $title = [Drv098f]::Txt($h)
            if (@('Copy', 'Move', 'Change Directory', 'Quick Rename') -contains $title -and (Find-Ctl $h 210) -ne [IntPtr]::Zero) {
                [void]$r.Messages.Add($title + ' dialog re-opened (cancelled)'); Close-Win $h; Start-Sleep -Milliseconds 400; continue
            }
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
    $s = $s -replace '\[#32770 ', '['
    if ($s.Length -gt 200) { $s = $s.Substring(0, 200) + '...' }
    return $s.Trim()
}

# ---- aliases -------------------------------------------------------------------------
function Unc([string]$p, [string]$server) { return '\\' + $server + '\' + $p.Substring(0, 1) + '$' + $p.Substring(2) }
function Free-Letter($prefer) {
    $used = @([IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpper() })
    foreach ($l in $prefer) { if ($used -notcontains $l) { return $l } }
    return $null
}
function Subst-On([string]$dir) {
    if ($script:Subst) { [void](Cmd ("subst {0} /d" -f $script:Subst)); $script:Subst = $null }
    $letter = Free-Letter @('T', 'U', 'V', 'Q', 'R')
    if (-not $letter) { return $null }
    $r = Cmd ("subst {0}: `"{1}`"" -f $letter, $dir); if ($r.Rc -ne 0) { return $null }
    $script:Subst = $letter + ':'; return $script:Subst
}
function Net-On {
    if ($script:Net) { return $script:Net }
    $letter = Free-Letter @('W', 'Y', 'X')
    if (-not $letter) { return $null }
    $r = Cmd ("net use {0}: \\localhost\C$ /persistent:no" -f $letter)
    if ($r.Rc -ne 0) { Out ('net use refused: ' + $r.Text); return $null }
    $script:Net = $letter + ':'; return $script:Net
}
# a drive letter mapped to the WebDAV share (re-check of 107: a mapped drive is resolved to its UNC path)
function Net-Dav {
    if ($script:NetDav) { return $script:NetDav }
    $letter = Free-Letter @('Y', 'X', 'V')
    if (-not $letter) { return $null }
    $r = Cmd ("net use {0}: {1} /persistent:no" -f $letter, $DavA)
    if ($r.Rc -ne 0) { Out ('net use (WebDAV) refused: ' + $r.Text); return $null }
    $script:NetDav = $letter + ':'; return $script:NetDav
}
function Short-Name([string]$p) {
    try { $fso = New-Object -ComObject Scripting.FileSystemObject; return $fso.GetFolder($p).ShortName } catch { return $null }
}

# the source tree F under $parent
function New-F([string]$parent, [string]$tag) {
    $f = $parent + '\F'
    NewDir "$f\sub\deep"; NewDir "$f\empty"; NewDir "$f\$Cyr"
    Put "$f\a.txt" ("A-" + $tag); Put "$f\sub\b.txt" ("B-" + $tag); Put "$f\$Cyr\c.txt" ("C-" + $tag)
    return $f
}

# ---- one case -----------------------------------------------------------------------
# $c: @{ Skip; Left (folder shown, holds the item); Focus ($null = the last item, else a file
#        path for Change Directory); Route; Target (the field text / the folder pasted into);
#        Phys (physical folder compared before/after); Asked (regex the windows must match
#        with -Expect107); NotAsked; Expect = 'same' | 'nested' | scriptblock($diff) -> bool }
function Run-Case([string]$Case, [scriptblock]$Setup) {
    $before = Reports; $id = 0; $fatal = $null
    try {
        $c = & $Setup
        if ($c.Skip) { Row $Case 'RUN' 'NOT DRIVEN' $c.Skip; return }
        if ($c.Route -like 'p*' -and -not $script:ClipOk) { Row $Case 'RUN' 'NOT DRIVEN' 'the clipboard cannot be opened from this session (hidden desktop); paste builds its script in DropCopyMove/BuildScriptMain2 like drag and drop, which is not driven either'; return }
        $davFrom = Dav-Count
        Set-Overwrite 1
        $t0 = Tree $c.Phys
        $id = Start-Tc $c.Left
        if ($c.Focus) { $held = Do-ChangeDir $id $c.Focus }
        else { $held = Do-ChangeDir $id $c.Left; Key $id 0x24; Key $id 0x23 }
        Start-Sleep -Milliseconds 500
        $sw = [Diagnostics.Stopwatch]::StartNew()
        switch ($c.Route) {
            { $_ -in 'cpy', 'mov' } {
                $dlg = Open-ByCmd $id $(if ($c.Route -eq 'cpy') { 727 } else { 728 }) 15
                if ($dlg -eq [IntPtr]::Zero) { throw 'the Copy/Move dialog did not open' }
                $fld = Find-Ctl $dlg 210; if ($fld -eq [IntPtr]::Zero) { throw 'the target field was not found' }
                [void][Drv098f]::SetText($fld, $c.Target, 5000)
                Click-Ok $dlg
            }
            'qren' {
                $dlg = Open-ByCmd $id 754 15
                if ($dlg -eq [IntPtr]::Zero) { throw 'the Quick Rename dialog did not open' }
                $fld = Find-Ctl $dlg 210; if ($fld -eq [IntPtr]::Zero) { throw 'the name field was not found' }
                [void][Drv098f]::SetText($fld, $c.Target, 5000)
                Click-Ok $dlg
            }
            { $_ -in 'pcpy', 'pmov' } {
                Post-Cmd (Get-Main $id) $(if ($c.Route -eq 'pcpy') { 773 } else { 774 })
                Start-Sleep -Milliseconds 1200
                $held = (Do-ChangeDir $id $c.Target) -and $held
                Start-Sleep -Milliseconds 800
                Post-Cmd (Get-Main $id) 775
            }
        }
        Start-Sleep -Milliseconds 800
        $r = Serve107 $id 150
        $secs = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        Start-Sleep -Milliseconds 500
        $t1 = Tree $c.Phys
        $df = Diff-Tree $t0 $t1
        $msgs = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || ')
        $shown = $(if ($msgs) { $msgs } else { 'nothing' })
        $dav = @(Dav-Lines $davFrom | ForEach-Object { ($_ -replace '^\S+ ', '') } | Where-Object { $_ -match 'DELETE|MOVE' })
        $base = ($df.Lost.Count -eq 0) -and ($df.Missing.Count -eq 0 -or $c.MayRemove)
        if ($c.Check) { $base = & $c.Check $df $t1 }
        $exp = $true
        if ($Expect107) {
            $exp = ($shown -match $c.Asked) -and (-not $c.NotAsked -or $shown -notmatch $c.NotAsked)
            if ($c.Expect -eq 'same') { $exp = $exp -and $df.Missing.Count -eq 0 -and $df.Added.Count -eq 0 }
            elseif ($c.Expect -eq 'nested') { $exp = $exp -and $df.Missing.Count -eq 0 }
        }
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and $base -and $exp
        $label = ('{0} -> {1}' -f $c.Route, (Tail $c.Target 60))
        Row $Case 'RUN' (V $ok) ("{0}; {1}s; lost {2} [{3}]; missing {4} [{5}]; added {6} [{7}]; 107-windows {8}; focus {9}; asked: {10}{11}{12}{13}" -f $label, $secs, $df.Lost.Count, (Show-List $df.Lost 4), $df.Missing.Count, (Show-List $df.Missing), $df.Added.Count, (Show-List $df.Added 4), $exp, $held, $shown, $(if ($dav.Count) { '; server: ' + (Show-List $dav 6) } else { '' }), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' $_.Exception.Message }
    finally {
        if ($id) { End-Row $Case $id $fatal $before }
        foreach ($l in @($script:Links)) { if ([IO.Directory]::Exists($l)) { [void](Cmd ("rmdir `"{0}`"" -f $l)) } }
        $script:Links.Clear()
        if ($script:Subst) { [void](Cmd ("subst {0} /d" -f $script:Subst)); $script:Subst = $null }
    }
}

# ---- the expectations of this feature ----------------------------------------------
# move: refused for every shape ("to itself" at the folder level, nothing changed);
# copy: b refused (the same place), a / c copy a snapshot INTO the folder as the build
# before did by name (the source entries stay; a nested copy is added) - see spec.md
function Expect-Of([string]$shape, [string]$route, [string]$alias) {
    $move = $route -in 'mov', 'pmov'
    # another case of the same path is the same path by name: 092's case-only rename (a no-op here)
    if ($move -and $shape -eq 'b' -and $alias -eq 'case') { return @{ Asked = '^nothing$'; NotAsked = 'Error'; Expect = 'same' } }
    if ($move) { return @{ Asked = 'Cannot move a directory to itself'; NotAsked = 'Confirm Directory Overwrite|Confirm File Overwrite|Error (Moving|Deleting)|Move Error|Copy Error'; Expect = 'same' } }
    if ($shape -eq 'b') { return @{ Asked = 'Cannot copy a file to itself'; NotAsked = 'Confirm Directory Overwrite|Confirm File Overwrite|Error (Moving|Deleting)|Move Error|Copy Error'; Expect = 'same' } }
    return @{ Asked = '.'; NotAsked = 'Error'; Expect = 'nested' }
}

$Cases = [ordered]@{}
$Shapes = 'a', 'b', 'c'
$Routes = 'cpy', 'mov', 'pcpy', 'pmov'
# the paste rows hold the clipboard (shared with the visible desktop) - only these aliases
$PasteAliases = 'plain', 'unc', 'subst', 'junc', 'davx'
# alias name -> scriptblock($caseDir, $parent) returning the alias of $parent (or @{Skip})
$Aliases = [ordered]@{
    'plain' = { param($cd, $p) $p }
    'unc'   = { param($cd, $p) Unc $p 'localhost' }
    'ip'    = { param($cd, $p) Unc $p '127.0.0.1' }
    'subst' = { param($cd, $p) $s = Subst-On $p; if (-not $s) { @{ Skip = 'no free drive letter / subst refused' } } else { $s } }
    'junc'  = { param($cd, $p) $r = Cmd ("mklink /J `"{0}`" `"{1}`"" -f "$cd\j", $p); if ($r.Rc -ne 0) { @{ Skip = 'mklink /J refused: ' + $r.Text } } else { [void]$script:Links.Add("$cd\j"); "$cd\j" } }
    'short' = { param($cd, $p) $s = Short-Name $p; if (-not $s -or $s -ieq 'parentlong') { @{ Skip = 'no 8.3 names on this volume' } } else { "$cd\$s" } }
    'case'  = { param($cd, $p) "$cd\PARENTLONG" }
    'net'   = { param($cd, $p) $n = Net-On; if (-not $n) { @{ Skip = 'net use refused' } } else { $n + $p.Substring(2) } }
}
function Tail-Of([string]$shape) { switch ($shape) { 'a' { return '\F\' } 'b' { return '\' } 'c' { return '\F\sub\' } } }

foreach ($al in $Aliases.Keys) {
    foreach ($sh in $Shapes) {
        foreach ($rt in $Routes) {
            if ($rt -like 'p*' -and $PasteAliases -notcontains $al) { continue }
            $name = "$sh-$al-$rt"
            $Cases[$name] = [scriptblock]::Create(@"
    `$cd = `$Root + '\$name'; `$p = `$cd + '\parentlong'; NewDir `$p; [void](New-F `$p '$name')
    `$alias = & `$Aliases['$al'] `$cd `$p
    if (`$alias -is [hashtable]) { return `$alias }
    `$e = Expect-Of '$sh' '$rt' '$al'
    @{ Left = `$p; Route = '$rt'; Target = (`$alias.TrimEnd('\') + (Tail-Of '$sh')); Phys = `$p; Asked = `$e.Asked; NotAsked = `$e.NotAsked; Expect = `$e.Expect }
"@)
        }
    }
}
# WebDAV: two server names (davx) and NFD stored / NFC typed (davn)
foreach ($al in 'davx', 'davn', 'davy', 'davw') {
    foreach ($sh in $Shapes) {
        foreach ($rt in $Routes) {
            if ($rt -like 'p*' -and $PasteAliases -notcontains $al) { continue }
            $name = "$sh-$al-$rt"
            $Cases[$name] = [scriptblock]::Create(@"
    if (-not `$script:DavOk) { return @{ Skip = `$script:DavWhy } }
    `$par = `$(if ('$al' -eq 'davn') { `$Nfd } else { 'parentlong' })
    `$b = `$DavBack + '\$name\' + `$par; NewDir `$b; [void](New-F `$b '$name')
    `$left = `$DavA + '\$name\' + `$par
    `$alias = `$(switch ('$al') { 'davn' { `$DavA + '\$name\' + `$Nfc } 'davx' { `$DavB + '\$name\parentlong' }
        'davw' { `$DavW + '\$name\parentlong' }
        'davy' { `$y = Net-Dav; if (`$y) { `$y + '\$name\parentlong' } else { `$null } } })
    if (-not `$alias) { return @{ Skip = 'net use of the WebDAV share refused' } }
    `$e = Expect-Of '$sh' '$rt' '$al'
    @{ Left = `$left; Route = '$rt'; Target = (`$alias + (Tail-Of '$sh')); Phys = (`$DavBack + '\$name'); Asked = `$e.Asked; NotAsked = `$e.NotAsked; Expect = `$e.Expect }
"@)
        }
    }
}

# Quick Rename of the folder to its own 8.3 name and to another case (the only alias it can name)
$Cases['q-short-qren'] = {
    $cd = $Root + '\q-short-qren'; $p = $cd + '\parentlong'; NewDir $p; $f = New-F $p 'q-short-qren'
    [void][IO.Directory]::Move($LP + $f, $LP + "$p\FolderLongName")
    $s = Short-Name "$p\FolderLongName"; if (-not $s -or $s -ieq 'FolderLongName') { return @{ Skip = 'no 8.3 names on this volume' } }
    @{ Left = $p; Route = 'qren'; Target = $s; Phys = $p; Asked = '^nothing$'; Expect = 'same' }
}
$Cases['q-case-qren'] = {
    $cd = $Root + '\q-case-qren'; $p = $cd + '\parentlong'; NewDir $p; [void](New-F $p 'q-case-qren')
    @{ Left = $p; Route = 'qren'; Target = 'f'; Phys = $p; Asked = '^nothing$'; Expect = 'any'
       Check = { param($df, $t1) ($df.Lost.Count -eq 0) -and (@($t1 | Where-Object { $_ -clike 'f\*' }).Count -eq 7) } }
}

# ---- hard links through an alias ---------------------------------------------------
function HL-Case([string]$name, [string]$al, [string]$route, [string]$which) {
    return [scriptblock]::Create(@"
    `$cd = `$Root + '\$name'; `$p = `$cd + '\parentlong'; NewDir `$p
    Put (`$p + '\a.txt') 'PRECIOUS-$name'
    `$r = Cmd ("mklink /H ```"{0}```" ```"{1}```"" -f (`$p + '\b.txt'), (`$p + '\a.txt')); if (`$r.Rc -ne 0) { return @{ Skip = 'mklink /H refused' } }
    `$alias = & `$Aliases['$al'] `$cd `$p
    if (`$alias -is [hashtable]) { return `$alias }
    `$t = `$alias.TrimEnd('\') + `$(if ('$which' -eq 'other') { '\b.txt' } else { '\' })
    if ('$which' -eq 'other') { `$ask = 'Confirm File Overwrite'; `$not = 'itself' }
    elseif ('$route' -eq 'mov' -and @('junc', 'short') -contains '$al') { `$ask = '^nothing`$'; `$not = 'itself' }   # one root: NTFS renames onto itself
    else { `$ask = `$(if ('$route' -eq 'cpy') { 'Cannot copy a file to itself' } else { 'Cannot move a file to itself' }); `$not = 'Confirm File Overwrite' }
    @{ Left = `$p; Focus = (`$p + '\a.txt'); Route = '$route'; Target = `$t; Phys = `$p; Asked = `$ask; NotAsked = `$not; Expect = 'any'; MayRemove = ('$which' -eq 'other')
       Check = { param(`$df, `$t1) (`$df.Lost.Count -eq 0) -and (@(`$t1 | Where-Object { `$_ -like '*=PRECIOUS-$name' }).Count -ge 1) -and (`$('$which' -eq 'other') -or `$df.Missing.Count -eq 0) } }
"@)
}
foreach ($al in 'unc', 'ip', 'subst', 'junc', 'short', 'net') {
    foreach ($rt in 'cpy', 'mov') { $Cases["hl-$al-$rt-same"] = HL-Case "hl-$al-$rt-same" $al $rt 'same' }
}
foreach ($al in 'unc', 'plain') { $Cases["hl-$al-cpy-other"] = HL-Case "hl-$al-cpy-other" $al 'cpy' 'other' }

# ---- below the top level, links as the source, WebDAV merges ----------------------
# the target holds its own F, but F\sub there is a junction back to the SOURCE's F\sub: the
# script-build check passes (dst\F is another folder), the worker meets F\sub as an existing
# folder that is the source's own subfolder
function Deep-Case([string]$name, [bool]$unc) {
    return [scriptblock]::Create(@"
    `$cd = `$Root + '\$name'; `$s = `$cd + '\src'; `$d = `$cd + '\dst'; NewDir `$s; NewDir (`$d + '\F'); [void](New-F `$s '$name')
    `$r = Cmd ("mklink /J ```"{0}```" ```"{1}```"" -f (`$d + '\F\sub'), (`$s + '\F\sub')); if (`$r.Rc -ne 0) { return @{ Skip = 'mklink /J refused: ' + `$r.Text } }
    [void]`$script:Links.Add(`$d + '\F\sub')
    `$tgt = `$(if (`$$unc) { Unc `$d 'localhost' } else { `$d }) + '\'
    @{ Left = `$s; Route = 'mov'; Target = `$tgt; Phys = `$cd; Asked = 'Cannot move a directory to itself'; Expect = 'any'; MayRemove = `$true
       Check = { param(`$df, `$t1) (`$df.Lost.Count -eq 0) -and (`$t1 -contains 'src\F\sub\deep/') -and (`$t1 -contains 'src\F\sub\b.txt=B-$name') -and (`$t1 -contains 'dst\F\a.txt=A-$name') } }
"@)
}
$Cases['deep-junc-mov'] = Deep-Case 'deep-junc-mov' $false
$Cases['deep-junc-unc-mov'] = Deep-Case 'deep-junc-unc-mov' $true
# a junction as the source moved "into the same place" through \\localhost\C$: the link must stay
$Cases['jlink-unc-mov'] = {
    $cd = $Root + '\jlink-unc-mov'; $p = $cd + '\parentlong'; $g = $cd + '\G'; NewDir $p; NewDir "$g\empty"; Put "$g\g.txt" 'G-jlink'
    $r = Cmd ("mklink /J `"{0}`" `"{1}`"" -f "$p\J", $g); if ($r.Rc -ne 0) { return @{ Skip = 'mklink /J refused: ' + $r.Text } }
    [void]$script:Links.Add("$p\J")
    @{ Left = $p; Route = 'mov'; Target = ((Unc $p 'localhost') + '\'); Phys = $cd; Asked = 'Cannot move a directory to itself'; Expect = 'same' }
}
function DavMerge-Case([string]$name, [bool]$twin, [string]$route, [bool]$sameServer) {
    return [scriptblock]::Create(@"
    if (-not `$script:DavOk) { return @{ Skip = `$script:DavWhy } }
    `$b = `$DavBack + '\$name'; [void](New-F (`$b + '\src') '$name'); NewDir (`$b + '\dst\F\old'); Put (`$b + '\dst\F\old\o.txt') 'O-$name'
    Put (`$b + '\dst\F\a.txt') 'OLD-$name'
    `$t = [datetime]'2020-01-02 03:04:05'
    foreach (`$x in (`$b + '\src\F'), (`$b + '\dst\F')) { if (`$$twin -or `$x -like '*dst*') { [IO.Directory]::SetCreationTime(`$x, `$t); [IO.Directory]::SetLastWriteTime(`$x, `$t) } }
    `$move = '$route' -eq 'mov'
    @{ Left = (`$DavA + '\$name\src'); Route = '$route'; Target = (`$(if (`$$sameServer) { `$DavA } else { `$DavB }) + '\$name\dst\'); Phys = `$b
       Asked = '.'; NotAsked = 'itself'; Expect = 'any'; MayRemove = `$true
       Check = { param(`$df, `$t1)
           (`$t1 -contains 'dst\F\old\o.txt=O-$name') -and (`$t1 -contains 'dst\F\a.txt=A-$name') -and (`$t1 -contains 'dst\F\sub\b.txt=B-$name') -and
           `$(if ('$route' -eq 'mov') { @(`$t1 | Where-Object { `$_ -like 'src\F\*' }).Count -eq 0 } else { `$t1 -contains 'src\F\a.txt=A-$name' }) } }
"@)
}
# a merge into ANOTHER folder of the same name on WebDAV (no ids) works - also with equal folder times
# (review of 107, SF2: a backup update within one server, or between its two names, must merge)
$Cases['dav-merge-mov'] = DavMerge-Case 'dav-merge-mov' $false 'mov' $false
$Cases['dav-twin-merge'] = DavMerge-Case 'dav-twin-merge' $true 'mov' $false
$Cases['dav-bak-cpy'] = DavMerge-Case 'dav-bak-cpy' $true 'cpy' $true
$Cases['dav-bak-mov'] = DavMerge-Case 'dav-bak-mov' $true 'mov' $true

# ---- controls: really different folders --------------------------------------------
function Norm-Case([string]$name, [string]$route, [string]$srcName, [string]$dstName, [string]$tgtAlias, [bool]$merge) {
    return [scriptblock]::Create(@"
    `$cd = `$Root + '\$name'; `$s = `$cd + '\' + '$srcName'; `$d = `$cd + '\' + '$dstName'; NewDir `$s; NewDir `$d; [void](New-F `$s '$name')
    if (`$$merge) { NewDir (`$d + '\F\old'); Put (`$d + '\F\old\o.txt') 'O-$name' }
    `$tgt = `$(if ('$tgtAlias' -eq 'unc') { Unc `$d 'localhost' } else { `$d }) + '\'
    `$move = '$route' -in 'mov', 'pmov'
    @{ Left = `$s; Route = '$route'; Target = `$tgt; Phys = `$cd; Asked = `$(if (`$$merge) { '.' } else { '^nothing$' }); Expect = 'any'; MayRemove = `$move
       Check = { param(`$df, `$t1)
           `$inDst = @(`$t1 | Where-Object { `$_ -like ('$dstName' + '\F\*') }).Count
           `$inSrc = @(`$t1 | Where-Object { `$_ -like ('$srcName' + '\F*') }).Count
           (`$df.Lost.Count -eq 0) -and (`$inDst -ge 7) -and `$(if ('$route' -in 'mov', 'pmov') { `$inSrc -eq 0 } else { `$inSrc -eq 8 }) } }
"@)
}
$Cases['norm-ascii-cpy'] = Norm-Case 'norm-ascii-cpy' 'cpy' 'src' 'dst' 'plain' $false
$Cases['norm-ascii-mov'] = Norm-Case 'norm-ascii-mov' 'mov' 'src' 'dst' 'plain' $false
$Cases['norm-cyr-cpy'] = Norm-Case 'norm-cyr-cpy' 'cpy' $CyrDoc $CyrTgt 'plain' $false
$Cases['norm-cyr-mov'] = Norm-Case 'norm-cyr-mov' 'mov' $CyrDoc $CyrTgt 'plain' $false
$Cases['norm-unc-mov'] = Norm-Case 'norm-unc-mov' 'mov' 'src' 'dst' 'unc' $false
$Cases['norm-unc-cpy'] = Norm-Case 'norm-unc-cpy' 'cpy' 'src' 'dst' 'unc' $false
$Cases['norm-cyr-pmov'] = Norm-Case 'norm-cyr-pmov' 'pmov' $CyrDoc $CyrTgt 'plain' $false
$Cases['norm-ascii-pcpy'] = Norm-Case 'norm-ascii-pcpy' 'pcpy' 'src' 'dst' 'plain' $false
$Cases['norm-merge-unc-mov'] = Norm-Case 'norm-merge-unc-mov' 'mov' 'src' 'dst' 'unc' $true
$Cases['norm-merge-cpy'] = Norm-Case 'norm-merge-cpy' 'cpy' 'src' 'dst' 'plain' $true

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc107_fa_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir; NewDir $DavBack
    Set-Config
    Set-Overwrite 1
    Out ("folderalias_probe (feature 107) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; Expect107 {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, [bool]$Expect107)
    Save-Clip
    $script:DavOk = $false; $script:DavWhy = 'WebDAV not started'
    if (@(Get-Service WebClient -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }).Count -eq 0) { $script:DavWhy = 'the WebClient service is not running' }
    elseif (@($Cases.Keys | Where-Object { $_ -match 'dav' -and (Want $_) }).Count) {
        try {
            $script:Dav = Start-Process -FilePath $Python -ArgumentList @(('"{0}"' -f $DavPy), ('"{0}"' -f $DavBack), $Port, ('"{0}"' -f $DavLog)) -PassThru -WindowStyle Hidden
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
    if ($script:Net) { [void](Cmd ("net use {0} /delete /y" -f $script:Net)) }
    if ($script:NetDav) { [void](Cmd ("net use {0} /delete /y" -f $script:NetDav)) }
    foreach ($l in @($script:Links)) { if ([IO.Directory]::Exists($l)) { [void](Cmd ("rmdir `"{0}`"" -f $l)) } }
    if ($script:Dav -and -not $script:Dav.HasExited) { Stop-Process -Id $script:Dav.Id -Force; Start-Sleep -Milliseconds 500 }
    Restore-Clip
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    # junctions inside the fixture first (a failed case may have left one), then the fixture
    try {
        if ([IO.Directory]::Exists($LP + $Root)) {
            foreach ($j in @(Get-ChildItem -LiteralPath $Root -Recurse -Directory -Attributes ReparsePoint -ErrorAction SilentlyContinue)) { [void](Cmd ("rmdir `"{0}`"" -f $j.FullName)) }
            [IO.Directory]::Delete($LP + $Root, $true)
        }
    } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $netGone = $true; if ($script:Net) { $netGone = -not (Test-Path ($script:Net + '\')) }
    if ($script:NetDav) { $netGone = $netGone -and -not (Test-Path ($script:NetDav + '\')) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; subst removed: {5}; net use removed: {6}; registry restored+identical: {7}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), (-not $script:Subst -or -not (Test-Path ($script:Subst + '\'))), $netGone, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
