Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore

$csharp = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class IcoHelper
{
    public static Bitmap CreateSquareBitmap(Image source, int size)
    {
        Bitmap bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.Transparent);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.SmoothingMode = SmoothingMode.HighQuality;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.CompositingQuality = CompositingQuality.HighQuality;

            float srcRatio = (float)source.Width / source.Height;
            float destW = size;
            float destH = size;
            if (srcRatio > 1.0f)
            {
                destH = size / srcRatio;
            }
            else
            {
                destW = size * srcRatio;
            }
            float x = (size - destW) / 2.0f;
            float y = (size - destH) / 2.0f;

            g.DrawImage(source, new RectangleF(x, y, destW, destH));
        }
        return bmp;
    }

    public static Bitmap ResizeBitmap(Image source, int targetWidth, int targetHeight)
    {
        Bitmap bmp = new Bitmap(targetWidth, targetHeight, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.Clear(Color.Transparent);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.SmoothingMode = SmoothingMode.HighQuality;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.CompositingQuality = CompositingQuality.HighQuality;

            g.DrawImage(source, new Rectangle(0, 0, targetWidth, targetHeight));
        }
        return bmp;
    }

    public static Bitmap CreateDarkThemeLogo(Image source, int targetWidth, int targetHeight)
    {
        Bitmap bmp = ResizeBitmap(source, targetWidth, targetHeight);
        BitmapData bData = bmp.LockBits(new Rectangle(0, 0, targetWidth, targetHeight), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        byte[] row = new byte[targetWidth * 4];

        try
        {
            for (int y = 0; y < targetHeight; y++)
            {
                IntPtr rowPtr = new IntPtr(bData.Scan0.ToInt64() + (y * bData.Stride));
                Marshal.Copy(rowPtr, row, 0, targetWidth * 4);

                for (int x = 0; x < targetWidth; x++)
                {
                    byte b = row[x * 4 + 0];
                    byte g = row[x * 4 + 1];
                    byte r = row[x * 4 + 2];
                    byte a = row[x * 4 + 3];

                    // If dark charcoal text (R < 80, G < 80, B < 80, A > 30), make it white with same alpha
                    if (a > 30 && r < 80 && g < 80 && b < 80)
                    {
                        row[x * 4 + 0] = 255;
                        row[x * 4 + 1] = 255;
                        row[x * 4 + 2] = 255;
                    }
                }
                Marshal.Copy(row, 0, rowPtr, targetWidth * 4);
            }
        }
        finally
        {
            bmp.UnlockBits(bData);
        }
        return bmp;
    }

    public static byte[] CreateDibIconFrame(Bitmap bmp)
    {
        int w = bmp.Width;
        int h = bmp.Height;
        int maskRowBytes = (w + 31) / 32 * 4;
        int maskSize = maskRowBytes * h;
        int colorSize = w * h * 4;
        int totalSize = 40 + colorSize + maskSize;

        byte[] data = new byte[totalSize];
        using (BinaryWriter bw = new BinaryWriter(new MemoryStream(data)))
        {
            // BITMAPINFOHEADER
            bw.Write((uint)40); // biSize
            bw.Write((int)w);   // biWidth
            bw.Write((int)(h * 2)); // biHeight (doubled for XOR + AND mask)
            bw.Write((ushort)1);  // biPlanes
            bw.Write((ushort)32); // biBitCount
            bw.Write((uint)0);    // biCompression (BI_RGB)
            bw.Write((uint)(colorSize + maskSize)); // biSizeImage
            bw.Write((int)0);     // biXPelsPerMeter
            bw.Write((int)0);     // biYPelsPerMeter
            bw.Write((uint)0);    // biClrUsed
            bw.Write((uint)0);    // biClrImportant

            // Pixel data: bottom-up BGRA
            BitmapData bData = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            byte[] mask = new byte[maskSize];
            byte[] row = new byte[w * 4];

            try
            {
                for (int y = h - 1; y >= 0; y--)
                {
                    IntPtr rowPtr = new IntPtr(bData.Scan0.ToInt64() + (y * bData.Stride));
                    Marshal.Copy(rowPtr, row, 0, w * 4);
                    int maskRowIndex = (h - 1 - y) * maskRowBytes;

                    for (int x = 0; x < w; x++)
                    {
                        byte b = row[x * 4 + 0];
                        byte g = row[x * 4 + 1];
                        byte r = row[x * 4 + 2];
                        byte a = row[x * 4 + 3];

                        bw.Write(b);
                        bw.Write(g);
                        bw.Write(r);
                        bw.Write(a);

                        if (a < 128)
                        {
                            mask[maskRowIndex + (x / 8)] |= (byte)(0x80 >> (x % 8));
                        }
                    }
                }
            }
            finally
            {
                bmp.UnlockBits(bData);
            }

            // Write mask
            bw.Write(mask);
        }
        return data;
    }

    public static void SaveIco(string outputPath, Image source, int[] sizes)
    {
        List<byte[]> frames = new List<byte[]>();
        List<int> frameSizes = new List<int>();

        foreach (int size in sizes)
        {
            using (Bitmap square = CreateSquareBitmap(source, size))
            {
                frames.Add(CreateDibIconFrame(square));
                frameSizes.Add(size);
            }
        }

        using (FileStream fs = new FileStream(outputPath, FileMode.Create, FileAccess.Write))
        using (BinaryWriter bw = new BinaryWriter(fs))
        {
            // ICONDIR
            bw.Write((ushort)0); // reserved
            bw.Write((ushort)1); // type = 1 (icon)
            bw.Write((ushort)frames.Count); // count

            int offset = 6 + (frames.Count * 16);

            for (int i = 0; i < frames.Count; i++)
            {
                int sz = frameSizes[i];
                bw.Write((byte)(sz >= 256 ? 0 : sz)); // bWidth
                bw.Write((byte)(sz >= 256 ? 0 : sz)); // bHeight
                bw.Write((byte)0); // bColorCount
                bw.Write((byte)0); // bReserved
                bw.Write((ushort)1); // wPlanes
                bw.Write((ushort)32); // wBitCount
                bw.Write((uint)frames[i].Length); // dwBytesInRes
                bw.Write((uint)offset); // dwImageOffset
                offset += frames[i].Length;
            }

            for (int i = 0; i < frames.Count; i++)
            {
                bw.Write(frames[i]);
            }
        }
    }
}
"@

