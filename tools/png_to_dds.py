#!/usr/bin/env python3
"""
PNG to DDS converter for FS25 mod textures.

Converts all PNG files in the textures/ folder to DDS format.
- If texconv.exe is on PATH, uses it to produce DXT5-compressed DDS with mipmaps (RGBA)
  or DXT1-compressed DDS (RGB, no alpha).
- Otherwise falls back to Pillow for uncompressed DDS (works fine for small icons).

Usage:
    python tools/png_to_dds.py
    python tools/png_to_dds.py --clean   # delete converted PNGs after conversion
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow")
    sys.exit(1)

TEXTURES_DIR = Path(__file__).parent.parent / "textures"


def has_alpha(img: Image.Image) -> bool:
    if img.mode == "RGBA":
        return img.getextrema()[3][0] < 255  # any non-fully-opaque pixel
    return img.mode in ("LA", "PA")


def convert_with_texconv(png_path: Path) -> bool:
    """Try DXT5/DXT1 via texconv.exe. Returns True on success."""
    texconv = shutil.which("texconv")
    if texconv is None:
        return False

    img = Image.open(png_path)
    fmt = "BC3_UNORM" if has_alpha(img) else "BC1_UNORM"  # DXT5 / DXT1

    result = subprocess.run(
        [
            texconv,
            "-f", fmt,
            "-y",           # overwrite
            "-m", "0",      # generate all mip levels
            "-o", str(png_path.parent),
            str(png_path),
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"  texconv failed: {result.stderr.strip()}")
        return False
    return True


def convert_with_pillow(png_path: Path) -> None:
    """Fallback: uncompressed RGBA DDS via Pillow."""
    img = Image.open(png_path).convert("RGBA")
    out = png_path.with_suffix(".dds")
    img.save(out, format="DDS")


def main():
    parser = argparse.ArgumentParser(description="Convert PNG textures to DDS")
    parser.add_argument("--clean", action="store_true", help="Delete source PNGs after conversion")
    args = parser.parse_args()

    if not TEXTURES_DIR.exists():
        print(f"ERROR: textures directory not found: {TEXTURES_DIR}")
        sys.exit(1)

    mod_root = TEXTURES_DIR.parent
    pngs = sorted(TEXTURES_DIR.glob("*.png")) + sorted(mod_root.glob("modIcon.png"))
    if not pngs:
        print("No PNG files found in textures/")
        return

    use_texconv = shutil.which("texconv") is not None
    method = "texconv (DXT5/DXT1 + mipmaps)" if use_texconv else "Pillow (uncompressed RGBA)"
    print(f"Converting {len(pngs)} file(s) using {method}\n")

    for png in pngs:
        dds = png.with_suffix(".dds")
        print(f"  {png.name} -> {dds.name}", end=" ... ")

        ok = False
        if use_texconv:
            ok = convert_with_texconv(png)
        if not ok:
            convert_with_pillow(png)
            ok = True

        print("ok")

        if ok and args.clean:
            png.unlink()
            print(f"    (deleted {png.name})")

    print("\nDone.")


if __name__ == "__main__":
    main()
