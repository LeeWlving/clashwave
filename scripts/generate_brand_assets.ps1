param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class ClashWaveNativeIcon {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr handle);
}
'@

function New-RoundedRectanglePath {
    param(
        [System.Drawing.RectangleF]$Rect,
        [float]$Radius
    )
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $Radius * 2
    $path.AddArc($Rect.X, $Rect.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-ClashWaveMark {
    param(
        [System.Drawing.Graphics]$Graphics,
        [float]$X,
        [float]$Y,
        [float]$Size,
        [System.Drawing.Color]$Color
    )

    $pen = [System.Drawing.Pen]::new($Color, $Size * 0.065)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $cat = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $cat.StartFigure()
    $cat.AddLine($X + $Size * 0.24, $Y + $Size * 0.54, $X + $Size * 0.28, $Y + $Size * 0.27)
    $cat.AddLine($X + $Size * 0.28, $Y + $Size * 0.27, $X + $Size * 0.43, $Y + $Size * 0.39)
    $cat.AddBezier(
        $X + $Size * 0.43, $Y + $Size * 0.39,
        $X + $Size * 0.47, $Y + $Size * 0.37,
        $X + $Size * 0.53, $Y + $Size * 0.37,
        $X + $Size * 0.57, $Y + $Size * 0.39
    )
    $cat.AddLine($X + $Size * 0.57, $Y + $Size * 0.39, $X + $Size * 0.72, $Y + $Size * 0.27)
    $cat.AddLine($X + $Size * 0.72, $Y + $Size * 0.27, $X + $Size * 0.76, $Y + $Size * 0.54)
    $Graphics.DrawPath($pen, $cat)

    $wave = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $wave.StartFigure()
    $wave.AddBezier(
        $X + $Size * 0.18, $Y + $Size * 0.62,
        $X + $Size * 0.31, $Y + $Size * 0.50,
        $X + $Size * 0.39, $Y + $Size * 0.76,
        $X + $Size * 0.52, $Y + $Size * 0.62
    )
    $wave.AddBezier(
        $X + $Size * 0.52, $Y + $Size * 0.62,
        $X + $Size * 0.64, $Y + $Size * 0.49,
        $X + $Size * 0.72, $Y + $Size * 0.72,
        $X + $Size * 0.82, $Y + $Size * 0.60
    )
    $Graphics.DrawPath($pen, $wave)

    $brush = [System.Drawing.SolidBrush]::new($Color)
    $eyeSize = $Size * 0.054
    $Graphics.FillEllipse($brush, $X + $Size * 0.373, $Y + $Size * 0.483, $eyeSize, $eyeSize)
    $Graphics.FillEllipse($brush, $X + $Size * 0.573, $Y + $Size * 0.483, $eyeSize, $eyeSize)

    $brush.Dispose()
    $wave.Dispose()
    $cat.Dispose()
    $pen.Dispose()
}

function New-ClashWaveBitmap {
    param(
        [int]$Size,
        [System.Drawing.Color]$Background,
        [System.Drawing.Color]$Foreground,
        [bool]$TransparentCorners = $false
    )
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $brush = [System.Drawing.SolidBrush]::new($Background)
    if ($TransparentCorners) {
        $inset = [math]::Max(1, $Size * 0.035)
        $rect = [System.Drawing.RectangleF]::new($inset, $inset, $Size - 2 * $inset, $Size - 2 * $inset)
        $shape = New-RoundedRectanglePath -Rect $rect -Radius ($Size * 0.22)
        $graphics.FillPath($brush, $shape)
        $shape.Dispose()
    } else {
        $graphics.FillRectangle($brush, 0, 0, $Size, $Size)
    }
    Draw-ClashWaveMark -Graphics $graphics -X 0 -Y 0 -Size $Size -Color $Foreground
    $brush.Dispose()
    $graphics.Dispose()
    return $bitmap
}

function Save-Png {
    param(
        [string]$RelativePath,
        [int]$Size,
        [System.Drawing.Color]$Background,
        [System.Drawing.Color]$Foreground,
        [bool]$TransparentCorners = $false
    )
    $path = Join-Path $ProjectRoot $RelativePath
    $bitmap = New-ClashWaveBitmap -Size $Size -Background $Background -Foreground $Foreground -TransparentCorners $TransparentCorners
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
}

function Save-Ico {
    param(
        [string]$RelativePath,
        [System.Drawing.Color]$Background,
        [System.Drawing.Color]$Foreground
    )
    $path = Join-Path $ProjectRoot $RelativePath
    $bitmap = New-ClashWaveBitmap -Size 256 -Background $Background -Foreground $Foreground -TransparentCorners $true
    $handle = $bitmap.GetHicon()
    try {
        $icon = [System.Drawing.Icon]::FromHandle($handle)
        $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Create)
        try { $icon.Save($stream) } finally { $stream.Dispose(); $icon.Dispose() }
    } finally {
        [ClashWaveNativeIcon]::DestroyIcon($handle) | Out-Null
        $bitmap.Dispose()
    }
}

function Save-DrawerImage {
    $path = Join-Path $ProjectRoot 'assets\darwer_img.jpg'
    $bitmap = [System.Drawing.Bitmap]::new(1200, 800, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#F4F7F7'))
    Draw-ClashWaveMark -Graphics $graphics -X 360 -Y 160 -Size 480 -Color ([System.Drawing.ColorTranslator]::FromHtml('#176B78'))
    $graphics.Dispose()
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $bitmap.Dispose()
}

$tide = [System.Drawing.ColorTranslator]::FromHtml('#176B78')
$inactive = [System.Drawing.ColorTranslator]::FromHtml('#68777C')
$white = [System.Drawing.Color]::White

Save-Png 'assets\icon.png' 1024 $tide $white $true
Save-Png 'assets\icon_inactive.png' 1024 $inactive $white $true
Save-Png 'assets\logo_64.png' 64 $tide $white $true
Save-Png 'assets\logo_64_inactive.png' 64 $inactive $white $true
Save-Ico 'assets\icon.ico' $tide $white
Save-Ico 'assets\icon_inactive.ico' $inactive $white
Save-DrawerImage

$androidSizes = @{
    'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
    'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
    'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
    'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
    'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
}
foreach ($item in $androidSizes.GetEnumerator()) {
    Save-Png $item.Key $item.Value $tide $white $false
}

$iosSizes = @{
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png' = 20
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png' = 40
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png' = 60
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png' = 29
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png' = 58
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png' = 87
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png' = 40
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png' = 80
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png' = 120
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png' = 120
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png' = 180
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png' = 76
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png' = 152
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png' = 167
    'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png' = 1024
}
foreach ($item in $iosSizes.GetEnumerator()) {
    Save-Png $item.Key $item.Value $tide $white $false
}

foreach ($size in 16, 32, 64, 128, 256, 512, 1024) {
    Save-Png "macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_$size.png" $size $tide $white $false
}

Save-Ico 'windows\runner\resources\app_icon.ico' $tide $white
Write-Host 'ClashWave brand assets generated.'
