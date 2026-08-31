#!/usr/bin/env python3
"""Slice a 4x2 green-screen keyframe sheet into transparent PNG frames.

Usage: slice_transition_sheet.py SHEET.png OUTDIR NAME --match TO_POSE.png
                                 [--from FROM_POSE.png] [--drop 3,4]
                                 [--canvas-scale 1.35]
Writes OUTDIR/NAME-000.png ... NAME-007.png.

--drop discards source cells by index before anything else, for when a sheet
is right everywhere except one or two badly drawn poses. The kept frames are
renumbered, so the clip stays contiguous.

--canvas-scale forces the output canvas multiplier instead of computing the
smallest one that fits. Every clip the app plays through the same view must
share one multiplier, or they render at different sizes.

Refuses to write frames whose body-to-face proportions do not match the pose
sprites they join. Matching eye width is NOT enough: an image model will
happily draw the same face on a stockier body, which reads on screen as the
head suddenly changing size at the handoff. See check_proportions.

The app fits each sprite into a fixed box, and the seated pose sprite already
fills that box almost exactly. A standing pose with arms overhead, lifted by a
jump, simply does not fit -- which is what clipped his hands and feet.

So the frames go on a canvas M times the pose sprite's, with the character
drawn at the SAME pixel size it would have on the pose canvas. The app then
renders these frames in a box M times larger. Same scale factor, same
on-screen character size, but room above for the jump. M is printed and must
match PoseTransition.canvasScale.

Within the canvas the character is scaled so his eyes match the pose sprite's
(eye separation is the reliable "same size" measure -- his height legitimately
changes when he crouches). His feet are placed on the pose sprite's ground
line, expressed in the enlarged canvas: because the larger box is centred on
the same point, the pose canvas sits centred inside the output canvas, and the
ground line moves down with it.
"""
import sys
from pathlib import Path

from PIL import Image
import numpy as np

COLS, ROWS = 4, 2

# How far a handoff frame's body-to-face ratio may drift from the pose sprite
# it joins. The drift that was visible on screen as "his head gets bigger"
# measured 7% at the handoff frame and 19% at the start frame, so the bar sits
# below both.
PROPORTION_TOLERANCE = 0.05

# A seated frame should show roughly as much sandal as its neighbours. Feet that
# vanish under the robe for one frame and reappear the next read as a glitch, so
# a frame showing less than this fraction of the clip's maximum fails. Keep the
# bar high: the user must never see feet disappear and return.
FOOT_VISIBILITY_FLOOR = 0.60


def eye_separation(img: Image.Image) -> float | None:
    """Horizontal distance between the two eye whites, in pixels."""
    a = np.asarray(img.convert("RGBA")).astype(int)
    r, g, b, alpha = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    whites = (alpha > 200) & (r > 225) & (g > 225) & (b > 225)
    xs = np.nonzero(whites)[1]
    if xs.size < 20:
        return None
    mid = np.median(xs)
    left, right = xs[xs < mid], xs[xs >= mid]
    if left.size == 0 or right.size == 0:
        return None
    return float(right.mean() - left.mean())


def body_to_face(img: Image.Image) -> float:
    """Character height measured in face widths.

    Pose-independent enough to compare a drawn frame against the sprite it
    hands off to, as long as both are the same posture. Catches a character
    drawn with correct facial size but a shortened body.
    """
    sep = eye_separation(img)
    box = img.getbbox()
    if sep is None or sep <= 0 or box is None:
        raise SystemExit("could not measure body-to-face ratio")
    return (box[3] - box[1]) / sep


def sandal_pixels(img: Image.Image) -> int:
    """Count brown sandal/foot pixels.

    Deliberately narrow: sandal brown is darker and redder than the skin, and
    nothing like the cream robe. Used only to compare frames of one sheet
    against each other, so the absolute number does not matter.
    """
    a = np.asarray(img.convert("RGBA")).astype(int)
    r, g, b, alpha = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    return int(((alpha > 128) & (r > 80) & (r < 170) & (r - b > 40) & (g < 130)).sum())


def check_feet(frames: list[Image.Image]) -> None:
    """Fail when feet disappear and come back mid-clip.

    The generator likes to bury the feet under the robe hem on a landing frame
    and draw them again on the next one. On screen that pops.
    """
    counts = [sandal_pixels(f) for f in frames]
    peak = max(counts)
    hidden = [i for i, n in enumerate(counts) if n < peak * FOOT_VISIBILITY_FLOOR]
    print("  feet: " + " ".join(f"{n * 100 // peak}%" for n in counts))
    if hidden:
        raise SystemExit(
            "FOOT CHECK FAILED\n  frame(s) "
            + ", ".join(str(i) for i in hidden)
            + " hide the feet while other frames show them. Redraw so the sandals "
            "stay visible below the robe hem in every grounded frame."
        )


def check_proportions(
    frames: list[Image.Image], to_pose: Image.Image, from_pose: Image.Image | None
) -> None:
    """Fail loudly when a handoff frame is drawn off-model.

    Only the end frames are checked. The middle of a jump legitimately changes
    the character's height -- a deep crouch is genuinely shorter -- so only the
    frames that sit next to a pose sprite have a proportion to match.
    """
    checks = [("last frame", frames[-1], to_pose, "the pose it hands off to")]
    if from_pose is not None:
        checks.append(("first frame", frames[0], from_pose, "the pose it starts from"))

    problems = []
    for label, frame, pose, described in checks:
        got, want = body_to_face(frame), body_to_face(pose)
        drift = got / want - 1
        status = "ok" if abs(drift) <= PROPORTION_TOLERANCE else "OFF-MODEL"
        print(f"  {label}: body-to-face {got:.2f} vs {want:.2f} ({drift:+.0%}) {status}")
        if abs(drift) > PROPORTION_TOLERANCE:
            shape = "stockier" if drift < 0 else "lankier"
            problems.append(
                f"{label} is {abs(drift):.0%} {shape} than {described}. "
                "Rescaling cannot fix this -- redraw the sheet with that pose "
                "matched to the sprite."
            )
    if problems:
        raise SystemExit("PROPORTION CHECK FAILED\n  " + "\n  ".join(problems))


