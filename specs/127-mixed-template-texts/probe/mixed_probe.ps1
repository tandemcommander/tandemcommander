<#
.SYNOPSIS
    Feature 127 probe (GitHub issue #7): texts composed from a translated template and a UTF-8
    name or Windows error text, in a language whose templates have non-ASCII letters (Czech).

.DESCRIPTION
    The program runs in Czech. Fixture under %TEMP%\tc127: a folder "data" with files named
    with Czech accents, a subfolder "denied" that the user may not list (icacls deny RD), and a
    large sparse file for a content search that lasts a few seconds.

      LOG    Find Files over "data" with subdirectories; the log ("Messages") is opened and its
             rows are read with LVM_GETITEMTEXTW: the row for the unreadable folder must be
             the Czech template with the Windows error text, exactly
             ("Chyba pri cteni adresare: (5) <Windows text for error 5>")
      STATUS Find Files with a text to search for in the large file: while it searches, the
             status line (owner-drawn) is captured and read: "Vyhledavani: <path>" with the
             accented file name readable
      BOX    F5 (Copy) of "data" to another folder: the error box for the unreadable subfolder
             ("Chyba pri cteni adresare "<path>". <Windows error text>") - its text is read
             from the window and from a capture
      TITLE  the Find window's title during that search holds the typed mask (with accented
             letters) exactly
      PROGRESS the title of the progress dialog of a running Copy: "(NN %) <caption>", the
             caption being a text of the translation exactly (the title is composed wide)
      COPYNAME a file copied into its own folder: the generated name on disk holds the
             translation's word for "copy" exactly (run with -Lang slovak: "Kopia" with accent)
      REGDEL Registry Editor: deleting a non-empty key with an accented name - the question
             names the key exactly
      END    each instance ends with exit code 0, no stray window, no report

    Verdicts: LOG exact; STATUS and BOX by text recognition (exact / folded / near) plus, for
    BOX, the window text. With -Expect before the same checks run on the old build (they are
    expected to FAIL there - the control).

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified; the deny entry is
    removed and the fixture deleted. Exit code = FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$ShotDir,
    [string]$Lang = 'czech'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\124-regedt-key-text\probe\shotocr_lib.ps1')
