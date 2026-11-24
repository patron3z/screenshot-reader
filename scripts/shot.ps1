<#
.SYNOPSIS
  Turn a screenshot into text (Windows built-in OCR) or into a small image, on this PC only.
.EXAMPLE
  shot.ps1 -Path C:\tmp\a.png                         # OCR: prints the text found
  shot.ps1 -Path C:\tmp\a.png -Crop 0,0,800,300       # OCR only that region (x,y,width,height)
  shot.ps1 -Path C:\tmp\a.png -Scale 2                # enlarge before OCR (small text)
  shot.ps1 -Path C:\tmp\a.png -Mode shrink -MaxWidth 800 [-Crop ...]   # writes a small PNG, prints its path
#>
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [ValidateSet('text','shrink')][string]$Mode = 'text',
  [string]$Crop,
  [double]$Scale = 1,
  [int]$MaxWidth = 800,
  [string]$Out
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
$Path = (Resolve-Path -LiteralPath $Path).Path
Add-Type -AssemblyName System.Drawing

# 1) optional crop / scale into a temp or output PNG
$work = $Path; $tmp = $null
if ($Crop -or $Scale -ne 1 -or $Mode -eq 'shrink') {
  $src = [System.Drawing.Image]::FromFile($Path)
  try {
    $rx,$ry,$rw,$rh = 0,0,$src.Width,$src.Height
    if ($Crop) {
      $c = @($Crop -split '[,\s]+' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
      if ($c.Count -ne 4) { throw "-Crop needs 4 numbers: x,y,width,height" }
      $rx,$ry,$rw,$rh = $c
      if ($rx -lt 0 -or $ry -lt 0 -or $rw -le 0 -or $rh -le 0 -or ($rx+$rw) -gt $src.Width -or ($ry+$rh) -gt $src.Height) {
        throw "Crop outside the image (image is $($src.Width)x$($src.Height))"
      }
    }
    $f = $Scale
    if ($Mode -eq 'shrink' -and $rw -gt $MaxWidth) { $f = $MaxWidth / $rw }
    $nw = [Math]::Max(1,[int]($rw*$f)); $nh = [Math]::Max(1,[int]($rh*$f))
    $bmp = New-Object System.Drawing.Bitmap $nw,$nh
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle 0,0,$nw,$nh), $rx,$ry,$rw,$rh, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    if ($Out) { $tmp = $Out } else { $tmp = Join-Path $env:TEMP ("shot-" + [guid]::NewGuid().ToString('N').Substring(0,8) + ".png") }
    $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    $work = $tmp
  } finally { $src.Dispose() }
}
if ($Mode -eq 'shrink') { Write-Output $work; exit 0 }

# 2) OCR with the Windows engine
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null=[Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
$null=[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
$null=[Windows.Graphics.Imaging.BitmapDecoder,Windows.Foundation,ContentType=WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, $type) { $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op)); $t.Wait(-1) | Out-Null; $t.Result }
try {
  $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($work)) ([Windows.Storage.StorageFile])
  $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $dec = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $sb = Await ($dec.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
  if ($sb.PixelWidth -gt [Windows.Media.Ocr.OcrEngine]::MaxImageDimension -or $sb.PixelHeight -gt [Windows.Media.Ocr.OcrEngine]::MaxImageDimension) {
    throw "Image too large for the OCR engine (max $([Windows.Media.Ocr.OcrEngine]::MaxImageDimension) px per side): use -Crop or -Scale 0.5"
  }
  $eng = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
  if (-not $eng) { throw "No OCR language installed. Add one in Windows Settings > Time & language > Language." }
  $res = Await ($eng.RecognizeAsync($sb)) ([Windows.Media.Ocr.OcrResult])
  foreach ($line in $res.Lines) { Write-Output $line.Text }
  if (-not $res.Lines.Count) { Write-Output "(no text found: the picture may need to be looked at, not read)" }
} finally {
  if ($tmp -and -not $Out) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