def key_out_green(tile: Image.Image) -> Image.Image:
    """Make green-screen pixels transparent."""
    tile = tile.convert("RGBA")
    px = tile.load()
    for y in range(tile.height):
        for x in range(tile.width):
            r, g, b, a = px[x, y]
            if g > 110 and g - r > 110 and g - b > 110:
                px[x, y] = (r, g, b, 0)
    return tile


def main() -> None:
    sheet_path, outdir, name = sys.argv[1], Path(sys.argv[2]), sys.argv[3]
    if "--match" not in sys.argv:
        raise SystemExit("--match POSE.png is required")
    pose_path = sys.argv[sys.argv.index("--match") + 1]
    from_pose = None
    if "--from" in sys.argv:
        from_pose = Image.open(sys.argv[sys.argv.index("--from") + 1]).convert("RGBA")
    drop = set()
    if "--drop" in sys.argv:
        drop = {int(n) for n in sys.argv[sys.argv.index("--drop") + 1].split(",")}
    forced_scale = None
    if "--canvas-scale" in sys.argv:
        forced_scale = float(sys.argv[sys.argv.index("--canvas-scale") + 1])
    outdir.mkdir(parents=True, exist_ok=True)

    # Target geometry, taken from the pose sprite this clip hands off to.
    pose = Image.open(pose_path).convert("RGBA")
    pose_box = pose.getbbox()
    pose_eyes = eye_separation(pose)
    if pose_eyes is None or pose_box is None:
        raise SystemExit(f"could not measure {pose_path}")
    canvas_w, canvas_h = pose.size
    pose_ground = pose_box[3]  # feet, in pose-canvas pixels

    sheet = Image.open(sheet_path).convert("RGBA")
    tw, th = sheet.width // COLS, sheet.height // ROWS

    cut = []
    for row in range(ROWS):
        for col in range(COLS):
            tile = sheet.crop((col * tw, row * th, (col + 1) * tw, (row + 1) * th))
            keyed = key_out_green(tile)
            box = keyed.getbbox()
            sep = eye_separation(keyed)
            if box is None or sep is None or sep <= 0:
                raise SystemExit(f"frame {len(cut)}: empty or no eyes found")
            cut.append((keyed, box, sep))

    if drop:
        cut = [c for i, c in enumerate(cut) if i not in drop]
        print(f"  dropped source cells {sorted(drop)}; {len(cut)} frames remain")

    # Feet in the source sheet: the lowest point across all frames is the
    # ground. Each frame's gap above it is its jump height, in source pixels.
    sheet_ground = max(box[3] for _, box, _ in cut)

    # Room the frames need, in pose-canvas pixels, at matched eye width: the
    # widest pose, and the tallest pose lifted by its jump.
    need_w = max((b[2] - b[0]) * (pose_eyes / s) for _, b, s in cut)
    need_top = max(
        ((b[3] - b[1]) + (sheet_ground - b[3])) * (pose_eyes / s) for _, b, s in cut
    )
    # Enlarge the canvas until the tallest frame clears the top and the widest
    # clears the sides, with a 12px margin. The character is NOT scaled by this;
    # only the empty space grows, so on-screen size is unchanged.
    #   half the added height sits above the pose ground line
    if forced_scale is not None:
        scale = forced_scale
    else:
        scale = 1.0
        for _ in range(64):
            out_w, out_h = canvas_w * scale, canvas_h * scale
            ground = pose_ground + (out_h - canvas_h) / 2
            if ground - need_top >= 12 and (out_w - need_w) / 2 >= 12:
                break
            scale += 0.05
        scale = round(scale, 2)
    # Whatever scale we ended on, the tallest frame must still clear the top.
    if pose_ground + (canvas_h * scale - canvas_h) / 2 < need_top:
        raise SystemExit(
            f"canvas scale {scale} is too small for this sheet; needs at least "
            f"{round(1 + 2 * (need_top - pose_ground) / canvas_h + 0.05, 2)}"
        )
    out_w, out_h = round(canvas_w * scale), round(canvas_h * scale)
    ground = pose_ground + (out_h - canvas_h) / 2

    built = []
    for keyed, box, sep in cut:
        factor = pose_eyes / sep
        char = keyed.crop(box)
        char = char.resize(
            (max(1, round(char.width * factor)), max(1, round(char.height * factor))),
            Image.LANCZOS,
        )
        frame = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
        lift = (sheet_ground - box[3]) * factor
        x = round((out_w - char.width) / 2)
        y = round(ground - lift - char.height)
        frame.paste(char, (x, y), char)
        built.append(frame)

    # Verify before writing: a failed check must leave the previous frames in
    # place rather than half-replacing them with off-model art.
    check_proportions(built, pose, from_pose)
    check_feet(built)
    for i, frame in enumerate(built):
        frame.save(outdir / f"{name}-{i:03d}.png")

    print(f"wrote {len(cut)} frames at {out_w}x{out_h}")
    print(f"canvasScale = {scale}   <-- must match PoseTransition.canvasScale")


if __name__ == "__main__":
    main()
