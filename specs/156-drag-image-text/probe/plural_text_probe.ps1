<#
.SYNOPSIS
    Feature 156 probe: the "N files" texts of a selection are shown whole in a language with accents
    (reported for 0.1.9: dragging several files showed "vybrané 2 soubory" with "?" for "é").

.DESCRIPTION
    The UI language is Czech (czech.slg); a folder with five files and t.zip holding five files.
    Five, because the Czech plural "souborů" (5 files) has an accented letter. Rows read the dialog's
    texts (wide WM_GETTEXT of every child) and look for the selection's text:
      pack     the folder's five files selected, Pack (CM_PACK 850): "Zabalit 5 souborů ..."
      unpack   in t.zip, all five selected, Copy (F5, 727): "Kopírovat 5 souborů z archivu do"
      delete   in t.zip, all five selected, Delete (F8, 729): "Opravdu chcete odstranit 5 souborů z
               archivu?" (answered No)
    PASS = the text holds "5 souborů" exactly (U+016F), no '?' and no U+FFFD in it.
    The drag image (CreateDragImage, the reported case) needs a mouse drag - NOT DRIVEN here; it
    builds its text through the same call as these dialogs.

    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc156'
$StartDir = $Root + '\start'
$U = [string][char]0x016F
$Want = '5 soubor' + $U
function Hex([string]$s) { return (($s.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' ') }
# the texts of a dialog's children, wide
function Dlg-Texts([IntPtr]$Dlg) { return @([Drv098f]::Kids($Dlg) | ForEach-Object { [Drv098f]::GetText($_, 3000) } | Where-Object { $_ }) }
function Run-Row([string]$Case, [string]$Dir, [int]$Cmd, [string]$Enter, [string]$Exact, [switch]$One, [string]$Rx) {
    if (-not (Want $Case)) { return }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $Dir
        if ($Enter) { [void](Do-ChangeDir $id $Enter); [void](Serve $id 8) }
        if ($One) { Key $id 0x24; Key $id 0x28; Start-Sleep -Milliseconds 400 }   # Home, Down: the first file (no selection)
        else { Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 600 }      # select all
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) $Cmd
        $dlg = Wait-NewWin $id $known 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'TEXT' 'FAIL' 'no dialog'; return }
        Start-Sleep -Milliseconds 600
        $texts = Dlg-Texts $dlg
        $t = @($texts | Where-Object { $_ -match 'archiv' }) | Select-Object -First 1
        if (-not $t) { $t = [Drv098f]::Txt($dlg) }
        if ($Rx) { $ok = $t -cmatch $Rx; $Exact = $Rx } else { $ok = $t -ceq $Exact }
        Row $Case 'TEXT' (V $ok) ("want '{0}': '{1}'" -f (Esc $Exact), (Esc $t))
        # cancel: No / Cancel
        $b = Buttons $dlg | Where-Object { @(7, 2) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
        if ($b) { Click $b } else { Close-Win $dlg }
        Start-Sleep -Milliseconds 800
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc156_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    $files = $Root + '\files'; NewDir $files
    foreach ($i in 1..5) { WriteFile ("{0}\a{1}.txt" -f $files, $i) ('file ' + $i) }
    $arcDir = $Root + '\arc'; NewDir $arcDir
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($files, $arcDir + '\t.zip')
    Set-Config
    & cmd.exe /c "reg query `"$RegKey\Settings\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) { & reg.exe add "$RegKey\Settings\Configuration" /v 'Language' /t REG_SZ /d 'czech.slg' /f | Out-Null }
    Out ("plural_text_probe (feature 156), UI language czech.slg")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; desktop '{2}'" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), [DeskLib098]::Name())
    Out ''
    $r = [string][char]0x0159; $i = [string][char]0x00ED; $q = [string][char]0x201E; $qq = [string][char]0x201C
    Run-Row 'pack' $files 850 $null ('P' + $r + 'idat 5 soubor' + $U + ' do archivu')
    Run-Row 'unpack' $arcDir 727 ($arcDir + '\t.zip') ('Kop' + $i + 'rovat 5 soubor' + $U + ' z archivu do')
    Run-Row 'delete' $arcDir 729 ($arcDir + '\t.zip') ('Opravdu chcete odstranit 5 soubor' + $U + ' z archivu?')
    # controls: one file (the name branch, UTF-8 already) - the dialog shows a UTF-8 subject whole
    Run-Row 'pack-one' $files 850 $null '' -One -Rx ('^P' + $r + 'idat .*a1\.txt.* do archivu$')
    Run-Row 'unpack-one' $arcDir 727 ($arcDir + '\t.zip') '' -One -Rx ('^Kop' + $i + 'rovat .*a1\.txt.* z archivu do$')
    Row 'drag' 'TEXT' 'NOT DRIVEN' 'the drag image needs a mouse drag (CreateDragImage builds its text with the same ExpandPluralFilesDirs call)'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; registry restored+identical: {4}" -f $np, $nf, $nn, $leftover.Count, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
