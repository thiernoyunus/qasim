#!/usr/bin/env python3
"""
Dehalo character sprites: remove cream-paper fringe from AI-generated PNGs.

Rules (per task brief):
  1. Targets the custom qasim-*, hana-*, and nur-* sprites only.
  2. Dehalo: for any light cream/white/paper pixel at the silhouette edge, including opaque
     matte pixels and semi-transparent fringe, set alpha to 0.
     Then contract 1px of semi-transparent fringe. Snap alpha < 24 to 0, alpha > 230 to 255.
  3. Never key dark pixels (Nur's niqab). Only key light/cream/white fringe.
  4. Trim to alpha bbox + 12px pad, then scale height to 520 preserving aspect.
  5. Write back to Art/*.png AND matching Assets.xcassets/<name>.imageset/<name>.png.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path("/Users/thiernodiallo/Coding/productivity app/Wick")
ART = REPO / "Wick" / "Resources" / "Art"
ASSETS = REPO / "Wick" / "Resources" / "Assets.xcassets"

TARGET_PREFIXES = ("qasim-", "hana-", "nur-")
DARK_MATTE_PREFIXES = ("qasim-", "hana-", "nur-")

CREAM_LUM_MIN = 170      # luminance threshold for "light enough to be halo"
CREAM_SAT_MAX = 60       # max (max-min) channel difference
HARD_DARK_LUM_MAX = 70   # any fringe pixel below this luminance is NEVER keyed

TARGET_HEIGHT = 520
PAD = 12
ALPHA_FLOOR = 24         # snap to 0 below this
ALPHA_CEIL = 230         # snap to 255 above this


def cream_mask(rgb: np.ndarray) -> np.ndarray:
    """True where rgb is cream/white/paper (high luminance, low saturation)."""
    lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    sat = rgb.max(axis=-1).astype(np.int32) - rgb.min(axis=-1).astype(np.int32)
    return (lum >= CREAM_LUM_MIN) & (sat <= CREAM_SAT_MAX)


def dehalo(rgba: np.ndarray) -> np.ndarray:
    """Remove cream-paper fringe without touching dark pixels."""
    rgb = rgba[..., :3].astype(np.int32)
    a = rgba[..., 3].copy()

    semi = (a > 1) & (a < 250)
    is_cream = cream_mask(rgb)
    safe_cream = semi & is_cream & (  # never key the hard-dark interior
        (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]) >= HARD_DARK_LUM_MAX
    )

    # 1) Knock out cream fringe pixels entirely.
    a[safe_cream] = 0

    # 2) Remove opaque matte layers too. Repeat until the next visible edge is
    # not pale, because hard background removal can leave several full-alpha
    # paper-colored pixels around the silhouette.
    while True:
        zero = a == 0
        padded = np.pad(zero, 1, mode="constant", constant_values=False)
        neighbor_any_zero = (
            padded[:-2, 1:-1] | padded[2:, 1:-1] | padded[1:-1, :-2] | padded[1:-1, 2:]
        )
        light_edge = (a > 0) & cream_mask(rgb) & neighbor_any_zero
        if not light_edge.any():
            break
        a[light_edge] = 0

    # 3) Contract 1px of remaining semi-transparent fringe:
    #    any pixel that is (a) semi-transparent AND (b) surrounded by alpha==0
    #    becomes alpha==0.
    zero = a == 0
    padded = np.pad(zero, 1, mode="constant", constant_values=False)
    # If any neighbor is fully transparent, this pixel is on the new edge.
    neighbor_any_zero = (
        padded[:-2, 1:-1] | padded[2:, 1:-1] | padded[1:-1, :-2] | padded[1:-1, 2:]
    )
    contract_mask = (a > 0) & (a < 255) & neighbor_any_zero
    a[contract_mask] = 0

    # The contraction can expose one last paper-colored pixel.
    zero = a == 0
    padded = np.pad(zero, 1, mode="constant", constant_values=False)
    neighbor_any_zero = (
        padded[:-2, 1:-1] | padded[2:, 1:-1] | padded[1:-1, :-2] | padded[1:-1, 2:]
    )
    a[(a > 0) & cream_mask(rgb) & neighbor_any_zero] = 0

    # 4) Snap alpha bands.
    a[a < ALPHA_FLOOR] = 0
    a[a > ALPHA_CEIL] = 255

    out = rgba.copy()
    out[..., 3] = a
    # Avoid renderer interpolation sampling the old paper-colored matte from
    # fully transparent pixels.
    out[a == 0, :3] = 0
    return out


def remove_outer_matte_ring(rgba: np.ndarray) -> np.ndarray:
    """Remove one mixed-color raster ring while preserving the inner outline."""
    a = rgba[..., 3].copy()
    zero = a == 0
    padded = np.pad(zero, 1, mode="constant", constant_values=False)
    neighbor_any_zero = (
        padded[:-2, 1:-1] | padded[2:, 1:-1] | padded[1:-1, :-2] | padded[1:-1, 2:]
    )
    a[(a > 0) & neighbor_any_zero] = 0

    out = rgba.copy()
    out[..., 3] = a
    out[a == 0, :3] = 0
    return out


def trim_and_resize(rgba_img: Image.Image) -> Image.Image:
    """Trim to alpha bbox + PAD, then scale height to TARGET_HEIGHT preserving aspect."""
    if rgba_img.height == TARGET_HEIGHT:
        return rgba_img

    arr = np.array(rgba_img)
    alpha = arr[..., 3]
    ys, xs = np.where(alpha > 0)
    if ys.size == 0:
        return rgba_img  # nothing to trim
    y0, y1 = ys.min(), ys.max() + 1
    x0, x1 = xs.min(), xs.max() + 1
    h, w = arr.shape[:2]
    y0 = max(0, y0 - PAD); x0 = max(0, x0 - PAD)
    y1 = min(h, y1 + PAD); x1 = min(w, x1 + PAD)
    cropped = arr[y0:y1, x0:x1]
    img = Image.fromarray(cropped, mode="RGBA")

    if img.height != TARGET_HEIGHT:
        new_w = max(1, round(img.width * (TARGET_HEIGHT / img.height)))
        img = img.resize((new_w, TARGET_HEIGHT), Image.LANCZOS)
    return img


def find_targets() -> list[Path]:
    if not ART.is_dir():
        raise SystemExit(f"Art dir missing: {ART}")
    out: list[Path] = []
    for p in sorted(ART.glob("*.png")):
        if p.stem.startswith(TARGET_PREFIXES):
            out.append(p)
    return out


def main(dry_run: bool = False) -> int:
    targets = find_targets()
    print(f"Found {len(targets)} target sprites.")
    summary: list[tuple[str, tuple[int, int], tuple[int, int]]] = []

    for art_path in targets:
        name = art_path.name
        stem = art_path.stem
        assets_path = ASSETS / f"{stem}.imageset" / f"{name}"

        with Image.open(art_path) as im:
            orig_size = im.size
            rgba = np.array(im.convert("RGBA"))

        before = rgba.copy()
        cleaned = dehalo(rgba)
        if stem.startswith(DARK_MATTE_PREFIXES):
            cleaned = remove_outer_matte_ring(cleaned)
        cleaned_pre_trim = np.array(Image.fromarray(cleaned, mode="RGBA"))
        out_img = trim_and_resize(Image.fromarray(cleaned, mode="RGBA"))

        # Diagnostics compare before-dehalo to after-dehalo (same shape).
        before_semi = ((before[..., 3] > 1) & (before[..., 3] < 250)).sum()
        after_semi = ((cleaned_pre_trim[..., 3] > 1) & (cleaned_pre_trim[..., 3] < 250)).sum()
        keyed = ((before[..., 3] > 0) & (cleaned_pre_trim[..., 3] == 0)).sum()

        if not dry_run:
            out_img.save(art_path, "PNG", optimize=True)
            if assets_path.exists():
                out_img.save(assets_path, "PNG", optimize=True)
            else:
                print(f"  ! missing assets copy: {assets_path}")

        summary.append((name, orig_size, out_img.size))
        print(f"  {name}: {orig_size} -> {out_img.size}  fringe {before_semi}->{after_semi}  keyed={keyed}")

    print(f"\nWrote {len(summary)} files.")
    return 0


if __name__ == "__main__":
    sys.exit(main(dry_run=("--dry-run" in sys.argv)))
