param(
    [Parameter(Mandatory = $true)][string]$Source,
    [string]$Destination = (Join-Path $PSScriptRoot '..\assets\ui\tap_glove_down.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$drawingReferences = @('System.Drawing.Common', 'System.Drawing.Primitives', 'System.Runtime', 'System.Console', 'System.Collections', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core')
if ($PSVersionTable.PSEdition -eq 'Desktop') { $drawingReferences = @('System.Drawing') }
Add-Type -ReferencedAssemblies $drawingReferences -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public static class TapGloveCutout {
    public static void Prepare(string source, string destination) {
        using (var input = new Bitmap(source))
        using (var output = new Bitmap(input.Width, input.Height, PixelFormat.Format32bppArgb)) {
            int width = input.Width, height = input.Height;
            var outside = new bool[width * height];
            var queue = new Queue<int>();
            Action<int, int> visit = (x, y) => {
                if (x < 0 || y < 0 || x >= width || y >= height) return;
                int index = y * width + x;
                if (outside[index] || input.GetPixel(x, y).R <= 90) return;
                outside[index] = true;
                queue.Enqueue(index);
            };
            // Only erase light pixels connected to the image border. The black
            // glove outline seals off the white palm, fingers and cuff.
            for (int x = 0; x < width; x++) { visit(x, 0); visit(x, height - 1); }
            for (int y = 0; y < height; y++) { visit(0, y); visit(width - 1, y); }
            while (queue.Count > 0) {
                int index = queue.Dequeue(), x = index % width, y = index / width;
                visit(x - 1, y); visit(x + 1, y); visit(x, y - 1); visit(x, y + 1);
            }
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    if (outside[y * width + x]) {
                        output.SetPixel(x, y, Color.Transparent);
                        continue;
                    }
                    Color pixel = input.GetPixel(x, y);
                    bool edge = (x > 0 && outside[y * width + x - 1]) ||
                        (x + 1 < width && outside[y * width + x + 1]) ||
                        (y > 0 && outside[(y - 1) * width + x]) ||
                        (y + 1 < height && outside[(y + 1) * width + x]);
                    output.SetPixel(x, y, edge ? Color.FromArgb(255 - pixel.R, 0, 0, 0) : pixel);
                }
            }
            output.RotateFlip(RotateFlipType.Rotate180FlipNone);
            output.Save(destination, ImageFormat.Png);
            Console.WriteLine("Saved transparent downward glove: " + destination);
        }
    }
}
'@

[TapGloveCutout]::Prepare((Resolve-Path -LiteralPath $Source).Path, [IO.Path]::GetFullPath($Destination))
