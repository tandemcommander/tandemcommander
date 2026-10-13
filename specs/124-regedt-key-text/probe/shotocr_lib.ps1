# Feature 124 probe library: reading OWNER-DRAWN text (panel cells, the information line, status
# bars) - a capture of the window (PrintWindow, works on a hidden desktop), a crop, and the text
# recognition of Windows (Windows.Media.Ocr). Dot-sourced after
# specs\098-long-path-overruns\probe\fix_probe_lib.ps1 (uses Drv098f). Pure ASCII, PowerShell 5.1.
#
# The recognition is evidence, not proof: every row that uses it also saves the crop as a PNG so
# that a person (or the agent) can look at it. Texts are compared exactly first and with the
# diacritics folded second (the recognizer of one language does not know every letter of another).

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
if (-not ('Shot124' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
public static class Shot124
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    // the whole window (with its frame) into a PNG; false when PrintWindow failed
    public static bool Capture(IntPtr h, string file)
    {
        RECT r; if (!GetWindowRect(h, out r)) return false;
        int w = r.Right - r.Left, hh = r.Bottom - r.Top; if (w <= 0 || hh <= 0) return false;
        bool ok;
        using (var bmp = new Bitmap(w, hh))
        {
            using (var g = Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); ok = PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
            bmp.Save(file, System.Drawing.Imaging.ImageFormat.Png);
        }
        return ok;
    }
    // the rectangle of 'child' (screen coordinates) relative to the window rectangle of 'top'
    public static int[] RelRect(IntPtr top, IntPtr child)
    {
        RECT t, c; GetWindowRect(top, out t); GetWindowRect(child, out c);
        return new int[] { c.Left - t.Left, c.Top - t.Top, c.Right - c.Left, c.Bottom - c.Top };
    }
    // does 'hay' hold a substring within edit distance 1 of 'needle'
    public static bool Near(string hay, string needle)
    {
        int n = needle.Length;
        for (int len = n - 1; len <= n + 1; len++)
            for (int i = 0; i + len <= hay.Length; i++)
                if (Dist(hay.Substring(i, len), needle) <= 1) return true;
        return false;
    }
    static int Dist(string a, string b)
    {
        var d = new int[a.Length + 1, b.Length + 1];
        for (int i = 0; i <= a.Length; i++) d[i, 0] = i;
        for (int j = 0; j <= b.Length; j++) d[0, j] = j;
        for (int i = 1; i <= a.Length; i++)
            for (int j = 1; j <= b.Length; j++)
                d[i, j] = Math.Min(Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1), d[i - 1, j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1));
        return d[a.Length, b.Length];
    }
    // crops x,y,w,h of 'src' into 'dst', enlarged 'scale' times (the recognizer needs letters of
    // about 30 px and more); a dark picture (light text on dark) is inverted
    public static void Crop(string src, string dst, int x, int y, int w, int h, int scale)
    {
        using (var b = new Bitmap(src))
        {
            if (x < 0) x = 0; if (y < 0) y = 0;
            if (x + w > b.Width) w = b.Width - x; if (y + h > b.Height) h = b.Height - y;
            using (var o = new Bitmap(w * scale + 40, h * scale + 40))
            {
                using (var g = Graphics.FromImage(o))
                {
                    g.Clear(b.GetPixel(x + 1, y + 1));
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.DrawImage(b, new Rectangle(20, 20, w * scale, h * scale), new Rectangle(x, y, w, h), GraphicsUnit.Pixel);
                }
                long sum = 0; int n = 0;
                for (int yy = 0; yy < o.Height; yy += 7) for (int xx = 0; xx < o.Width; xx += 7) { var p = o.GetPixel(xx, yy); sum += p.R + p.G + p.B; n++; }
                if (n > 0 && sum / n < 380)
                    for (int yy = 0; yy < o.Height; yy++) for (int xx = 0; xx < o.Width; xx++) { var p = o.GetPixel(xx, yy); o.SetPixel(xx, yy, Color.FromArgb(255 - p.R, 255 - p.G, 255 - p.B)); }
                o.Save(dst, System.Drawing.Imaging.ImageFormat.Png);
            }
        }
    }
}
'@
}

