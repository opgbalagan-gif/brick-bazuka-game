# BRICK BAZUKA

Vertical 9:16 arcade prototype for Godot 4. The bazooka is both the weapon and the movement system: aim, shoot, recoil, fly, smash bricks and collect cash.

## Play online

[Launch BRICK BAZUKA in the browser](https://opgbalagan-gif.github.io/brick-bazuka-game/)

## Run

Open `project.godot` in Godot 4.4+ and press **F6/F5**, or launch from a terminal:

```powershell
godot --path .
```

## Controls

- Hold touch/mouse, drag to aim, and release over a point or brick to fire.
- The bazooka aims faster than the body; the body smoothly leans toward the same shot direction.
- The rocket spawns from the rotating muzzle and recoil pushes the hero in the opposite direction.
- Aim below the hero to climb; aim down-right to recoil up-left and vice versa.
- Space/Enter: fire straight down.
- Pause button or Escape: pause.
- The title screen has one active control: START. Its painted button launches the game.

## Gameplay systems

- The restored assisted controller supplies the original tap boost, horizontal correction, gravity, air drag and platform bounce.
- Bazooka recoil is additive (`velocity += -shot_direction * recoil_force`) and never replaces existing velocity.
- Physics/collision stays axis-aligned; only the character and weapon visual layers rotate.
- The vertical world is generated continuously above the player, with brick structures positioned for downward and diagonal shots.
- Normal, reinforced, graffiti and cash bricks have distinct behavior/appearance.
- Rockets have directional flight, trails and explosion radius; destroyed bricks create debris and can drop cash.
- Ghost enemies use the supplied videos as transparent animated sprites: calm while distant, angry within 200 pixels of the hero, and calm again beyond 250 pixels. The gap keeps their expressions from flickering at the boundary.
- A rocket or nearby explosion removes the ghost's collision immediately and plays the supplied death animation once. Touching a live ghost consumes the shield or one of three hearts, with brief invulnerability and knockback.
- The supplied night-city video loops behind the level at 540×960, 24 FPS. Pausing freezes the video and ghost animations; returning to START stops the video.
- The original platform bounce is restored; bazooka recoil remains an additional trajectory-control impulse.
- Jet Boots, Bazooka, Cash Magnet and Shield levels affect the live run.
- Three persistent missions automatically pay rewards once their targets are reached.
- Money, upgrade levels, mission progress, best height, daily reward and settings save to `user://brick_bazuka_save.cfg`.

## Asset layout

Project art lives in `assets/ui`, `assets/characters`, `assets/weapons`, `assets/blocks`, `assets/pickups`, `assets/effects` and `assets/backgrounds`. The title image is used directly as the interactive cover. `assets/backgrounds/night_city_loop.ogv` is the in-game video, with a matching poster while the first frame loads. Dynamic blocks, currency, rockets, shields and effects are editable SVGs; the transparent in-game hero and separately rotating bazooka remain independent layers.

`assets/characters/ghost/animations.tres` shares three RGBA atlases between enemies, with independent playback times. The 149 frames were extracted from the supplied MP4 clips at 24 FPS, keyed before downscaling to preserve outlines, and cleaned of magenta edge spill. Rebuild the assets from the original BAZOOKA folder with Python and FFmpeg:

```powershell
python tools/prepare_video_assets.py --ffmpeg <ffmpeg.exe> --source-dir <BAZOOKA-folder>
```

The originals are not modified. The preparation script requires FFmpeg with the PNG and Theora encoders; the game itself needs no Python or FFmpeg.

## Smoke test

```powershell
godot --headless --path . --script res://scripts/smoke_test.gd
```