. (Join-Path $PSScriptRoot 'lvtext_lib.ps1')

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..')).Path
$Root = $TempRoot + '\tc127'
$StartDir = $Root + '\start'
$DataDir = $Root + '\data'
$DeniedDir = $DataDir + '\denied'
$BigDir = $Root + '\big'
$OutDir2 = $Root + '\out'
if (-not $ShotDir) { $ShotDir = $Root + '\shots' }
function Chars([int[]]$Codes) { return (-join ($Codes | ForEach-Object { [char]$_ })) }
# "Prilis zlutoucky kun" with its Czech accents (pure ASCII source)
$Accent = 'P' + (Chars @(0x0159, 0x00ED)) + 'li' + [char]0x0161 + ' ' + [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD + ' k' + (Chars @(0x016F, 0x0148))
$AccentTail = $Accent.Substring($Accent.IndexOf(' ') + 1)
$BigName = $Accent + ' 01.bin'
$Err5 = '(5) ' + (New-Object ComponentModel.Win32Exception 5).Message     # the text Windows gives for ERROR_ACCESS_DENIED

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }) | Select-Object -First 1 }
function Start-P([string]$Left) {
    $a = @('-t', 'T127', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
# a template of the language: translations\<lang>\salamand.slt by id (English: the given text)
function Template([int]$Id, [string]$English) {
    if ($Lang -eq 'english') { return $English }
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $RepoRoot ("translations\{0}\salamand.slt" -f $Lang)), $Utf8)) {
        if ($line -match ('^' + $Id + ',\d+,"(.*)"\s*$')) { return $Matches[1].Replace('""', '"').Replace('\n', "`n") }
    }
    throw "id $Id not found in the $Lang translation"
}
function Trim-Err([string]$t) { if ($null -eq $t) { return '' }; return $t.Replace("`r", '').TrimEnd(' ', "`n", '.') }
function End-P([string]$Case, [int]$Id, $Before) {
    $fatal = Fatal-Win $Id
    End-Row $Case $Id $fatal $Before
}
function Make-Fixture {
    NewDir $StartDir; NewDir $DataDir; NewDir $DeniedDir; NewDir $BigDir; NewDir $OutDir2
    [void][IO.Directory]::CreateDirectory($ShotDir)
    foreach ($n in 1..3) { [IO.File]::WriteAllText(($DataDir + '\' + $Accent + (' {0:D2}.txt' -f $n)), 'x') }
    [IO.File]::WriteAllText(($DeniedDir + '\inside.txt'), 'x')
    $big = $BigDir + '\' + $BigName
    [IO.File]::WriteAllBytes($big, [byte[]]@(1))
    & fsutil.exe sparse setflag $big | Out-Null
    $fs = [IO.File]::Open($big, 'Open', 'ReadWrite'); try { $fs.SetLength(12GB) } finally { $fs.Dispose() }
    $who = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls.exe $DeniedDir /deny ($who + ':(RD)') | Out-Null
    $listable = $true; try { [void][IO.Directory]::GetFiles($DeniedDir) } catch { $listable = $false }
    return ("data: 3 accented files + 'denied' (listing denied: {0}); big: sparse 12 GB '{1}'" -f (-not $listable), (Esc $BigName))
}

# LOG: the Find log row for the unreadable folder
function Row-Log {
    if (-not (Want 'LOG')) { return }
    $before = Reports; $id = 0; $find = [IntPtr]::Zero
    try {
        $id = Start-P $DataDir
        $find = Open-ByCmd $id 741 10
        if ($find -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
        [void][Drv098f]::SetText((Find-Ctl $find 2505), '*.txt', 5000)
        $look = [Drv098f]::GetText((Find-Ctl $find 2501), 5000)
        Post-Cmd $find 1                                    # Find Now
        Start-Sleep -Milliseconds 4000
        $lv = Kid $find 2510
        $found = [LvText127]::Count($lv)
        $known = Get-Tops $id
        Post-Cmd $find 2233                                 # CM_FIND_MESSAGES: the log
        $log = Wait-NewWin $id $known 10
        if ($log -eq [IntPtr]::Zero) { Row 'LOG' 'ROWS' 'FAIL' ("the log did not open (found {0} files in '{1}')" -f $found, (Esc $look)); return }
        Start-Sleep -Milliseconds 600
        $list = Kid $log 2756
        $n = [LvText127]::Count($list)
        # columns: kind, text, path. The program's error text is Windows' own with its final
        # full stop and blanks (FormatMessage); those are trimmed before the comparison
        $rows = @(); $hit = 0
        $expected = (Template 10825 'Error reading directory: %s').Replace('%s', $Err5)
        for ($i = 0; $i -lt [Math]::Min($n, 10); $i++) {
            $c = @(0..2 | ForEach-Object { [LvText127]::Cell($list, $i, $_) })
            $rows += ($c -join ' ## ')
            if ((Trim-Err $c[1]) -ceq $expected -and $c[2] -like '*\denied') { $hit++ }
        }
        Row 'LOG' 'ROWS' (V ($hit -eq 1)) ("found {0} files; log rows {1}: {2}; expected the text '{3}' for ...\denied" -f $found, $n, (($rows | ForEach-Object { Esc $_ }) -join ' || '), (Esc $expected))
        Close-Win $log; Start-Sleep -Milliseconds 400
    }
    catch { Row 'LOG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($find -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($find)) { Close-Win $find; Start-Sleep -Milliseconds 500 }
        if ($id) { End-P 'LOG' $id $before }
    }
}

# STATUS: the Find status line while a content search runs
function Row-Status {
    if (-not ((Want 'STATUS') -or (Want 'TITLE'))) { return }
    $before = Reports; $id = 0; $find = [IntPtr]::Zero
    try {
        $id = Start-P $BigDir
        $find = Open-ByCmd $id 741 10
        if ($find -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
        $mask = '*.bin;' + [char]0x017E + '*.' + [char]0x0159 + 'x'      # a mask with accented letters
        [void][Drv098f]::SetText((Find-Ctl $find 2505), $mask, 5000)
        $grep = Kid $find 2504
        if (-not $grep) { throw 'the Containing field (2504) was not found' }
        [void][Drv098f]::SetText($grep, 'needle127', 5000)
        $status = Kid $find 2517
        if (-not $status) { throw 'the status line (2517) was not found' }
        Post-Cmd $find 1                                    # Find Now
        $prefix = Template 10734 'Searching:'
        $best = 'no'; $seen = @(); $shots = 0
        Start-Sleep -Milliseconds 400
        $title = [Drv098f]::Txt($find)
        Row 'TITLE' 'TEXT' (V ($title.Contains($mask))) ("the Find window's title while it searches: '{0}'; holds the mask '{1}' exactly: {2}" -f (Esc $title), (Esc $mask), $title.Contains($mask))
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 12 -and $shots -lt 5) {
            Start-Sleep -Milliseconds 500
            $png = Join-Path $ShotDir ("{0}_status_{1}.png" -f $Expect, $shots)
            $s = Shot-Read $find $status $png 3
            $text = ($s.Lines -join ' | ')
            if (-not $text) { continue }
            $shots++; $seen += $text
            $hasName = Ocr-Has $s.Lines $AccentTail          # the recognizer misreads "Prilis" ("11" for "li"); the two other words carry six accented letters
            $hasPrefix = Ocr-Has $s.Lines $prefix
            if ($hasName -ne 'no' -and $hasPrefix -ne 'no') { $best = $hasName; break }
        }
        Row 'STATUS' 'LINE' (V ($best -ne 'no')) ("expected '{0} ...\{1}': {2}; recognized ({3} captures): {4}" -f (Esc $prefix), (Esc $BigName), $best, $shots, (($seen | Select-Object -Unique | ForEach-Object { Esc $_ }) -join ' || '))
        Post-Cmd $find 1; Start-Sleep -Milliseconds 1500    # Stop
    }
    catch { Row 'STATUS' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($find -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($find)) { Close-Win $find; Start-Sleep -Milliseconds 800 }
        foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) { $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b; Start-Sleep -Milliseconds 500 } }
        if ($id) { End-P 'STATUS' $id $before }
    }
}

# BOX: Copy of the folder with the unreadable subfolder
function Row-Box {
    if (-not (Want 'BOX')) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P $Root
        # focus "data" (the items of the fixture root are big, data, out, start; ".." first)
        Key $id 0x24; Key $id 0x28; Key $id 0x28
        $dlg = Open-ByCmd $id 727 10                        # CM_COPYFILES
        if ($dlg -eq [IntPtr]::Zero) { throw 'Copy (727) opened no window' }
        $what = WinDesc $dlg
        [void][Drv098f]::SetText((Find-Ctl $dlg 210), $OutDir2, 5000)
        Click-Ok $dlg
        $english = 'Cannot read directory "%s".' + "`n" + '%s'
        $expectedTemplate = (Template 10137 $english)
        $wantText = $expectedTemplate
        $i1 = $wantText.IndexOf('%s'); $wantText = $wantText.Substring(0, $i1) + $DeniedDir + $wantText.Substring($i1 + 2)
        $i2 = $wantText.IndexOf('%s'); $wantText = $wantText.Substring(0, $i2) + $Err5 + $wantText.Substring($i2 + 2)
        $box = [IntPtr]::Zero; $others2 = @(); $sw = [Diagnostics.Stopwatch]::StartNew(); $seenW = @{}
        while ($sw.Elapsed.TotalSeconds -lt 40 -and $box -eq [IntPtr]::Zero) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) {
                $st = Kid $h 2477
                if (-not $st) { continue }
                $k = $h.ToInt64(); if (-not $seenW.ContainsKey($k)) { $seenW[$k] = 1; Start-Sleep -Milliseconds 700 }
                $t = [Drv098f]::GetText($st, 5000)
                if ($t -match 'denied') { $box = $h; break }
                $others2 += (WinDesc $h)
                $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
                if ($b) { Click $b } else { Close-Win $h }
                Start-Sleep -Milliseconds 500
            }
            Start-Sleep -Milliseconds 200
        }
        if ($box -eq [IntPtr]::Zero) { Row 'BOX' 'TEXT' 'FAIL' ("no error box naming 'denied' (from: {0}); other windows: {1}" -f $what, ($others2 -join ' || ')); return }
        $text = [Drv098f]::GetText((Kid $box 2477), 5000)
        $norm = $text.Replace("`r`n", "`n")
        $s = Shot-Read $box $box (Join-Path $ShotDir ($Expect + '_box.png')) 2
        $seenTxt = ($s.Lines -join ' | ')
        $ocrErr = Ocr-Has $s.Lines $Err5.Substring(4)
        $ocrTpl = Ocr-Has $s.Lines ($expectedTemplate.Substring(0, $expectedTemplate.IndexOf('"')).Trim())
        $exact = ((Trim-Err $norm) -ceq $wantText)
        Row 'BOX' 'TEXT' (V $exact) ("window text equal to the expected text: {0}; window text: '{1}'; expected: '{2}'" -f $exact, (Esc $norm), (Esc $wantText))
        Row 'BOX' 'LOOK' (V ($ocrErr -ne 'no' -and $ocrTpl -ne 'no')) ("drawn: the template's words {0}, the Windows error text {1}; recognized: {2}" -f $ocrTpl, $ocrErr, (Esc $seenTxt))
        $cancel = Buttons $box | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2 } | Select-Object -First 1
        if ($cancel) { Click $cancel } else { Close-Win $box }
        Start-Sleep -Milliseconds 800
        $r = Serve $id 20
    }
    catch { Row 'BOX' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'BOX' $id $before } }
}