[void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
[void][Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType = WindowsRuntime]
[void][Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
$script:OcrAsTask = @([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Ocr-Await($Op, [Type]$T) {
    $task = $script:OcrAsTask.MakeGenericMethod($T).Invoke($null, @($Op))
    if (-not $task.Wait(60000)) { throw 'text recognition timed out' }
    return $task.Result
}
$script:OcrEngine = $null
function Ocr-Languages { return @([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | ForEach-Object { $_.LanguageTag }) }
# the recognized lines of a PNG (an array of strings; empty when nothing was recognized)
function Ocr-File([string]$File) {
    if (-not $script:OcrEngine) {
        $script:OcrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
        if (-not $script:OcrEngine) { throw 'no text recognizer is installed (Windows.Media.Ocr)' }
    }
    $sf = Ocr-Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($File)) ([Windows.Storage.StorageFile])
    $st = Ocr-Await ($sf.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    try {
        $dec = Ocr-Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($st)) ([Windows.Graphics.Imaging.BitmapDecoder])
        $bmp = Ocr-Await ($dec.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
        $res = Ocr-Await ($script:OcrEngine.RecognizeAsync($bmp)) ([Windows.Media.Ocr.OcrResult])
        return @($res.Lines | ForEach-Object { $_.Text })
    }
    finally { $st.Dispose() }
}
# letters and digits only, upper case; with -Fold also without diacritics
function Ocr-Norm([string]$s, [switch]$Fold) {
    if ($null -eq $s) { return '' }
    if ($Fold) {
        $d = $s.Normalize([Text.NormalizationForm]::FormD)
        $sb = New-Object Text.StringBuilder
        foreach ($c in $d.ToCharArray()) { if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($c) -ne [Globalization.UnicodeCategory]::NonSpacingMark) { [void]$sb.Append($c) } }
        $s = $sb.ToString().Replace([string][char]0x00DF, 'ss')
    }
    return (($s.ToUpperInvariant().ToCharArray() | Where-Object { [char]::IsLetterOrDigit($_) }) -join '')
}
# 'exact' / 'folded' / 'no': does the recognized text hold the expected one
function Ocr-Has([string[]]$Lines, [string]$Expected) {
    $all = ($Lines -join ' ')
    if ((Ocr-Norm $all).Contains((Ocr-Norm $Expected))) { return 'exact' }
    $hay = Ocr-Norm $all -Fold; $needle = Ocr-Norm $Expected -Fold
    if ($hay.Contains($needle)) { return 'folded' }
    # a long word with ONE misread letter (the recognizer of another language): 'near'. Only for
    # 12 letters and more - a garbled text has a wrong letter for every accented one, and short
    # words are not given this allowance.
    if ($needle.Length -ge 12 -and [Shot124]::Near($hay, $needle)) { return 'near' }
    return 'no'
}
# capture of window $Top, crop of its child $Child (or of the given relative rectangle), text
function Shot-Read([IntPtr]$Top, [IntPtr]$Child, [string]$Png, [int]$Scale = 3, [int[]]$Rect = $null) {
    $full = $Png + '.full.png'
    $ok = [Shot124]::Capture($Top, $full)
    if (-not $Rect) { $Rect = [Shot124]::RelRect($Top, $Child) }
    [Shot124]::Crop($full, $Png, $Rect[0], $Rect[1], $Rect[2], $Rect[3], $Scale)
    $lines = @(Ocr-File $Png)
    # the recognizer sometimes returns nothing (or a misreading) for a short line at one size:
    # the same crop at two more sizes; all readings are kept, a row passes when one holds the text
    foreach ($s in @(2, 4)) {
        if ($s -eq $Scale) { continue }
        $alt = $Png + ('.x{0}.png' -f $s)
        [Shot124]::Crop($full, $alt, $Rect[0], $Rect[1], $Rect[2], $Rect[3], $s)
        $lines += @(Ocr-File $alt)
        Remove-Item -LiteralPath $alt -Force
    }
    Remove-Item -LiteralPath $full -Force
    return [pscustomobject]@{ Captured = $ok; Lines = $lines; Png = $Png }
}
