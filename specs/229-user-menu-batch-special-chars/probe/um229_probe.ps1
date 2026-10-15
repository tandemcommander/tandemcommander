<#
.SYNOPSIS
    Feature 229 probe: a User Menu item run "through a batch file" gets names holding the batch
    file's special characters (%, ^, !, &) unchanged - never another file.

.DESCRIPTION
    The machinery of 226's probe (um226_probe.ps1): User Menu items (the registry key replaced for
    the run) copy the focused file with cmd's "copy" into <root>\out\<row>.txt. Each row's folder
    also holds a DECOY - the name the special character would turn the real one into; PASS = the
    real file's content copied (FAIL "decoy" = another file was acted on).
      PCT      50%off.txt (decoy 50off.txt: a lone % dropped)
      PCTVAR   a%OS%b.txt (decoy aWindows_NTb.txt: %OS% expanded)
      PCTCALL  a%%OS%%b.txt (decoy a%OS%b.txt / aWindows_NTb.txt: "call" expands once more)
      CARET    a^b.txt (decoy a^^b.txt: "call" doubles a caret inside quotes, no escape survives it):
               PASS = refused with a message, nothing copied
      BANG     a!b.txt (delayed expansion is off by default - the control)
      AMP      a&b.txt (inside quotes - the control)
      PCTU     50%off + CJK letters (the UTF-8 route; decoy without the %)
      PCTDIR   the folder p%OS%q, Initial Directory $(FullPath), Arguments /y "$(Name)" (decoy
               folder pWindows_NTq with its own a.txt); the panel enters the folder from its parent
               (a path on the program's command line has its %OS% expanded - another folder)
      AMPU     a&b.txt inserted without quotes (decoy "a": the line ran "copy a" and the command
               "b.txt"): PASS = refused with a message, nothing copied
      LIST     50%off.txt through $(ListOfSelectedNames) (unquoted - no space): PASS = copied
      WIDTH    50%off.txt through "$(Name:20)" (padded): PASS = copied
      ENV      $[TC229V] holding the full name of a%OS%b.txt (set in the program's environment)
      MULTI    1.txt and a^b.txt selected: PASS = refused, nothing copied (not even 1.txt)
      DELAYED  a!b.txt with cmd's DelayedExpansion set to 1 for the row (HKCU value backed up and
               restored; the program starts cmd with /V:OFF): PASS = copied
      LISTQ    "a b&c.txt" through "$(ListOfSelectedFullNames)" quoted by the user (the list quotes
               the name itself: ""...a b&c.txt"" - the '&' outside quotes): PASS = refused
      COMMA    Smith,John.txt through $(ListOfSelectedNames) (decoy Smith: cmd splits at ','):
               PASS = copied (the list quotes such a name now)
      INITVAR  the Initial Directory typed as C:%TC229P% (the user's own batch variable, set in the
               program's environment to the folder "real" without its drive), its a.txt the real
               one; the panel's own a.txt is the decoy: PASS = the real one copied (what the user
               typed keeps its batch meaning)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc229'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$UmKey = 'Software\Tandem Commander\0.1\User Menu'
$CzDir = 'p' + [char]0x0159 + [char]0x00ED + 'li' + [char]0x0161
$CzFile = [string][char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD + '.txt'
$JpDir = [string][char]0x6F22 + [char]0x5B57
$JpFile = [string][char]0x4E2D + [char]0x6587 + '.txt'

# row -> folder, file, the item's arguments, its initial directory, keep the shell open, kind, decoy
# (the decoy is a file name in the row's folder, or "folder|file" for a decoy folder beside it)
$Cases = [ordered]@{
    'PCT'     = @('plain', '50%off.txt', '/y "$(FullName)"', '', 0, '', '50off.txt')
    'PCTVAR'  = @('plain', 'a%OS%b.txt', '/y "$(FullName)"', '', 0, '', 'aWindows_NTb.txt')
    'PCTCALL' = @('plain', 'a%%OS%%b.txt', '/y "$(FullName)"', '', 0, '', 'a%OS%b.txt')
    'CARET'   = @('plain', 'a^b.txt', '/y "$(FullName)"', '', 0, 'refuse', 'a^^b.txt')
    'BANG'    = @('plain', 'a!b.txt', '/y "$(FullName)"', '', 0, '', 'ab.txt')
    'AMP'     = @('plain', 'a&b.txt', '/y "$(FullName)"', '', 0, '', 'a.txt')
    'PCTU'    = @('plain', ('50%off' + $JpFile), '/y "$(FullName)"', '', 0, '', ('50off' + $JpFile))
    'PCTDIR'  = @('p%OS%q', 'a.txt', '/y "$(Name)"', '$(FullPath)', 0, 'enter', 'pWindows_NTq|a.txt')
    'AMPU'    = @('plain', 'a&b.txt', '/y $(FullName)', '', 0, 'refuse', 'a')
    'LIST'    = @('plain', '50%off.txt', '/y $(ListOfSelectedNames)', '', 0, '', '50off.txt')
    'WIDTH'   = @('plain', '50%off.txt', '/y "$(Name:20)"', '', 0, '', '50off.txt')
    'ENV'     = @('plain', 'a%OS%b.txt', '/y "$[TC229V]"', '', 0, 'env', 'aWindows_NTb.txt')
    'MULTI'   = @('plain', 'a^b.txt', '/y "$(FullName)"', '', 0, 'multi', '')
    'DELAYED' = @('plain', 'a!b.txt', '/y "$(FullName)"', '', 0, 'delayed', 'ab.txt')
    'LISTQ'   = @('plain', 'a b&c.txt', '/y "$(ListOfSelectedFullNames)"', '', 0, 'refuse', 'a b')
    'COMMA'   = @('plain', 'Smith,John.txt', '/y $(ListOfSelectedNames)', '', 0, '', 'Smith')
    'INITVAR' = @('plain', 'a.txt', '/y "$(Name)"', 'C:%TC229P%', 0, 'initvar', '')
}
$ChcpLine = '@"' + [Environment]::SystemDirectory + '\chcp.com" {0}>nul{1}'
$AutoRunKey = 'Software\Microsoft\Command Processor'
$script:AutoRunSaved = $null; $script:AutoRunSet = $false
$script:DelSaved = $null; $script:DelSet = $false
function Set-Delayed {
    $had = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($AutoRunKey); $keyExisted = ($null -ne $had); if ($had) { $had.Close() }
    $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($AutoRunKey)
    $script:DelSaved = @{ KeyExisted = $keyExisted; Exists = ($k.GetValueNames() -contains 'DelayedExpansion'); Value = $k.GetValue('DelayedExpansion', $null) }
    $k.SetValue('DelayedExpansion', 1, 'DWord'); $k.Close(); $script:DelSet = $true
}
function Restore-Delayed {
    if (-not $script:DelSet) { return }
    $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($AutoRunKey)
    if ($script:DelSaved.Exists) { $k.SetValue('DelayedExpansion', $script:DelSaved.Value, 'DWord') } else { $k.DeleteValue('DelayedExpansion', $false) }
    $empty = ($k.ValueCount -eq 0 -and $k.SubKeyCount -eq 0); $k.Close(); $script:DelSet = $false
    if (-not $script:DelSaved.KeyExisted -and $empty) { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($AutoRunKey, $false) }
    $left = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($AutoRunKey); $keyNow = ($null -ne $left); if ($left) { $left.Close() }
    Out ("DelayedExpansion restored: value existed {0}; key existed {1}, exists {2}" -f $script:DelSaved.Exists, $script:DelSaved.KeyExisted, $keyNow)
}
function Set-AutoRun {   # cmd runs this before every batch file: the console then is not at the OEM code page
    $had = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($AutoRunKey); $keyExisted = ($null -ne $had); if ($had) { $had.Close() }
    $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($AutoRunKey)
    $script:AutoRunSaved = @{ KeyExisted = $keyExisted; Exists = ($k.GetValueNames() -contains 'AutoRun'); Value = $k.GetValue('AutoRun', $null, 'DoNotExpandEnvironmentNames'); Kind = $(if ($k.GetValueNames() -contains 'AutoRun') { $k.GetValueKind('AutoRun') } else { $null }) }
    # the marker shows that cmd ran it (a row whose AutoRun never ran proves nothing)
    $k.SetValue('AutoRun', ('chcp 65001>nul & echo ran>"{0}\autorun.txt"' -f $OutDir), 'String'); $k.Close(); $script:AutoRunSet = $true
}
function Restore-AutoRun {
    if (-not $script:AutoRunSet) { return }
    $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($AutoRunKey)
    if ($script:AutoRunSaved.Exists) { $k.SetValue('AutoRun', $script:AutoRunSaved.Value, $script:AutoRunSaved.Kind) } else { $k.DeleteValue('AutoRun', $false) }
    $now = $k.GetValue('AutoRun', $null, 'DoNotExpandEnvironmentNames'); $empty = ($k.ValueCount -eq 0 -and $k.SubKeyCount -eq 0); $k.Close(); $script:AutoRunSet = $false
    if (-not $script:AutoRunSaved.KeyExisted -and $empty) { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey($AutoRunKey, $false) }
    $left = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($AutoRunKey); $keyNow = ($null -ne $left); if ($left) { $left.Close() }
    Out ("AutoRun restored: value existed {0}, now '{1}'; key existed {2}, exists {3}" -f $script:AutoRunSaved.Exists, $now, $script:AutoRunSaved.KeyExisted, $keyNow)
}
function Many-Names([string]$Kind) {
    $n = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt 40; $i++) {
        $m = $(if ($Kind -eq 'manycz') { 1 } else { $i % 3 })
        $base = $(if ($m -eq 0) { [string][char]0x4E2D * 25 } elseif ($m -eq 1) { ([string][char]0x017E + [char]0x0159) * 15 } else { 'plain_ascii_name_' * 2 })
        [void]$n.Add(('{0:D2} {1} {2}.txt' -f $i, $base, ('x' * 30)))
    }
    return $n
}
$OemCp = [Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
# cmd searches the current folder for a command unless this variable is set; Windows does not set
# it - a shell the probe is started from may (then the PLANT row could not fail): removed from this
# process (the program started below inherits that)
$NoCurDir = $env:NoDefaultCurrentDirectoryInExePath
Remove-Item Env:NoDefaultCurrentDirectoryInExePath -ErrorAction SilentlyContinue

function Seed-UserMenu {
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($UmKey, $false)
    $i = 0
    foreach ($c in $Cases.Keys) {
        $i++
        $v = $Cases[$c]
        $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($UmKey + '\' + $i)
        $k.SetValue('Item Name', ('tc229 ' + $c), 'String'); $k.SetValue('Command', 'copy', 'String')
        $target = $(if ($v[5] -like 'many*') { $OutDir + '\' + $c + '\$(Name)' } else { $OutDir + '\' + $c + '.txt' })
        $k.SetValue('Arguments', ($v[2] + ' "' + $target + '"'), 'String'); $k.SetValue('Initial Directory', $v[3], 'String')
        $k.SetValue('Execute Through Shell', 1, 'DWord'); $keep = ($v[4] -eq 1)
        $k.SetValue('Close Shell Window', $(if ($keep) { 0 } else { 1 }), 'DWord'); $k.SetValue('Open Shell Window', $(if ($keep) { 1 } else { 0 }), 'DWord')
        $k.SetValue('Icon', '', 'String'); $k.SetValue('Type', 0, 'DWord'); $k.SetValue('Show In Toolbar', 0, 'DWord')
        $k.Close()
    }
}

function Run-Case([string]$Case, [int]$Index) {
    if (-not (Want $Case)) { return }
    $v = $Cases[$Case]
    $dir = $Root + '\' + $Case + '\' + $v[0]
    NewDir $dir
    $content = 'content of ' + $Case
    $many = @()
    if ($v[5] -like 'many*') {
        $many = @(Many-Names $v[5])
        foreach ($m in $many) { [IO.File]::WriteAllText($LP + $dir + '\' + $m, ('content of ' + $m.Substring(0, 2)), (New-Object Text.ASCIIEncoding)) }
        NewDir ($OutDir + '\' + $Case)
    }
    else { [IO.File]::WriteAllText($LP + $dir + '\' + $v[1], $content, (New-Object Text.ASCIIEncoding)) }
    $planted = $OutDir + '\planted.txt'
    if ([IO.File]::Exists($LP + $planted)) { [IO.File]::Delete($LP + $planted) }
    if ($v[5] -eq 'plant') { [IO.File]::WriteAllText($LP + $dir + '\chcp.bat', ('@echo planted>"{0}"' -f $planted) + "`r`n", (New-Object Text.ASCIIEncoding)) }
    if ($v[5] -eq 'cwdrel') { [IO.File]::WriteAllText($LP + $StartDir + '\a.txt', 'WRONG', (New-Object Text.ASCIIEncoding)) }
    if ($v.Count -gt 6 -and $v[6]) {
        if ($v[6].Contains('|')) { $p = $v[6].Split('|'); $dd = $Root + '\' + $Case + '\' + $p[0]; NewDir $dd; [IO.File]::WriteAllText($LP + $dd + '\' + $p[1], 'DECOY', (New-Object Text.ASCIIEncoding)) }
        else { [IO.File]::WriteAllText($LP + $dir + '\' + $v[6], 'DECOY', (New-Object Text.ASCIIEncoding)) }
    }
    if ($v[5] -eq 'multi') { [IO.File]::WriteAllText($LP + $dir + '\1.txt', 'one', (New-Object Text.ASCIIEncoding)) }
    $env:TC229V = $dir + '\' + $v[1]   # ENV row (inherited by the program started below)
    if ($v[5] -eq 'initvar') {
        $real = $Root + '\' + $Case + '\real'; NewDir $real
        [IO.File]::WriteAllText($LP + $real + '\a.txt', $content, (New-Object Text.ASCIIEncoding))
        [IO.File]::WriteAllText($LP + $dir + '\a.txt', 'DECOY', (New-Object Text.ASCIIEncoding))
        $env:TC229P = $real.Substring(2)  # INITVAR: the folder without "C:"
    }
    $out = $(if ($many.Count) { $OutDir + '\' + $Case + '\' + $many[-1] } else { $OutDir + '\' + $Case + '.txt' })
    $id = 0; $before = Reports
    try {
        if ($v[5] -eq 'enter') {   # a command-line path has its %VAR% expanded: start in the parent, Enter on the folder ('%' sorts first)
            $id = Start-Tc ($Root + '\' + $Case)
            [void](Serve $id 10)
            Key $id 0x24; Key $id 0x28; Key $id 0x0D; Start-Sleep -Milliseconds 1500
        }
        else { $id = Start-Tc $dir }
        $panelAt = Get-Loc $id   # the folder the panel really shows (a command-line path may be expanded)
        [void](Serve $id 10)
        if ($many.Count -or $v[5] -eq 'multi') { Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800 }   # Select All
        else {   # select exactly the real file (the decoy sorts anywhere): Select (841) with its name as the mask
            $sd = Open-ByCmd $id 841 10
            $edits = @([Drv098f]::Kids($sd) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' })
            if ($sd -eq [IntPtr]::Zero -or -not $edits.Count) { Row $Case 'RUN' 'NOT DRIVEN' 'the Select dialog or its edit was not found'; return }
            [void][Drv098f]::SetText($edits[0], $v[1], 5000); Click-Ok $sd; Start-Sleep -Milliseconds 800
        }
        Start-Sleep -Milliseconds 500
        if ($v[5] -eq 'autorun') { Set-AutoRun }
        if ($v[5] -eq 'delayed') { Set-Delayed }
        Post-Cmd (Get-Main $id) (3000 + $Index)
        $sw = [Diagnostics.Stopwatch]::StartNew(); $msgs = New-Object System.Collections.ArrayList
        while ($sw.Elapsed.TotalSeconds -lt 15 -and -not [IO.File]::Exists($LP + $out)) {
            foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void]$msgs.Add((WinDesc $h)); Close-Win $h }
            Start-Sleep -Milliseconds 250
        }
        Start-Sleep -Milliseconds 500
        $got = $(if ([IO.File]::Exists($LP + $out)) { [IO.File]::ReadAllText($LP + $out) } else { $null })
        $ok = ($got -ceq $content)
        $batFacts = ''
        if ($v[5] -eq 'autorun') {
            Restore-AutoRun
            $ar = [IO.File]::Exists($LP + $OutDir + '\autorun.txt')
            $ok = $ok -and $ar
            $batFacts = ('; AutoRun ran: {0}' -f $ar)
        }
        if ($v[5] -eq 'cdfail') { $ok = ($null -eq $got) }
        if ($v[5] -eq 'refuse' -or $v[5] -eq 'multi') { $ok = ($null -eq $got) -and ($msgs.Count -gt 0) }
        if ($v[5] -eq 'delayed') { Restore-Delayed }
        if ($got -ceq 'DECOY') { $batFacts += '; ANOTHER FILE (the decoy) was copied' }
        $batFacts += ('; panel at ' + (Esc $panelAt))
        if ($many.Count) {
            $copied = @($many | Where-Object { $f = $OutDir + '\' + $Case + '\' + $_; [IO.File]::Exists($LP + $f) -and ([IO.File]::ReadAllText($LP + $f) -ceq ('content of ' + $_.Substring(0, 2))) })
            $ok = ($copied.Count -eq $many.Count)
            $got = ('{0} of {1} copied (batch about {2} bytes)' -f $copied.Count, $many.Count, (($many | ForEach-Object { (U8Len ($dir + '\' + $_)) + 80 }) | Measure-Object -Sum).Sum)
        }
        if ($v[5] -eq 'plant') {
            $pl = [IO.File]::Exists($LP + $planted)
            $ok = $ok -and -not $pl
            $batFacts = ('; planted chcp.bat ran: {0}' -f $pl)
        }
        if ($v[4] -eq 1) {   # the shell stays open: read its batch file, then end that shell
            $kids = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId={0}" -f $id) | Where-Object { $_.Name -ieq 'cmd.exe' })
            $bats = @(Get-ChildItem -LiteralPath $env:TEMP -Directory -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) } |
                    ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -Filter 'usermenu.bat' -ErrorAction SilentlyContinue })
            if ($bats.Count -ne 1) { $ok = $false; $batFacts = ('; batch files found: {0}' -f $bats.Count) }
            else {
                $bytes = [IO.File]::ReadAllBytes($bats[0].FullName)
                $oemText = [Text.Encoding]::GetEncoding($OemCp).GetString($bytes)
                $u8Text = $Utf8.GetString($bytes)
                $full = $dir + '\' + $v[1]
                $lines = @($(if ($Case -eq 'ACCKEEP') { $oemText } else { $u8Text }) -split "`r`n" | Where-Object { $_ })
                if ($Case -eq 'ACCKEEP') { $bok = ($lines[0] -ceq ($ChcpLine -f $OemCp, ' || exit /b 1')) -and ($lines.Count -eq 2) -and $oemText.Contains($full) }
                else { $bok = ($lines[0] -ceq ($ChcpLine -f 65001, ' || exit /b 1')) -and ($lines[-1] -ceq ($ChcpLine -f $OemCp, '')) -and $u8Text.Contains($full) }
                $ok = $ok -and $bok
                $batFacts = ("; batch file ({0} bytes, read as {1}): '{2}'" -f $bytes.Length, $(if ($Case -eq 'ACCKEEP') { 'OEM ' + $OemCp } else { 'UTF-8' }), (Esc $(if ($Case -eq 'ACCKEEP') { $oemText } else { $u8Text })))
            }
            foreach ($c in $kids) { Stop-Process -Id $c.ProcessId -Force -ErrorAction SilentlyContinue }
            $batFacts += ('; shells ended: {0}' -f $kids.Count)
        }
        Row $Case 'RUN' (V $ok) (("folder {0}, file {1}: {2}; windows: {3}" -f (Esc $v[0]), (Esc $v[1]), $(if ($null -eq $got) { 'copy missing' } elseif ($many.Count) { $got } else { "copy '" + (Esc $got) + "'" }), $(if ($msgs.Count) { ($msgs | Select-Object -Unique) -join ' || ' } else { 'none' })) + $batFacts)
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc229_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir
    Set-Config
    Seed-UserMenu
    Out ("um229_probe (feature 229) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; OEM CP {3}; NoDefaultCurrentDirectoryInExePath was '{4}' (removed for the run)" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), $OemCp, $NoCurDir)
    Out ''
    $i = 0
    foreach ($c in @($Cases.Keys)) { Run-Case $c $i; $i++ }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    try { Restore-Delayed } catch { Out ('DelayedExpansion restore: ' + $_.Exception.Message) }
    try { Restore-AutoRun } catch { Out ('AutoRun restore: ' + $_.Exception.Message) }
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
exit $nf
