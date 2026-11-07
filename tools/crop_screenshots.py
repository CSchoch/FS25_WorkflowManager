"""Crop the in-game captures of `wmDocScreenshots` into the website's screenshot folder.

Usage (from the mod folder):
    python tools/crop_screenshots.py [capture_dir] [--out website/static/img/screenshots] [--margin 12]

capture_dir defaults to <Documents>/My Games/FarmingSimulator2025/screenshots/wm_docs/en. It holds
one full-screen image per scenario plus crops.xml, whose boxes are normalized screen coordinates
with the origin at the bottom left (as FS25 reports them).
"""
import argparse
import glob
import os
import sys
import xml.etree.ElementTree as ET

from PIL import Image

MOD_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CAPTURES = os.path.join(os.path.expanduser("~"), "Documents", "My Games", "FarmingSimulator2025",
                                "screenshots", "wm_docs", "en")
DEFAULT_OUT = os.path.join(MOD_DIR, "website", "static", "img", "screenshots")


def read_crops(path):
    """[(name, x, y, w, h)] from crops.xml"""
    crops = []
    for node in ET.parse(path).getroot().findall("crop"):
        crops.append((node.get("name"), *(float(node.get(k)) for k in ("x", "y", "w", "h"))))
    return crops


def pixel_box(rect, size, margin):
    """Normalized bottom-left box -> PIL (left, top, right, bottom), widened by margin, kept on screen"""
    x, y, w, h = rect
    width, height = size
    left = round(x * width) - margin
    right = round((x + w) * width) + margin
    top = round((1 - y - h) * height) - margin
    bottom = round((1 - y) * height) + margin
    return max(0, left), max(0, top), min(width, right), min(height, bottom)


def find_capture(directory, name):
    """The capture for a scenario, whatever extension the engine wrote"""
    matches = sorted(glob.glob(os.path.join(directory, name + ".*")))
    return matches[0] if matches else None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("captures", nargs="?", default=DEFAULT_CAPTURES)
    parser.add_argument("--out", default=DEFAULT_OUT)
    parser.add_argument("--margin", type=int, default=12, help="pixels kept around each box")
    args = parser.parse_args(argv)

    crops_file = os.path.join(args.captures, "crops.xml")
    if not os.path.isfile(crops_file):
        print("no crops.xml in %s - run wmDocScreenshots in the game first" % args.captures)
        return 1

    os.makedirs(args.out, exist_ok=True)
    missing = 0
    for name, *rect in read_crops(crops_file):
        source = find_capture(args.captures, name)
        if source is None:
            print("missing capture: %s" % name)
            missing += 1
            continue
        with Image.open(source) as image:
            cropped = image.convert("RGB").crop(pixel_box(rect, image.size, args.margin))
            target = os.path.join(args.out, name + ".png")
            cropped.save(target, optimize=True)
            print("%s -> %s %s" % (os.path.basename(source), target, cropped.size))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
