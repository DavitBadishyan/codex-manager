param([string]$OutputDirectory=$PSScriptRoot)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$frames=@()
foreach($size in @(16,24,32,48,64,128,256)){
 $bmp=New-Object Drawing.Bitmap($size,$size)
 $g=[Drawing.Graphics]::FromImage($bmp);$g.SmoothingMode='AntiAlias';$g.ScaleTransform($size/256.0,$size/256.0)
 $shape=New-Object Drawing.Drawing2D.GraphicsPath
 foreach($arc in @(@(8,8,56,56,180,90),@(192,8,56,56,270,90),@(192,192,56,56,0,90),@(8,192,56,56,90,90))){$shape.AddArc([single]$arc[0],[single]$arc[1],[single]$arc[2],[single]$arc[3],[single]$arc[4],[single]$arc[5])};$shape.CloseFigure()
 $fill=New-Object Drawing.Drawing2D.LinearGradientBrush([Drawing.Point]::new(0,0),[Drawing.Point]::new(256,256),[Drawing.ColorTranslator]::FromHtml('#293E5A'),[Drawing.ColorTranslator]::FromHtml('#111419'))
 $g.FillPath($fill,$shape)
 $edge=New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml('#506584'),3);$g.DrawPath($edge,$shape)
 $pen=New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml('#82B0EB'),17);$pen.StartCap='Round';$pen.EndCap='Round';$pen.LineJoin='Round'
 $g.DrawLines($pen,[Drawing.PointF[]]@([Drawing.PointF]::new(80,88),[Drawing.PointF]::new(44,128),[Drawing.PointF]::new(80,168)))
 $g.DrawLines($pen,[Drawing.PointF[]]@([Drawing.PointF]::new(176,88),[Drawing.PointF]::new(212,128),[Drawing.PointF]::new(176,168)))
 $pen.Color=[Drawing.ColorTranslator]::FromHtml('#EAF2FC');$g.DrawLine($pen,146,77,110,179)
 $memory=New-Object IO.MemoryStream;$bmp.Save($memory,[Drawing.Imaging.ImageFormat]::Png);$frames+=@{Size=$size;Bytes=$memory.ToArray()}
 if($size -eq 256){$bmp.Save((Join-Path $OutputDirectory 'CodexManager.png'),[Drawing.Imaging.ImageFormat]::Png)}
 $memory.Dispose();$pen.Dispose();$edge.Dispose();$fill.Dispose();$shape.Dispose();$g.Dispose();$bmp.Dispose()
}
$stream=[IO.File]::Create((Join-Path $OutputDirectory 'CodexManager.ico'));$writer=New-Object IO.BinaryWriter($stream)
try{
 $writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]$frames.Count)
 $offset=6+16*$frames.Count
 foreach($frame in $frames){$dimension=if($frame.Size -eq 256){0}else{$frame.Size};$writer.Write([byte]$dimension);$writer.Write([byte]$dimension);$writer.Write([byte]0);$writer.Write([byte]0);$writer.Write([uint16]1);$writer.Write([uint16]32);$writer.Write([uint32]$frame.Bytes.Length);$writer.Write([uint32]$offset);$offset+=$frame.Bytes.Length}
 foreach($frame in $frames){$writer.Write([byte[]]$frame.Bytes)}
}finally{$writer.Dispose();$stream.Dispose()}