# PROGRESS: the title of the progress dialog of a running Copy ("(NN %) <caption>") - composed
# wide since feature 127; the caption part must be a text of the translation, exactly
function Row-Progress {
    if (-not (Want 'PROGRESS')) { return }
    $before = Reports; $id = 0
    try {
        $id = Start-P $BigDir
        Key $id 0x24; Key $id 0x28                              # the 12 GB sparse file
        $known = Get-Tops $id
        $dlg = Open-ByCmd $id 727 10
        if ($dlg -eq [IntPtr]::Zero) { throw 'Copy (727) opened no window' }
        [void][Drv098f]::SetText((Find-Ctl $dlg 210), $OutDir2, 5000)
        Click-Ok $dlg
        $title = $null; $prog = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 20 -and $null -eq $title) {
            foreach ($h in @(Get-Tops $id | Where-Object { $known -notcontains $_ -and [Drv098f]::Cls($_) -eq '#32770' })) {
                $t = [Drv098f]::Txt($h)
                if ($t -match '^\(\d+ %\) ') { $title = $t; $prog = $h; break }
            }
            Start-Sleep -Milliseconds 150
        }
        if ($null -eq $title) { Row 'PROGRESS' 'TITLE' 'NOT DRIVEN' ('no progress dialog with a "(NN %)" title within 20 s; windows: ' + ((Get-Tops $id | ForEach-Object { '[' + (Esc ([Drv098f]::Txt($_))) + ']' }) -join ' ')); return }
        $caption = $title -replace '^\(\d+ %\) ', ''
        $known2 = $false
        if ($Lang -eq 'english') { $known2 = ($caption -cmatch '^[\x20-\x7E]+$') }
        else { foreach ($line in [IO.File]::ReadAllLines((Join-Path $RepoRoot ("translations\{0}\salamand.slt" -f $Lang)), $Utf8)) { if ($line.EndsWith(',"' + $caption + '"')) { $known2 = $true; break } } }
        Row 'PROGRESS' 'TITLE' (V $known2) ("title '{0}'; the caption '{1}' is a text of the translation: {2}" -f (Esc $title), (Esc $caption), $known2)
        # cancel the copy: Cancel in the progress dialog, Yes / OK to whatever asks
        $c = Buttons $prog | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2 } | Select-Object -First 1
        if ($c) { Click $c } else { Close-Win $prog }
        $r = Serve $id 60
    }
    catch { Row 'PROGRESS' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'PROGRESS' $id $before } }
}

