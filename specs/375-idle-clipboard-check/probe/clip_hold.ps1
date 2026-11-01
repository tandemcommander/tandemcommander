<#
.SYNOPSIS
    Feature 375 helper: holds the clipboard open (OpenClipboard with a hidden window; the content is
    never changed) until -StopFile exists or -MaxSeconds passed, then closes it.
.DESCRIPTION
    Stands in for an application that keeps the clipboard open: while it holds it, OpenClipboard of
    every other program fails (ERROR_ACCESS_DENIED). Writes 'True' / 'False' (the result of its
    OpenClipboard) into -Ready once it holds it. Nothing is written to the clipboard.
#>
param([string]$Ready, [string]$StopFile, [int]$MaxSeconds = 60)
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Hold375
{
    [DllImport("user32.dll", SetLastError = true)] public static extern bool OpenClipboard(IntPtr h);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool CloseClipboard();
}
'@
Add-Type -AssemblyName System.Windows.Forms
$f = New-Object System.Windows.Forms.Form
$ok = [Hold375]::OpenClipboard($f.Handle)
"holder: OpenClipboard $ok"
if ($Ready) { [IO.File]::WriteAllText($Ready, "$ok") }
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $MaxSeconds -and -not ($StopFile -and (Test-Path -LiteralPath $StopFile))) { Start-Sleep -Milliseconds 50 }
if ($ok) { [void][Hold375]::CloseClipboard() }
$f.Dispose()
"holder: closed after {0:N1} s" -f $sw.Elapsed.TotalSeconds
