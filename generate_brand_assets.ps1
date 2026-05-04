$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function New-BrandBitmap {
    param(
        [int]$Size
    )

    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $backgroundRect = New-Object System.Drawing.RectangleF 0, 0, $Size, $Size
    $backgroundBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $backgroundRect,
        [System.Drawing.ColorTranslator]::FromHtml('#0D1420'),
        [System.Drawing.ColorTranslator]::FromHtml('#1A2332'),
        45
    )
    $graphics.FillRectangle($backgroundBrush, $backgroundRect)

    $accentBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#FF8C42'))
    $accentPoints = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF ($Size * 0.08), ($Size * 0.18)),
        (New-Object System.Drawing.PointF ($Size * 0.76), ($Size * 0.18)),
        (New-Object System.Drawing.PointF ($Size * 0.92), ($Size * 0.04)),
        (New-Object System.Drawing.PointF ($Size * 0.24), ($Size * 0.04))
    )
    $graphics.FillPolygon($accentBrush, $accentPoints)

    $shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 255, 140, 66))
    $graphics.FillEllipse($shadowBrush, $Size * 0.12, $Size * 0.58, $Size * 0.76, $Size * 0.24)

    $font = New-Object System.Drawing.Font('Segoe UI', ($Size * 0.34), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
    $stringFormat = New-Object System.Drawing.StringFormat
    $stringFormat.Alignment = [System.Drawing.StringAlignment]::Center
    $stringFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
    $graphics.DrawString('ATR', $font, $textBrush, (New-Object System.Drawing.RectangleF 0, ($Size * 0.12), $Size, ($Size * 0.72)), $stringFormat)

    $subtitleFont = New-Object System.Drawing.Font('Segoe UI', ($Size * 0.07), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $subtitleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#D7E2F0'))
    $graphics.DrawString('LOCACOES', $subtitleFont, $subtitleBrush, (New-Object System.Drawing.RectangleF 0, ($Size * 0.70), $Size, ($Size * 0.14)), $stringFormat)

    $backgroundBrush.Dispose()
    $accentBrush.Dispose()
    $shadowBrush.Dispose()
    $font.Dispose()
    $subtitleFont.Dispose()
    $textBrush.Dispose()
    $subtitleBrush.Dispose()
    $stringFormat.Dispose()
    $graphics.Dispose()

    return $bitmap
}

function Save-Png {
    param(
        [int]$Size,
        [string]$Path
    )

    $bitmap = New-BrandBitmap -Size $Size
    try {
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }
}

function Save-IcoFromPng {
    param(
        [string]$PngPath,
        [string]$IcoPath
    )

    $pngBytes = [System.IO.File]::ReadAllBytes($PngPath)
    $memoryStream = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter $memoryStream

    $writer.Write([UInt16]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]1)
    $writer.Write([Byte]0)
    $writer.Write([Byte]0)
    $writer.Write([Byte]0)
    $writer.Write([Byte]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]32)
    $writer.Write([UInt32]$pngBytes.Length)
    $writer.Write([UInt32]22)
    $writer.Write($pngBytes)
    $writer.Flush()

    [System.IO.File]::WriteAllBytes($IcoPath, $memoryStream.ToArray())

    $writer.Dispose()
    $memoryStream.Dispose()
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$webIconsDir = Join-Path $projectRoot 'web\icons'
$windowsResourceDir = Join-Path $projectRoot 'windows\runner\resources'

Save-Png -Size 192 -Path (Join-Path $webIconsDir 'Icon-192.png')
Save-Png -Size 512 -Path (Join-Path $webIconsDir 'Icon-512.png')
Save-Png -Size 192 -Path (Join-Path $webIconsDir 'Icon-maskable-192.png')
Save-Png -Size 512 -Path (Join-Path $webIconsDir 'Icon-maskable-512.png')

$tempPngPath = Join-Path $env:TEMP 'atr_app_icon_256.png'
Save-Png -Size 256 -Path $tempPngPath
Save-IcoFromPng -PngPath $tempPngPath -IcoPath (Join-Path $windowsResourceDir 'app_icon.ico')
Remove-Item $tempPngPath -ErrorAction SilentlyContinue

Write-Output 'Brand assets atualizados com sucesso.'