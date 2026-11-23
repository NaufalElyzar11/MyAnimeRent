# Original geometric garment illustrations; no third-party product photographs.
# Run from the Flutter root. Does not contact any service.
Add-Type -AssemblyName System.Drawing
$assetDirectory = Join-Path (Get-Location) 'assets\event\images'
New-Item -ItemType Directory -Force -Path $assetDirectory | Out-Null
$illustrations = @(
  @('2b-black', '2B', '#282333', '#D6C7F2'),
  @('2b-detail', '2B / DETAIL', '#51415E', '#FFE0EF'),
  @('2b-white', '2B / PUTIH', '#F5F0E4', '#D6C7F2'),
  @('tanjiro', 'TANJIRO', '#277568', '#CCEEE5'),
  @('anya', 'ANYA', '#272637', '#FFD3E7'),
  @('hutao', 'HU TAO', '#573344', '#ECD9F6'),
  @('frieren', 'FRIEREN', '#F5F0E4', '#DFD7F4'),
  @('naruto', 'NARUTO', '#E77832', '#FFE9BD'),
  @('yor', 'YOR', '#302836', '#F0D1E4')
)
foreach ($illustration in $illustrations) {
  $bitmap = New-Object System.Drawing.Bitmap 640,640
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $background = [System.Drawing.ColorTranslator]::FromHtml($illustration[3])
  $graphics.Clear($background)
  $pink = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(35,255,77,166))
  $graphics.FillEllipse($pink, -90, -90, 360, 360)
  $graphics.FillEllipse($pink, 400, 430, 360, 360)
  $ink = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#302339'))
  $outline = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml('#7B3FE4')),7
  $graphics.DrawArc($outline, 293, 103, 55, 60, 170, 240)
  $graphics.DrawLine($outline,320,158,320,180)
  $hanger = [System.Drawing.Point[]]@([System.Drawing.Point]::new(320,180),[System.Drawing.Point]::new(190,238),[System.Drawing.Point]::new(450,238))
  $graphics.DrawPolygon($outline,$hanger)
  $garment = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(245,215),[System.Drawing.Point]::new(180,242),
    [System.Drawing.Point]::new(131,328),[System.Drawing.Point]::new(196,364),
    [System.Drawing.Point]::new(233,313),[System.Drawing.Point]::new(211,484),
    [System.Drawing.Point]::new(429,484),[System.Drawing.Point]::new(407,313),
    [System.Drawing.Point]::new(444,364),[System.Drawing.Point]::new(509,328),
    [System.Drawing.Point]::new(460,242),[System.Drawing.Point]::new(395,215),
    [System.Drawing.Point]::new(360,249),[System.Drawing.Point]::new(280,249)
  )
  $cloth = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($illustration[2]))
  $graphics.FillPolygon($cloth,$garment)
  $graphics.DrawPolygon($outline,$garment)
  $accent = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml('#FFC629')),7
  $graphics.DrawLine($accent,253,439,387,439)
  $titleFont = New-Object System.Drawing.Font 'Arial',25,([System.Drawing.FontStyle]::Bold)
  $smallFont = New-Object System.Drawing.Font 'Arial',15,([System.Drawing.FontStyle]::Regular)
  $center = New-Object System.Drawing.StringFormat
  $center.Alignment = [System.Drawing.StringAlignment]::Center
  $graphics.DrawString('ILUSTRASI / BUKAN FOTO BARANG',$smallFont,$ink,[System.Drawing.RectangleF]::new(0,32,640,45),$center)
  $graphics.DrawString($illustration[1],$titleFont,$ink,[System.Drawing.RectangleF]::new(0,540,640,50),$center)
  $bitmap.Save((Join-Path $assetDirectory ($illustration[0]+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose(); $bitmap.Dispose(); $pink.Dispose(); $ink.Dispose()
  $outline.Dispose(); $cloth.Dispose(); $accent.Dispose(); $titleFont.Dispose(); $smallFont.Dispose(); $center.Dispose()
}