Add-Type -TypeDefinition $csharp -ReferencedAssemblies System.Drawing

function Generate-ProjectAssets([string]$repoRoot, [string]$iconSrcPath, [string]$logoSrcPath) {
    Write-Host "Generating assets for $repoRoot..." -ForegroundColor Cyan

    $iconImg = [System.Drawing.Image]::FromFile($iconSrcPath)
    $logoImg = [System.Drawing.Image]::FromFile($logoSrcPath)

    try {
        # 1. Multi-resolution icon.ico (16, 24, 32, 48, 64, 128, 256)
        $iconIcoPath = Join-Path $repoRoot "res\icon.ico"
        [IcoHelper]::SaveIco($iconIcoPath, $iconImg, @(16, 24, 32, 48, 64, 128, 256))
        Write-Host "Created $iconIcoPath"

        # 2. app_icon.ico in flutter runner
        $appIconIcoPath = Join-Path $repoRoot "flutter\windows\runner\resources\app_icon.ico"
        $appIconDir = Split-Path $appIconIcoPath
        if (-not (Test-Path $appIconDir)) { New-Item -ItemType Directory -Path $appIconDir -Force | Out-Null }
        Copy-Item -Path $iconIcoPath -Destination $appIconIcoPath -Force
        Write-Host "Created $appIconIcoPath"

        # 3. tray-icon.ico (16, 32)
        $trayIcoPath = Join-Path $repoRoot "res\tray-icon.ico"
        [IcoHelper]::SaveIco($trayIcoPath, $iconImg, @(16, 32))
        Write-Host "Created $trayIcoPath"

        # 4. flutter/assets/icon.ico
        $flutterAssetsDir = Join-Path $repoRoot "flutter\assets"
        if (-not (Test-Path $flutterAssetsDir)) { New-Item -ItemType Directory -Path $flutterAssetsDir -Force | Out-Null }
        $flutterIconIco = Join-Path $flutterAssetsDir "icon.ico"
        Copy-Item -Path $iconIcoPath -Destination $flutterIconIco -Force
        Write-Host "Created $flutterIconIco"

        # 5. Square PNG icons in res/
        $pngSizes = @{
            "icon.png" = 1024
            "mac-icon.png" = 1024
            "128x128@2x.png" = 256
            "128x128.png" = 128
            "64x64.png" = 64
            "32x32.png" = 32
        }

        foreach ($entry in $pngSizes.GetEnumerator()) {
            $destPath = Join-Path $repoRoot "res\$($entry.Key)"
            $sz = $entry.Value
            $squareBmp = [IcoHelper]::CreateSquareBitmap($iconImg, $sz)
            $squareBmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $squareBmp.Dispose()
            Write-Host "Created $destPath ($sz x $sz)"
        }

        # 6. flutter/assets/icon.png (512x512)
        $flutterIconPng = Join-Path $flutterAssetsDir "icon.png"
        $flutterSquare = [IcoHelper]::CreateSquareBitmap($iconImg, 512)
        $flutterSquare.Save($flutterIconPng, [System.Drawing.Imaging.ImageFormat]::Png)
        $flutterSquare.Dispose()
        Write-Host "Created $flutterIconPng"

        # 7. flutter/assets/icon.svg (SVG wrapping base64 of Icon.png)
        $iconBase64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($iconSrcPath))
        $iconSvgContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<svg id="Layer_1" data-name="Layer 1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 $($iconImg.Width) $($iconImg.Height)">
  <image width="$($iconImg.Width)" height="$($iconImg.Height)" xlink:href="data:image/png;base64,$iconBase64"/>
</svg>
"@
        $flutterIconSvg = Join-Path $flutterAssetsDir "icon.svg"
        [System.IO.File]::WriteAllText($flutterIconSvg, $iconSvgContent)
        Write-Host "Created $flutterIconSvg"

        # 8. res/scalable.svg (Linux desktop scalable icon)
        $resScalableSvg = Join-Path $repoRoot "res\scalable.svg"
        [System.IO.File]::WriteAllText($resScalableSvg, $iconSvgContent)
        Write-Host "Created $resScalableSvg"

        # 9. flutter/assets/logo.png (Full logo for light/default)
        # Scaled to 1200 width, aspect ratio 3628x844 -> height = 279
        $targetLogoW = 1200
        $targetLogoH = [int][Math]::Round(1200.0 * $logoImg.Height / $logoImg.Width)
        $logoPng = Join-Path $flutterAssetsDir "logo.png"
        $logoBmp = [IcoHelper]::ResizeBitmap($logoImg, $targetLogoW, $targetLogoH)
        $logoBmp.Save($logoPng, [System.Drawing.Imaging.ImageFormat]::Png)
        $logoBmp.Dispose()
        Write-Host "Created $logoPng ($targetLogoW x $targetLogoH)"

        # 10. flutter/assets/logo_light.png
        $logoLightPng = Join-Path $flutterAssetsDir "logo_light.png"
        Copy-Item -Path $logoPng -Destination $logoLightPng -Force
        Write-Host "Created $logoLightPng"

        # 11. flutter/assets/logo_dark.png
        $logoDarkPng = Join-Path $flutterAssetsDir "logo_dark.png"
        $logoDarkBmp = [IcoHelper]::CreateDarkThemeLogo($logoImg, $targetLogoW, $targetLogoH)
        $logoDarkBmp.Save($logoDarkPng, [System.Drawing.Imaging.ImageFormat]::Png)
        $logoDarkBmp.Dispose()
        Write-Host "Created $logoDarkPng"

    }
    finally {
        $iconImg.Dispose()
        $logoImg.Dispose()
    }

    Write-Host "Asset generation for $repoRoot completed successfully!`n" -ForegroundColor Green
}

$iconSrc = "D:\Github\XsightDesk\Logos\Icon.png"
$logoSrc = "D:\Github\XsightDesk\Logos\Logo_Full.png"

# Execute for XsightDesk (SummaTech-Master)
Generate-ProjectAssets "D:\Github\XsightDesk" $iconSrc $logoSrc

# Execute for XsightDeskClient (SummaTech-Client) if it exists
if (Test-Path "D:\Github\XsightDeskClient") {
    Generate-ProjectAssets "D:\Github\XsightDeskClient" $iconSrc $logoSrc
}
