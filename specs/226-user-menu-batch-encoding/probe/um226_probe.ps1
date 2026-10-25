<#
.SYNOPSIS
    Feature 226 probe: a User Menu item run "through a batch file" (Execute Through Shell) gets
    the names and folders it was given - also with letters outside ASCII.

.DESCRIPTION
    The User Menu (registry key User Menu, replaced for the run) holds items that copy the focused
    file with cmd's own "copy" command into <root>\out\<row>.txt (ASCII). Each row has its own
    folder <root>\<row>\<folder>\<file>; the panel shows that folder, End focuses the file, the
    item's command (CM_USERMENU_MIN + n) runs. PASS = the copy exists with the file's content.
      ASCII    folder "plain", file "a.txt"; Arguments /y "$(FullName)" ... (the control)
      ACC      folder and file with Czech letters (r-caron, z-caron, u-ring), $(FullName)
      ACCDIR   the same names; Initial Directory $(FullPath), Arguments /y "$(Name)" ...: the
               batch file changes into the folder first
      CJK      folder and file with CJK letters (no OEM code page holds them on a Czech system)
      CJKDIR   the CJK names through the Initial Directory
      ACCKEEP  as ACC, the shell window kept open (Open Shell Window, not closed): the batch file is
               read while it runs - PASS = the first line switches the console to the OEM code page
               (chcp.com by its full path), the names in the OEM code page
      CJKKEEP  as CJK, kept open: PASS = the first line switches to UTF-8, the last one back to the
               OEM code page (both chcp.com by its full path), the names in UTF-8
      MANY     40 files selected (CJK, Czech and ASCII names of 60+ letters - a batch file over 8 KB,
               one line per file), each copied to out\MANY\<its name>: PASS = all 40 copied
      MANYCZ   40 files with Czech names only (the OEM code page, one line per file): PASS = all copied
      PLANT    as CJK, the folder also holds chcp.bat writing out\planted.txt (cmd looks for a bare
               "chcp" in the current folder first): PASS = copied and planted.txt not written
      PLANTA   the same in an ASCII folder (CJK file name - a UTF-8 batch file)
      CWDREL   a Czech folder holding a.txt, no Initial Directory, Arguments /y "$(Name)": the command
               runs in the current folder, which must be the panel's - the other panel (start)
               holds another a.txt ("WRONG"): PASS = the left panel's a.txt copied
      CDFAIL   the Initial Directory does not exist, Arguments /y "$(Name)": PASS = nothing copied
               (the batch file ends; it must not run the command in the panel's folder)
      AUTORUN  as ACC with cmd's AutoRun set to "chcp 65001>nul" for the row (HKCU value backed up and
               restored): PASS = copied (the batch file switches the console to the OEM code page)
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
$Root = $TempRoot + '\tc226'
$StartDir = $Root + '\start'
$OutDir = $Root + '\out'
$UmKey = 'Software\Tandem Commander\Settings\User Menu'
$CzDir = 'p' + [char]0x0159 + [char]0x00ED + 'li' + [char]0x0161
$CzFile = [string][char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD + '.txt'
$JpDir = [string][char]0x6F22 + [char]0x5B57
$JpFile = [string][char]0x4E2D + [char]0x6587 + '.txt'

# row -> folder, file, the item's arguments, its initial directory, keep the shell open, kind
$Cases = [ordered]@{
    'ASCII'   = @('plain', 'a.txt', '/y "$(FullName)"', '', 0, '')
    'ACC'     = @($CzDir, $CzFile, '/y "$(FullName)"', '', 0, '')
    'ACCDIR'  = @($CzDir, $CzFile, '/y "$(Name)"', '$(FullPath)', 0, '')
    'CJK'     = @($JpDir, $JpFile, '/y "$(FullName)"', '', 0, '')
    'CJKDIR'  = @($JpDir, $JpFile, '/y "$(Name)"', '$(FullPath)', 0, '')
    'ACCKEEP' = @($CzDir, $CzFile, '/y "$(FullName)"', '', 1, '')
    'CJKKEEP' = @($JpDir, $JpFile, '/y "$(FullName)"', '', 1, '')
    'MANY'    = @($JpDir, '', '/y "$(FullName)"', '', 0, 'many')
    'MANYCZ'  = @($CzDir, '', '/y "$(FullName)"', '', 0, 'manycz')
    'PLANT'   = @($JpDir, $JpFile, '/y "$(FullName)"', '', 0, 'plant')
    'PLANTA'  = @('plantdir', $JpFile, '/y "$(FullName)"', '', 0, 'plant')
    'CWDREL'  = @($CzDir, 'a.txt', '/y "$(Name)"', '', 0, 'cwdrel')
    'CDFAIL'  = @('plain', 'a.txt', '/y "$(Name)"', ($TempRoot + '\tc226\missing'), 0, 'cdfail')
    'AUTORUN' = @($CzDir, $CzFile, '/y "$(FullName)"', '', 0, 'autorun')
}
$ChcpLine = '@"' + [Environment]::SystemDirectory + '\chcp.com" {0}>nul{1}'
$AutoRunKey = 'Software\Microsoft\Command Processor'
$script:AutoRunSaved = $null; $script:AutoRunSet = $false
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
        $k.SetValue('Item Name', ('tc226 ' + $c), 'String'); $k.SetValue('Command', 'copy', 'String')
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
    $out = $(if ($many.Count) { $OutDir + '\' + $Case + '\' + $many[-1] } else { $OutDir + '\' + $Case + '.txt' })
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $dir
        [void](Serve $id 10)
        if ($many.Count) { Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800 }   # Select All
        else { Key $id 0x24; Key $id 0x23 }
        Start-Sleep -Milliseconds 500
        if ($v[5] -eq 'autorun') { Set-AutoRun }
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

$backup = Join-Path $env:TEMP 'tc226_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $OutDir
    Set-Config
    Seed-UserMenu
    Out ("um226_probe (feature 226) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; OEM CP {3}; NoDefaultCurrentDirectoryInExePath was '{4}' (removed for the run)" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), $OemCp, $NoCurDir)
    Out ''
    $i = 0
    foreach ($c in @($Cases.Keys)) { Run-Case $c $i; $i++ }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
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
