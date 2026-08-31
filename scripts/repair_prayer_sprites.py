#!/usr/bin/env python3
"""Extract and normalize a three-pose prayer strip into Qasim assets."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from dehalo_sprites import dehalo


POSES = ("qiyam", "ruku", "sujud")
TARGET_HEIGHT = 520
PAD = 12


def remove_checkerboard(arr: np.ndarray) -> np.ndarray:
    """Remove a light checkerboard connected to the image border."""
    rgb = arr[..., :3].astype(np.int16)
    alpha = arr[..., 3].copy()
    gray = (rgb.max(axis=-1) - rgb.min(axis=-1) <= 14) & (rgb.min(axis=-1) >= 180)
    seen = np.zeros(gray.shape, dtype=bool)
    stack: list[tuple[int, int]] = []
    height, width = gray.shape
    for x in range(width):
        if gray[0, x]:
            stack.append((0, x))
        if gray[height - 1, x]:
            stack.append((height - 1, x))
    for y in range(height):
        if gray[y, 0]:
            stack.append((y, 0))
        if gray[y, width - 1]:
            stack.append((y, width - 1))

    while stack:
        y, x = stack.pop()
        if y < 0 or y >= height or x < 0 or x >= width or seen[y, x] or not gray[y, x]:
            continue
        seen[y, x] = True
        stack.extend(((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)))

    alpha[seen] = 0
    out = arr.copy()
    out[..., 3] = alpha
    out[alpha == 0, :3] = 0
    return out


def trim_and_resize(arr: np.ndarray) -> Image.Image:
    alpha = arr[..., 3]
    ys, xs = np.where(alpha > 8)
    if ys.size == 0:
        raise ValueError("pose panel has no visible pixels")
    y0, y1 = max(0, ys.min() - PAD), min(arr.shape[0], ys.max() + PAD + 1)
    x0, x1 = max(0, xs.min() - PAD), min(arr.shape[1], xs.max() + PAD + 1)
    img = Image.fromarray(arr[y0:y1, x0:x1], mode="RGBA")
    if img.height != TARGET_HEIGHT:
        width = max(1, round(img.width * TARGET_HEIGHT / img.height))
        img = img.resize((width, TARGET_HEIGHT), Image.Resampling.LANCZOS)
    return Image.fromarray(dehalo(np.array(img.convert("RGBA"))), mode="RGBA")


def keep_main_components(arr: np.ndarray) -> np.ndarray:
    """Keep the character and mat while dropping detached strip fragments."""
    visible = arr[..., 3] > 8
    total = int(visible.sum())
    if total == 0:
        return arr
    seen = np.zeros(visible.shape, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    height, width = visible.shape
    for y, x in zip(*np.where(visible)):
        if seen[y, x]:
            continue
        stack = [(int(y), int(x))]
        seen[y, x] = True
        component: list[tuple[int, int]] = []
        while stack:
            cy, cx = stack.pop()
            component.append((cy, cx))
            for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                if 0 <= ny < height and 0 <= nx < width and visible[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        components.append(component)
    keep = id(max(components, key=len))
    out = arr.copy()
    for component in components:
        if id(component) != keep:
            ys, xs = zip(*component)
            out[ys, xs, 3] = 0
    out[out[..., 3] == 0, :3] = 0
    return out


def extract(strip: Path, character: str, output_root: Path, poses: tuple[str, ...]) -> None:
    with Image.open(strip) as source:
        arr = np.array(source.convert("RGBA"))
    if np.all(arr[..., 3] == 255):
        arr = remove_checkerboard(arr)
    else:
        arr[arr[..., 3] < 8, :3] = 0

    width = arr.shape[1]
    for index, pose in enumerate(poses):
        x0 = round(index * width / len(poses))
        x1 = round((index + 1) * width / len(poses))
        image = trim_and_resize(keep_main_components(arr[:, x0:x1]))
        name = f"{character}-{pose}.png"
        art_path = output_root / "Qasim" / "Resources" / "Art" / name
        catalog_path = output_root / "Qasim" / "Resources" / "Assets.xcassets" / f"{character}-{pose}.imageset" / name
        art_path.parent.mkdir(parents=True, exist_ok=True)
        catalog_path.parent.mkdir(parents=True, exist_ok=True)
        image.save(art_path, "PNG", optimize=True)
        image.save(catalog_path, "PNG", optimize=True)
        print(f"{name}: {image.size} -> {art_path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--strip", type=Path, required=True)
    parser.add_argument("--character", choices=("hana", "nur"), required=True)
    parser.add_argument("--poses", default=",".join(POSES))
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    poses = tuple(pose.strip() for pose in args.poses.split(",") if pose.strip())
    if not poses:
        raise SystemExit("--poses must contain at least one pose")
    extract(args.strip, args.character, args.repo, poses)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
