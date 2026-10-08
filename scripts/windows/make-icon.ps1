# Draws the app icon (the "slides" glyph on a dark rounded square, as in
# apps/windows/web/favicon.svg) at the usual sizes and packs them into an
# .ico with PNG-compressed frames, which Windows Vista and later read.
param(
    [string]$Out = (Join-Path $PSScriptRoot '..\..\apps\windows\Resources\app.ico')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Draw-Frame([int]$size) {
    $bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $s = $size / 64.0

    function RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $d = $r * 2
        $path.AddArc($x, $y, $d, $d, 180, 90)
        $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
        $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
        $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
        $path.CloseFigure()
        return $path
    }

    $card = [System.Drawing.Color]::FromArgb(255, 38, 38, 38)
    $edge = [System.Drawing.Color]::FromArgb(255, 70, 70, 70)
    $ink = [System.Drawing.Color]::FromArgb(255, 242, 242, 242)
    $accent = [System.Drawing.Color]::FromArgb(255, 10, 132, 255)

    $back = RoundedPath (2 * $s) (2 * $s) (60 * $s) (60 * $s) (14 * $s)
    $g.FillPath((New-Object System.Drawing.SolidBrush $card), $back)
    $g.DrawPath((New-Object System.Drawing.Pen $edge, ([Math]::Max(1, 2 * $s))), $back)

    $stroke = [Math]::Max(1.5, 3.5 * $s)
    $backSlide = RoundedPath (14 * $s) (18 * $s) (36 * $s) (24 * $s) (4 * $s)
    $g.DrawPath((New-Object System.Drawing.Pen $ink, $stroke), $backSlide)
    $frontSlide = RoundedPath (22 * $s) (12 * $s) (36 * $s) (24 * $s) (4 * $s)
    $g.FillPath((New-Object System.Drawing.SolidBrush $card), $frontSlide)
    $g.DrawPath((New-Object System.Drawing.Pen $accent, $stroke), $frontSlide)
    $g.Dispose()
    return $bitmap
}

$sizes = @(256, 64, 48, 32, 24, 16)
$frames = @()
foreach ($size in $sizes) {
    $bitmap = Draw-Frame $size
    $stream = New-Object System.IO.MemoryStream
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $frames += ,@{ Size = $size; Bytes = $stream.ToArray() }
    $stream.Dispose(); $bitmap.Dispose()
}

$writer = New-Object System.IO.BinaryWriter ([System.IO.File]::Create($Out))
$writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]$frames.Count)
$offset = 6 + 16 * $frames.Count
foreach ($frame in $frames) {
    $dimension = if ($frame.Size -ge 256) { 0 } else { $frame.Size }
    $writer.Write([Byte]$dimension); $writer.Write([Byte]$dimension)
    $writer.Write([Byte]0); $writer.Write([Byte]0)
    $writer.Write([UInt16]1); $writer.Write([UInt16]32)
    $writer.Write([UInt32]$frame.Bytes.Length); $writer.Write([UInt32]$offset)
    $offset += $frame.Bytes.Length
}
foreach ($frame in $frames) { $writer.Write($frame.Bytes) }
$writer.Dispose()
Write-Host "Icon written to $Out ($($frames.Count) frames)"
