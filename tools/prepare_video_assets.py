"""Convert the supplied videos to Godot's background stream and RGBA atlases.

Run with --ffmpeg <executable> --source-dir <BAZOOKA directory>.
The original MP4s are left untouched. Only FFmpeg processes video pixels.
"""

import argparse
import json
import math
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FPS = 24
CELL = 192
COLUMNS = 8


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", required=True)
    parser.add_argument("--source-dir", type=Path, required=True)
    args = parser.parse_args()
    source_files = {p.name: p for p in args.source_dir.rglob("*.mp4")}
    scratch = ROOT / ".testdata" / "animation-review"
    output = ROOT / "assets" / "characters" / "ghost"
    output.mkdir(parents=True, exist_ok=True)
    scratch.mkdir(parents=True, exist_ok=True)

    def ffmpeg(*options):
        subprocess.run(
            [args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y", *map(str, options)],
            check=True,
        )

    background = ROOT / "assets" / "backgrounds" / "night_city_loop.ogv"
    ffmpeg(
        "-i", source_files["0914.mp4"], "-an", "-vf",
        "fps=24,scale=540:960:force_original_aspect_ratio=increase,crop=540:960,setsar=1",
        "-c:v", "libtheora", "-q:v", "7", "-g:v", "64", background,
    )
    ffmpeg("-i", background, "-frames:v", "1", background.with_name("night_city_poster.png"))
    clips = {
        "idle": "приведение -1.mp4",
        "alert": "когда игрок рядом -2.mp4",
        "death": "взрыв -1.mp4",
    }
    manifest = {}
    for name, source_name in clips.items():
        frames_dir = scratch / (name + "-frames")
        frames_dir.mkdir(exist_ok=True)
        # Remove only this tool's previous intermediate frames, inside .testdata.
        for old_frame in frames_dir.glob("frame_*.png"):
            old_frame.unlink()
        # Key before downscaling to retain the black outline. The source ghosts
        # are neutral white/gray; cap magenta spill using the clean green channel.
        filters = (
            "fps=24,scale=512:512:flags=lanczos,format=rgba,"
            "colorkey=0xFA16DC:0.30:0.08,"
            "geq=r='min(r(X,Y),g(X,Y)+6)':g='g(X,Y)':"
            "b='min(b(X,Y),g(X,Y)+6)':a='alpha(X,Y)',"
            f"scale={CELL}:{CELL}:flags=lanczos,format=rgba"
        )
        ffmpeg("-i", source_files[source_name], "-an", "-vf", filters,
               frames_dir / "frame_%03d.png")
        count = len(list(frames_dir.glob("frame_*.png")))
        rows = math.ceil(count / COLUMNS)
        ffmpeg("-framerate", FPS, "-i", frames_dir / "frame_%03d.png",
               "-vf", f"tile={COLUMNS}x{rows}:color=0x00000000", "-frames:v", "1",
               output / (name + ".png"))
        manifest[name] = {
            "source": source_name, "fps": FPS, "frames": count,
            "cell_size": CELL, "columns": COLUMNS,
            "duration": count / FPS, "loop": name != "death",
        }
        print(f"{name}: {count} RGBA frames at {FPS} FPS", flush=True)

    (output / "clips.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    # One shared SpriteFrames resource keeps every enemy's state/time independent
    # while sharing atlas textures and avoids loose-frame resource loading on Web.
    lines = [f'[gd_resource type="SpriteFrames" load_steps={sum(c["frames"] for c in manifest.values()) + 4} format=3]', ""]
    for name in clips:
        lines += [f'[ext_resource type="Texture2D" path="res://assets/characters/ghost/{name}.png" id="{name}"]']
    for name, clip in manifest.items():
        for frame in range(clip["frames"]):
            lines += ["", f'[sub_resource type="AtlasTexture" id="{name}_{frame}"]',
                      f'atlas = ExtResource("{name}")',
                      f'region = Rect2({frame % COLUMNS * CELL}, {frame // COLUMNS * CELL}, {CELL}, {CELL})',
                      'filter_clip = true']
    lines += ["", "[resource]", "animations = ["]
    for name, clip in manifest.items():
        frames = ",\n".join(f'{{"duration": 1.0, "texture": SubResource("{name}_{frame}")}}' for frame in range(clip["frames"]))
        lines += ['{', f'"frames": [{frames}],', f'"loop": {str(clip["loop"]).lower()},',
                  f'"name": &"{name}",', f'"speed": {FPS}.0', '},']
    lines += ["]", ""]
    (output / "animations.tres").write_text("\n".join(lines), encoding="utf-8")
    print(f"Background: {background.stat().st_size / 1024 / 1024:.2f} MiB", flush=True)


if __name__ == "__main__":
    main()
