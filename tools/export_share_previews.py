"""Crop inner share-tutorial mockups from zoomed Figma screenshots."""

from __future__ import annotations

import os
import shutil
from PIL import Image

ROOT = r"D:\Projects\Zenorix\Flutter-Hamme-App"
SHOTS = r"c:\Users\govin\AppData\Local\Temp\cursor\screenshots"
OUT = os.path.join(ROOT, "assets", "images", "share")

SOURCES = {
    "snap_step_1.png": os.path.join(SHOTS, "figma-snap1-200.png"),
    "snap_step_2.png": os.path.join(SHOTS, "figma-snap2-200.png"),
    "snap_step_3.png": os.path.join(SHOTS, "figma-snap3-200.png"),
    "snap_step_4.png": os.path.join(SHOTS, "page-2026-08-25T15-35-38-616Z.png"),
}

IG_COPY = [
    ("share_link_button.png", "ig_step_1.png"),
    ("share_link_stickers.png", "ig_step_2.png"),
    ("share_paste_link.png", "ig_step_3.png"),
    ("share_frame_link.png", "ig_step_4.png"),
]


def is_white(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    return r > 235 and g > 235 and b > 235


def largest_white_x(im: Image.Image) -> tuple[int, int]:
    w, h = im.size
    px = im.load()
    col = []
    for x in range(w):
        c = 0
        samples = 0
        for y in range(0, h, 2):
            samples += 1
            if is_white(px[x, y]):
                c += 1
        col.append(c / samples)
    on = [v > 0.12 for v in col]
    ranges: list[tuple[int, int]] = []
    start = None
    for i, v in enumerate(on):
        if v and start is None:
            start = i
        if (not v) and start is not None:
            if i - start > 200:
                ranges.append((start, i))
            start = None
    if start is not None and w - start > 200:
        ranges.append((start, w))
    return max(ranges, key=lambda t: t[1] - t[0])


def figma_chrome_top(im: Image.Image) -> int:
    """Bottom of the Figma signup banner that sits under the canvas."""
    w, h = im.size
    px = im.load()
    for y in range(h - 1, h // 2, -1):
        blue = 0
        n = 0
        for x in range(0, w, 8):
            n += 1
            r, g, b = px[x, y]
            if b > 200 and r < 80 and g < 190:
                blue += 1
        if blue / n > 0.12:
            return y
    return h


def crop_preview(path: str) -> Image.Image:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    x0, x1 = largest_white_x(im)
    limit = figma_chrome_top(im) - 2
    nonwhite = []
    for y in range(h):
        nw = 0
        n = 0
        for x in range(x0, x1, 3):
            n += 1
            if not is_white(px[x, y]):
                nw += 1
        nonwhite.append(nw / n if n else 0)

    # Preview sits in the lower half of the white card (below title / step dots).
    start = None
    end = None
    for y in range(int(h * 0.42), limit):
        if nonwhite[y] > 0.55:
            if start is None:
                start = y
            end = y
        elif start is not None and y - start > 80 and nonwhite[y] < 0.2:
            break

    if start is None or end is None or end - start < 80:
        raise RuntimeError(f"Could not find preview in {path}")

    # Inset past the white card padding.
    pad_x = int((x1 - x0) * 0.09)
    pad_y = 8
    box = (x0 + pad_x, start + pad_y, x1 - pad_x, min(end, limit) - 2)
    crop = im.crop(box)
    # Drop any leftover Figma chrome along the bottom edge.
    trim = int(crop.height * 0.06)
    if trim > 0:
        crop = crop.crop((0, 0, crop.width, crop.height - trim))
    return crop


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    images_dir = os.path.join(ROOT, "assets", "images")
    for src_name, dest_name in IG_COPY:
        shutil.copy2(os.path.join(images_dir, src_name), os.path.join(OUT, dest_name))
        print("copied", dest_name)

    for dest, src in SOURCES.items():
        crop = crop_preview(src)
        # Target ~3x of the 345x200 on-screen preview.
        target_h = 600
        scale = target_h / crop.height
        crop = crop.resize(
            (max(1, int(crop.width * scale)), target_h),
            Image.Resampling.LANCZOS,
        )
        out_path = os.path.join(OUT, dest)
        crop.save(out_path, "PNG")
        print("wrote", dest, crop.size)


if __name__ == "__main__":
    main()
