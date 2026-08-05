"""Build aligned modular 128px atlases from the approved Wuyang directions.

The outfit and weapon atlases deliberately share the same 8x8 cell contract.
Godot composites them only when equipment changes, so runtime animation still
uses one Sprite3D and never suffers layer depth-order artifacts.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


CELL_SIZE = 128
FRAME_COUNT = 8
ROW_SOURCES = (
    ("screen_n", "back.png"),
    ("screen_ne", "iso_back_right.png"),
    ("screen_e", "right.png"),
    ("screen_se", "iso_front_right.png"),
    ("screen_s", "front.png"),
    ("screen_sw", "iso_front_left.png"),
    ("screen_w", "left.png"),
    ("screen_nw", "iso_back_left.png"),
)
HAND_POINTS = {
    "screen_n": ((42, 70, 27, 79), (86, 70, 101, 79)),
    "screen_ne": ((46, 72, 34, 82), (83, 68, 101, 76)),
    "screen_e": ((73, 70, 94, 77),),
    "screen_se": ((42, 76, 29, 88), (84, 75, 101, 86)),
    "screen_s": ((39, 75, 24, 90), (89, 75, 104, 90)),
    "screen_sw": ((44, 75, 27, 86), (86, 76, 99, 88)),
    "screen_w": ((55, 70, 34, 77),),
    "screen_nw": ((45, 68, 27, 76), (82, 72, 94, 82)),
}


def repository_root() -> Path:
    return Path(__file__).resolve().parents[2]


def source_directory(root: Path) -> Path:
    candidates = list(
        (root / "assets/characters/wuyang/pixel_pipeline/directions_v1").glob(
            "*/preview_3x3.png"
        )
    )
    if len(candidates) != 1:
        raise RuntimeError(f"Expected one approved multi-view set, found {len(candidates)}")
    return candidates[0].parent


def recolor_earth_guard(source: Image.Image) -> Image.Image:
    result = source.copy().convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0 or max(red, green, blue) > 165:
                continue
            if red > green * 1.18 and red > blue * 1.12:
                continue
            if blue >= red + 4 and green >= red:
                pixels[x, y] = (
                    min(255, int(red * 1.18 + 12)),
                    min(255, int(green * 0.82 + 6)),
                    min(255, int(blue * 0.55 + 4)),
                    alpha,
                )
    return result


def draw_dual_daggers(direction: str) -> Image.Image:
    layer = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for hand_x, hand_y, tip_x, tip_y in HAND_POINTS[direction]:
        delta_x = tip_x - hand_x
        delta_y = tip_y - hand_y
        length = max(1.0, (delta_x * delta_x + delta_y * delta_y) ** 0.5)
        normal_x = -delta_y / length
        normal_y = delta_x / length
        grip_x = int(round(hand_x - delta_x / length * 4.0))
        grip_y = int(round(hand_y - delta_y / length * 4.0))
        draw.line((grip_x, grip_y, hand_x, hand_y), fill=(38, 28, 25, 255), width=3)
        draw.line((hand_x, hand_y, tip_x, tip_y), fill=(31, 39, 46, 255), width=4)
        draw.line((hand_x, hand_y, tip_x, tip_y), fill=(151, 184, 199, 255), width=2)
        draw.polygon(
            (
                (tip_x, tip_y),
                (int(tip_x - delta_x / length * 5 + normal_x * 2), int(tip_y - delta_y / length * 5 + normal_y * 2)),
                (int(tip_x - delta_x / length * 5 - normal_x * 2), int(tip_y - delta_y / length * 5 - normal_y * 2)),
            ),
            fill=(205, 221, 224, 255),
        )
    return layer


def build_atlas(rows: dict[str, Image.Image]) -> Image.Image:
    atlas = Image.new(
        "RGBA", (CELL_SIZE * FRAME_COUNT, CELL_SIZE * len(ROW_SOURCES)), (0, 0, 0, 0)
    )
    for row_index, (direction, _) in enumerate(ROW_SOURCES):
        frame = rows[direction]
        for column in range(FRAME_COUNT):
            atlas.alpha_composite(frame, (column * CELL_SIZE, row_index * CELL_SIZE))
    return atlas


def main() -> None:
    root = repository_root()
    source_dir = source_directory(root)
    output_dir = root / "assets/characters/wuyang/modular"
    output_dir.mkdir(parents=True, exist_ok=True)

    traveler_rows: dict[str, Image.Image] = {}
    earth_rows: dict[str, Image.Image] = {}
    dagger_rows: dict[str, Image.Image] = {}
    empty_rows: dict[str, Image.Image] = {}
    for direction, filename in ROW_SOURCES:
        source = Image.open(source_dir / filename).convert("RGBA")
        if source.size != (CELL_SIZE, CELL_SIZE):
            raise RuntimeError(f"{filename} must be {CELL_SIZE}x{CELL_SIZE}, got {source.size}")
        traveler_rows[direction] = source
        earth_rows[direction] = recolor_earth_guard(source)
        dagger_rows[direction] = draw_dual_daggers(direction)
        empty_rows[direction] = Image.new("RGBA", source.size, (0, 0, 0, 0))

    outputs = {
        "outfit_wanderer": build_atlas(traveler_rows),
        "outfit_earth_guard": build_atlas(earth_rows),
        "weapon_none": build_atlas(empty_rows),
        "weapon_dual_daggers": build_atlas(dagger_rows),
    }
    for name, image in outputs.items():
        image.save(output_dir / f"{name}_8dir_atlas.png", optimize=True)

    manifest = {
        "version": 1,
        "cell_size": [CELL_SIZE, CELL_SIZE],
        "frames_per_direction": FRAME_COUNT,
        "row_order_top_to_bottom": [direction for direction, _ in ROW_SOURCES],
        "outfits": ["outfit_wanderer", "outfit_earth_guard"],
        "weapons": ["weapon_none", "weapon_dual_daggers"],
        "composition": "outfit RGBA followed by weapon RGBA; identical cell anchors",
        "source": source_dir.relative_to(root).as_posix(),
    }
    (output_dir / "wuyang_modular_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wuyang modular atlases written to {output_dir}")


if __name__ == "__main__":
    main()
