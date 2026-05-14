#!/usr/bin/env python3
"""
PNG to DDS converter for FS25 mod textures.

Source PNGs live in _art/ and mirror the output structure:
  _art/textures/white.png       -> textures/white.dds  (DXT1, +mipmaps)
  _art/icon_WorkflowManager.png -> icon_WorkflowManager.dds (DXT1, no mipmaps)

FS25 rules:
  - Images with alpha      -> BC3_UNORM (DXT5)
  - Fully opaque           -> BC1_UNORM (DXT1)
  - Smaller than 4x4       -> R8G8B8A8_UNORM (DX10 uncompressed; block compression needs 4x4)
  - Root-level (mod icons) -> no mipmaps
  - textures/              -> full mip chain

Getting texconv (required):
  Download from https://github.com/microsoft/DirectXTex/releases
  Place texconv.exe in this tools/ folder or anywhere on PATH.

Usage:
    python tools/png_to_dds.py
"""

import shutil
import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow")
    sys.exit(1)

MOD_ROOT  = Path(__file__).parent.parent
ART_DIR   = MOD_ROOT / "_art"
TOOLS_DIR = Path(__file__).parent

TEXCONV_SEARCH_PATHS = [
    TOOLS_DIR / "texconv.exe",
    TOOLS_DIR / "texconv" / "texconv.exe",
    Path("C:/texconv/texconv.exe"),
]


def find_texconv() -> str | None:
    found = shutil.which("texconv")
    if found:
        return found
    for p in TEXCONV_SEARCH_PATHS:
        if p.exists():
            return str(p)
    return None


def dds_format(png_path: Path) -> str:
    """Choose the right DXGI format string for texconv."""
    img = Image.open(png_path)
    if img.width < 4 or img.height < 4:
        return "R8G8B8A8_UNORM"  # block compression needs 4x4 minimum
    has_alpha = img.mode == "RGBA" and img.getextrema()[3][0] < 255
    return "BC3_UNORM" if has_alpha else "BC1_UNORM"


def convert(png_path: Path, out_path: Path, texconv: str, mipmaps: bool) -> bool:
    fmt = dds_format(png_path)
    mip_count = "0" if mipmaps else "1"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [texconv, "-f", fmt, "-y", "-m", mip_count, "-o", str(out_path.parent), str(png_path)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"  texconv failed: {result.stderr.strip()}")
        return False
    # texconv names the output after the input; rename if needed
    texconv_out = out_path.parent / (png_path.stem + ".dds")
    if texconv_out != out_path:
        texconv_out.rename(out_path)
    return True


def main():
    if not ART_DIR.exists():
        print(f"ERROR: _art/ directory not found: {ART_DIR}")
        sys.exit(1)

    texconv = find_texconv()
    if not texconv:
        print("ERROR: texconv.exe not found.")
        print()
        print("  Download from: https://github.com/microsoft/DirectXTex/releases")
        print(f"  Then place texconv.exe in: {TOOLS_DIR}")
        sys.exit(1)

    print(f"texconv: {texconv}\n")

    pngs = sorted(ART_DIR.rglob("*.png"))
    if not pngs:
        print("No PNG files found in _art/")
        return

    failed = []
    for png in pngs:
        rel   = png.relative_to(ART_DIR)           # e.g. textures/white.png
        out   = (MOD_ROOT / rel).with_suffix(".dds") # e.g. textures/white.dds
        # Root-level art = mod icons: no mipmaps. Subdirs: full mip chain.
        mipmaps = png.parent != ART_DIR

        fmt   = dds_format(png)
        mips  = "+mips" if mipmaps else "no mips"
        print(f"  {rel} -> {out.relative_to(MOD_ROOT)} [{fmt} {mips}]", end=" ... ", flush=True)

        if convert(png, out, texconv, mipmaps):
            print("ok")
        else:
            print("FAILED")
            failed.append(str(rel))

    print()
    if failed:
        print(f"FAILED ({len(failed)}): {', '.join(failed)}")
        sys.exit(1)
    else:
        print("Done.")


if __name__ == "__main__":
    main()