# COPYNAME: a file copied into its own folder gets a generated name with the translated word
function Row-CopyName {
    if (-not (Want 'COPYNAME')) { return }
    $before = Reports; $id = 0
    $dir = $Root + '\copy'
    try {
        NewDir $dir
        [IO.File]::WriteAllText(($dir + '\a.txt'), 'x')
        $id = Start-P $dir
        Key $id 0x24; Key $id 0x28                              # Home, Down: a.txt (after "..")
        # Edit > Copy, Edit > Paste in the same folder (the user's clipboard text is saved and restored;
        # with other data on the clipboard the row is not driven)
        Save-Clip
        if (-not $script:ClipOk) { Row 'COPYNAME' 'DISK' 'NOT DRIVEN' 'the clipboard holds data that cannot be saved and restored'; return }
        try {
            Post-Cmd (Get-Main $id) 773; Sync $id; Start-Sleep -Milliseconds 600      # CM_CLIPCOPY
            Post-Cmd (Get-Main $id) 775                                               # CM_CLIPPASTE
            $r = Serve $id 30
            Sync $id; Start-Sleep -Milliseconds 1500
        }
        finally { Restore-Clip }
        $names = @([IO.Directory]::GetFiles($dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
        $word = Template 12230 'Copy'
        $want = 'a - ' + $word + '.txt'
        Row 'COPYNAME' 'DISK' (V ($names.Count -eq 2 -and ($names -ccontains $want))) ("files in the folder after Copy + Paste of a.txt in it: {0}; expected the new name '{1}'; windows: {2}" -f (($names | ForEach-Object { Esc $_ }) -join ' , '), (Esc $want), (Msgs $r))
    }
    catch { Row 'COPYNAME' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { End-P 'COPYNAME' $id $before }
        try { if ([IO.Directory]::Exists($LP + $dir)) { [IO.Directory]::Delete($LP + $dir, $true) } } catch { }
    }
}

# REGDEL: Registry Editor - deleting a non-empty key with an accented name asks with its name
function Row-RegDel {
    if (-not (Want 'REGDEL')) { return }
    $before = Reports; $id = 0
    $regRoot = 'HKCU:\Software\TcProbe127'
    try {
        [void](New-Item -Path ($regRoot + '\' + $Accent + '\sub') -Force)
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Non-empty Dir Del' /t REG_DWORD /d 1 /f | Out-Null
        $id = Start-P $StartDir
        [void](Do-ChangeDir $id 'reg:\HKEY_CURRENT_USER\Software\TcProbe127')
        Sync $id; Start-Sleep -Milliseconds 1500
        Key $id 0x24; Key $id 0x28
        Post-Cmd (Get-Main $id) 729                              # CM_DELETEFILES
        $templ = $null
        foreach ($line in [IO.File]::ReadAllLines((Join-Path $RepoRoot ("translations\{0}\regedt.slt" -f $Lang)), $Utf8)) { if ($line -match '^1016,\d+,"(.*)"\s*$') { $templ = $Matches[1].Replace('""', '"').Replace('\n', "`n") } }
        $want = $templ.Replace('%s', $Accent)
        $seenBoxes = @(); $hit = $null; $sw = [Diagnostics.Stopwatch]::StartNew(); $done = @{}
        while ($sw.Elapsed.TotalSeconds -lt 25 -and $null -eq $hit) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) {
                $k = $h.ToInt64(); if ($done.ContainsKey($k)) { continue }
                Start-Sleep -Milliseconds 700
                $st = Kid $h 2477
                $t = $(if ($st) { [Drv098f]::GetText($st, 5000).Replace("`r", '') } else { WinDesc $h })
                $seenBoxes += $t; $done[$k] = 1
                if ($t -ceq $want -or $t -match 'pr.zdn') { $hit = $t; $b = Buttons $h | Where-Object { @(2, 7) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } else { Close-Win $h } }
                else { $b = Buttons $h | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } else { Close-Win $h } }
                Start-Sleep -Milliseconds 500
            }
            Start-Sleep -Milliseconds 200
        }
        $r = Serve $id 15
        Row 'REGDEL' 'TEXT' (V ($hit -ceq $want)) ("boxes: {0}; expected the question '{1}'" -f (($seenBoxes | ForEach-Object { Esc $_ }) -join ' || '), (Esc $want))
    }
    catch { Row 'REGDEL' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { End-P 'REGDEL' $id $before }
        Remove-Item -LiteralPath $regRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---- rows added by the second verification (sites the first pass had missed) ----------------
# the text of the first message box of the program that matches $Rx (static 2477, else all texts);
# other boxes are answered; returns @{ Text; Win; Seen }
function Wait-Box([int]$Id, [string]$Rx, [double]$Seconds = 20, $Skip = @()) {
    $seen = @(); $done = @{}; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $Skip -notcontains $_ })) {
            $k = $h.ToInt64(); if ($done.ContainsKey($k)) { continue }
            Start-Sleep -Milliseconds 700
            $st = Kid $h 2477
            # (no static 2477: every child's text - an archiver's output window shows it in an edit)
            $t = $(if ($st) { [Drv098f]::GetText($st, 5000).Replace("`r", '') } else { (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -ne 'Button' } | ForEach-Object { [Drv098f]::GetText($_, 5000).Replace("`r", '') } | Where-Object { $_ }) -join "`n") })
            $done[$k] = 1; $seen += ('[' + (Esc ([Drv098f]::Txt($h))) + '] ' + (Esc $t))
            if ($t -match $Rx) { return @{ Text = $t; Win = $h; Seen = $seen } }
            $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($b) { Click $b } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 200
    }
    return @{ Text = $null; Win = [IntPtr]::Zero; Seen = $seen }
}
function Answer-Box([IntPtr]$H) {
    if ($H -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindow($H)) { return }
    $b = Buttons $H | Where-Object { @(1, 2, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
    if ($b) { Click $b } else { Close-Win $H }
    Start-Sleep -Milliseconds 600
}
# letters that only a wrong reading of UTF-8 bytes in the code page 1250/1252 produces
function Garbled([string]$t) { return [bool]($t -match ('[' + (Chars @(0x0102, 0x0139, 0x00C4, 0x00C3, 0x00C5, 0x00E2, 0x20AC, 0xFFFD)) + ']')) }
$Needle = [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD      # "zlutoucky" with accents

# VIEWFIND: the internal viewer, Find of a text that is not there - the message names the text
function Row-ViewFind {
    if (-not (Want 'VIEWFIND')) { return }
    $before = Reports; $id = 0; $view = [IntPtr]::Zero
    try {
        $vdir = $Root + '\view'
        NewDir $vdir
        [IO.File]::WriteAllText(($vdir + '\a.q127'), "plain text`r`nof two lines`r`n")   # an extension no viewer plug-in claims
        $id = Start-P $vdir
        Key $id 0x24; Key $id 0x28                               # "..", a.q127
        $view = Open-ByCmd $id 742 15                            # CM_VIEW
        if ($view -eq [IntPtr]::Zero -or [Drv098f]::Cls($view) -eq '#32770') { Row 'VIEWFIND' 'TEXT' 'FAIL' ('no viewer window: ' + $(if ($view -ne [IntPtr]::Zero) { WinDesc $view } else { 'nothing opened' })); return }
        Start-Sleep -Milliseconds 800
        $known = Get-Tops $id
        Post-Cmd $view 6063                                      # CM_FINDSET
        $dlg = Wait-NewWin $id $known 10
        if ($dlg -eq [IntPtr]::Zero) { Row 'VIEWFIND' 'TEXT' 'FAIL' ('the viewer''s Find dialog did not open; viewer: ' + (WinDesc $view) + '; windows: ' + ((Get-Tops $id | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        [void][Drv098f]::SetText((Find-Ctl $dlg 6125), $Needle, 5000)      # IDC_FINDTEXT
        Click-Ok $dlg
        $want = (Template 12353 "Cannot find the string '%s'.").Replace('%s', $Needle)
        $r = Wait-Box $id ([regex]::Escape($Needle) + '|%s|\?\?') 15 @($dlg)
        $t = $r.Text
        Row 'VIEWFIND' 'TEXT' (V ($t -ceq $want)) ("box text '{0}'; expected '{1}'; boxes: {2}" -f (Esc $t), (Esc $want), ($r.Seen -join ' || '))
        if ($null -eq $t) {
            # the wrong reading does not hold the searched text: show whatever box is there
            $r2 = Wait-Box $id '.' 3 @($dlg); Answer-Box $r2.Win
        }
        else { Answer-Box $r.Win }
    }
    catch { Row 'VIEWFIND' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) { Answer-Box $h }
            if ($view -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($view)) { Close-Win $view; Start-Sleep -Milliseconds 700 }
            End-P 'VIEWFIND' $id $before
        }
        try { if ([IO.Directory]::Exists($LP + $Root + '\view')) { [IO.Directory]::Delete($LP + $Root + '\view', $true) } } catch { }
    }
}

# REGEXP: Find Files with a broken regular expression that holds an accented letter
function Row-RegExp {
    if (-not (Want 'REGEXP')) { return }
    $before = Reports; $id = 0; $find = [IntPtr]::Zero
    try {
        $id = Start-P $DataDir
        $find = Open-ByCmd $id 741 10
        if ($find -eq [IntPtr]::Zero) { throw 'Find (741) opened no window' }
        $pattern = [char]0x017E + '('
        [void][Drv098f]::SetText((Find-Ctl $find 2505), '*.txt', 5000)
        [void][Drv098f]::SetText((Kid $find 2504), $pattern, 5000)
        $chk = Kid $find 2513                                    # IDC_FIND_REGULAR
        if (-not $chk) { throw 'the Regular expression check box (2513) was not found' }
        [void][Drv098f]::Send($chk, 0x00F1, 1, 0, 5000)          # BM_SETCHECK
        Post-Cmd $find 1                                         # Find Now
        $templ = Template 12345 ("The string '%s' is not a valid regular expression." + "`n" + 'Error: %s.')
        $head = $templ.Substring(0, $templ.IndexOf('%s')) + $pattern
        $mid = $templ.Substring($templ.IndexOf('%s') + 2); $mid = $mid.Substring(0, $mid.IndexOf('%s'))
        $r = Wait-Box $id '\(' 15 @($find)
        $t = $r.Text
        $ok = ($null -ne $t) -and $t.StartsWith($head + $mid, [StringComparison]::Ordinal) -and -not (Garbled $t) -and ($t.Length -gt ($head + $mid).Length + 3)
        Row 'REGEXP' 'TEXT' (V $ok) ("box text '{0}'; expected to start with '{1}' and to go on with the reason, readable; boxes: {2}" -f (Esc $t), (Esc ($head + $mid)), ($r.Seen -join ' || '))
        Answer-Box $r.Win
    }
    catch { Row 'REGEXP' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $_ -ne $find })) { Answer-Box $h }
            if ($find -ne [IntPtr]::Zero -and [Drv098f]::IsWindow($find)) { Close-Win $find; Start-Sleep -Milliseconds 600 }
            End-P 'REGEXP' $id $before
        }
    }
}

# PACKERR: Enter on an archive whose external archiver cannot be started - the message of the
# archivers' error handler (numbered inserts): the program's path and the Windows reason, both
# with accented letters, inside the translated text
function Row-PackErr {
    if (-not (Want 'PACKERR')) { return }
    $before = Reports; $id = 0
    $dir = $Root + '\arc'
    try {
        NewDir $dir
        [IO.File]::WriteAllBytes(($dir + '\a.arj'), [byte[]]@(0x60, 0xEA, 0x22, 0x00, 0x1E, 0x06, 0x01, 0x00, 0x10, 0x00, 0x02))
        # the 7-Zip console (it lists *.arj) is pointed to a file that is no program, in a folder
        # with accented letters (a program that is not there at all makes *.arj an ordinary file) -
        # the registry is restored at the end of the probe
        NewDir ($Root + '\prg ' + $Accent)
        $prog = $Root + '\prg ' + $Accent + '\7z.exe'
        [IO.File]::WriteAllText($prog, 'this is not a program')
        $pk = "$RegKey\0.1\Packers & Unpackers\Predefined Packers"
        $set = 0
        foreach ($k in @(Get-ChildItem -LiteralPath ('Registry::HKEY_CURRENT_USER' + $pk.Substring(4)) -ErrorAction SilentlyContinue)) {
            $v = $k.GetValue('Packer Executable')
            if ($v -is [string] -and $v -match '(^|\\)7z[a]?(\.exe)?$') { Set-ItemProperty -LiteralPath $k.PSPath -Name 'Packer Executable' -Value $prog; $set++ }
        }
        if ($set -eq 0) { Row 'PACKERR' 'TEXT' 'NOT DRIVEN' 'no predefined archiver with a 7z program in the configuration'; return }
        $id = Start-P $dir
        Key $id 0x24; Key $id 0x28                               # a.arj (after "..")
        # Enter, sent with a short limit: the message box opens inside the handling of the key
        $list = Get-LeftList $id
        [void][Drv098f]::Send($list, 0x0100, 0x0D, 1, 2500)
        $err193 = '(193) ' + (New-Object ComponentModel.Win32Exception 193).Message      # ERROR_BAD_EXE_FORMAT
        $templ = Template 11072 'Unable to start the archiver "%1". The error was: %2'
        $wantText = $templ.Replace('%1', $prog).Replace('%2', $err193)
        $r = Wait-Box $id '.' 20
        $t = $r.Text
        if ($null -eq $t) { Row 'PACKERR' 'TEXT' 'NOT DRIVEN' ('Enter on a.arj opened no message (an archiver for it is installed, or the file was opened another way); location: ' + (Esc (Get-Loc $id)) + '; windows: ' + ((Get-Tops $id | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        # the reason differs between systems (193 or 216; the program has no text for 216): the
        # sentence up to the reason must be exact, the reason present and readable
        $head = $templ.Substring(0, $templ.IndexOf('%2')).Replace('%1', $prog)
        $exact = $t.StartsWith($head, [StringComparison]::Ordinal) -and ($t.Length -gt $head.Length + 5) -and -not (Garbled $t)
        Row 'PACKERR' 'TEXT' (V $exact) ("box text '{0}'; expected to start with '{1}' and to go on with the reason (e.g. '{2}'); boxes: {3}" -f (Esc $t), (Esc $head), (Esc $err193), ($r.Seen -join ' || '))
        Answer-Box $r.Win
        $x = Serve $id 10
    }
    catch { Row 'PACKERR' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { End-P 'PACKERR' $id $before }
        foreach ($d in @($dir, ($Root + '\prg ' + $Accent))) { try { if ([IO.Directory]::Exists($LP + $d)) { [IO.Directory]::Delete($LP + $d, $true) } } catch { } }
    }
}

# ---- rows that need the clipboard: driven on the visible desktop only (the hidden one has none)
function Clip-Text {
    for ($i = 0; $i -lt 10; $i++) {
        try { if ([Windows.Forms.Clipboard]::ContainsText()) { return [Windows.Forms.Clipboard]::GetText() } } catch { }
        Start-Sleep -Milliseconds 200
    }
    return ''
}
function Clip-Clear { for ($i = 0; $i -lt 5; $i++) { try { [Windows.Forms.Clipboard]::Clear(); return } catch { Start-Sleep -Milliseconds 200 } } }
function Wait-PopupMenu([int]$Id, [double]$Seconds = 10) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        $m = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq 'PopupMenuClass' }) | Select-Object -First 1
        if ($m) { Start-Sleep -Milliseconds 500; return $m }
        Start-Sleep -Milliseconds 100
    }
    return [IntPtr]::Zero
}
function Menu-Key([IntPtr]$Menu, [int]$Vk) {
    [void][Drv098f]::PostMessageW($Menu, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($Menu, 0x0101, [IntPtr]$Vk, [IntPtr]::new(0xC0000001L))
    Start-Sleep -Milliseconds 300
}

# CLIPMSG: Ctrl+C in a message box (WM_COPY to it) - caption and text on the clipboard, readable
function Row-ClipMsg {
    if (-not (Want 'CLIPMSG')) { return }
    $before = Reports; $id = 0
    try {
        Save-Clip
        if (-not $script:ClipOk) { Row 'CLIPMSG' 'TEXT' 'NOT DRIVEN' 'no clipboard that can be saved and restored (the hidden desktop has none)'; return }
        $id = Start-P $Root
        Key $id 0x24; Key $id 0x28; Key $id 0x28                 # "data"
        $dlg = Open-ByCmd $id 727 10                            # CM_COPYFILES
        if ($dlg -eq [IntPtr]::Zero) { throw 'Copy (727) opened no window' }
        [void][Drv098f]::SetText((Find-Ctl $dlg 210), $OutDir2, 5000)
        Click-Ok $dlg
        $r = Wait-Box $id 'denied' 40
        if ($null -eq $r.Text) { Row 'CLIPMSG' 'TEXT' 'FAIL' ('no error box naming "denied"; boxes: ' + ($r.Seen -join ' || ')); return }
        $caption = [Drv098f]::Txt($r.Win)
        $body = $r.Text.Trim()
        try {
            Clip-Clear
            [void][Drv098f]::Send($r.Win, 0x0301, 0, 0, 5000)    # WM_COPY (what Ctrl+C posts)
            Start-Sleep -Milliseconds 600
            $clip = Clip-Text
        }
        finally { Restore-Clip }
        $flat = $clip.Replace("`r", '')
        $ok = $flat.Contains($caption) -and $flat.Contains($body) -and -not (Garbled $clip) -and $caption.Length -gt 3 -and $body.Contains($Err5)
        Row 'CLIPMSG' 'TEXT' (V $ok) ("clipboard after Ctrl+C in the box: '{0}'; holds the caption '{1}': {2}; holds the text '{3}': {4}" -f (Esc $clip), (Esc $caption), $flat.Contains($caption), (Esc $body), $flat.Contains($body))
        $cancel = Buttons $r.Win | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2 } | Select-Object -First 1
        if ($cancel) { Click $cancel } else { Close-Win $r.Win }
        Start-Sleep -Milliseconds 800
        $x = Serve $id 20
    }
    catch { Row 'CLIPMSG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P 'CLIPMSG' $id $before } }
}

# CLIPREG: Registry Editor, context menu > Copy Name (the last item) on a key with an accented
# name and on the translated "(Default)" value
function Row-ClipReg {
    if (-not (Want 'CLIPREG')) { return }
    $before = Reports; $id = 0
    $regRoot = 'HKCU:\Software\TcProbe127c'
    try {
        Save-Clip
        if (-not $script:ClipOk) { Row 'CLIPREG' 'NAME' 'NOT DRIVEN' 'no clipboard that can be saved and restored (the hidden desktop has none)'; return }
        [void](New-Item -Path ($regRoot + '\' + $Accent) -Force)
        Set-Item -LiteralPath ($regRoot + '\' + $Accent) -Value 'x'      # the (Default) value is set
        $defName = '(Default)'
        if ($Lang -ne 'english') { foreach ($line in [IO.File]::ReadAllLines((Join-Path $RepoRoot ("translations\{0}\regedt.slt" -f $Lang)), $Utf8)) { if ($line -match '^1003,\d+,"(.*)"\s*$') { $defName = $Matches[1] } } }
        $id = Start-P $StartDir
        $got = @()
        try {
            foreach ($step in @(@('reg:\HKEY_CURRENT_USER\Software\TcProbe127c', $Accent), @(('reg:\HKEY_CURRENT_USER\Software\TcProbe127c\' + $Accent), $defName))) {
                [void](Do-ChangeDir $id $step[0])
                Sync $id; Start-Sleep -Milliseconds 1500
                Key $id 0x24; Key $id 0x28                       # "..", the first item
                Clip-Clear
                Post-Cmd (Get-Main $id) 858                      # CM_CONTEXTMENU
                $menu = Wait-PopupMenu $id 10
                if ($menu -eq [IntPtr]::Zero) { $got += '<no menu>'; continue }
                Menu-Key $menu 0x23; Menu-Key $menu 0x0D         # End, Enter: Copy Name
                Start-Sleep -Milliseconds 700
                $got += (Clip-Text)
            }
        }
        finally { Restore-Clip }
        Row 'CLIPREG' 'NAME' (V ($got.Count -eq 2 -and $got[0] -ceq $Accent)) ("Copy Name on the key: clipboard '{0}', expected '{1}'" -f (Esc $got[0]), (Esc $Accent))
        Row 'CLIPREG' 'DEFAULT' (V ($got.Count -eq 2 -and $got[1] -ceq $defName)) ("Copy Name on the default value: clipboard '{0}', expected '{1}'" -f (Esc $got[1]), (Esc $defName))
    }
    catch { Row 'CLIPREG' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { End-P 'CLIPREG' $id $before }
        Remove-Item -LiteralPath $regRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc127_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    $fx = Make-Fixture
    Set-Config
    Set-Lang ($Lang + '.slg')
    Out ("mixed_probe (feature 127, issue #7), expect: {0}, language: {1}" -f $Expect, $Lang)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ("Fixture : {0}; Windows text for error 5: '{1}'" -f $fx, (Esc $Err5))
    Out ''
    Row-Log
    Row-Status
    Row-Box
    Row-Progress
    Row-CopyName
    if ($Lang -ne 'english') { Row-RegDel }
    Row-ViewFind
    Row-RegExp
    Row-PackErr
    Row-ClipMsg
    Row-ClipReg
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try {
        if (Test-Path -LiteralPath $DeniedDir) { & icacls.exe $DeniedDir /remove:d ([Security.Principal.WindowsIdentity]::GetCurrent().Name) | Out-Null }
        foreach ($d in @($StartDir, $DataDir, $BigDir, $OutDir2)) { if ([IO.Directory]::Exists($LP + $d)) { [IO.Directory]::Delete($LP + $d, $true) } }
    }
    catch { Out ("Fixture: could not delete under $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $DataDir)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
