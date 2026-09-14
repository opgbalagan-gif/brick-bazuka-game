# BRICK BAZUKA

Vertical 9:16 arcade prototype for Godot 4. Bounce on brick platforms and use the bazooka to shoot ghosts.

## Play online

[Launch BRICK BAZUKA in the browser](https://opgbalagan-gif.github.io/brick-bazuka-game/)

## Run

Open `project.godot` in Godot 4.4+ and press **F6/F5**, or launch from a terminal:

```powershell
godot --path .
```

## Controls

- Tilt the phone left/right to steer. Each run calibrates its initial position as neutral; a 3-degree dead zone filters hand tremors. Screen rotation and returning from a hidden tab recalibrate the Web sensor.
- On iPhone, tap **ВКЛЮЧИТЬ НАКЛОН** and allow motion/orientation access. Play waits while this dialog is open. Sensor access requires HTTPS (or localhost on the same device); a plain HTTP LAN address will offer touch arrows instead. Denied or unavailable sensors also have touch-arrow controls.
- On desktop, use **←/→** or physical **A/D** (**Ф/В** on a Russian layout) to move. The first movement key dismisses the introductory overlay and starts play. Keyboard hints appear on the title screen and before the first move; platform jumps remain automatic. Touch/mouse aiming and shooting remain independent of movement.
- Hold touch/mouse, drag to aim, and release toward a ghost to fire.
- The bazooka aims faster than the body; the body smoothly leans toward the same shot direction.
- The rocket spawns from the rotating muzzle and flies toward the aim point. Shooting does not change the hero's position, velocity or trajectory in any direction.
- Enter or Space: start from the title screen; during play, fire straight down. Either key also resumes a paused run without firing.
- Escape: pause.
- The title screen has one active control: START. Its painted button launches the game.
- On phones, before the first shot, the supplied white glove points down and loops a tap gesture without text. The first touch dismisses the hint and starts aiming.

## Gameplay systems

- Tilt/keyboard steering controls horizontal movement with smooth acceleration and braking. Gravity and platform bounces control vertical movement. Shots apply no jump impulse, horizontal correction or recoil to the hero; only the weapon plays a firing animation.
- Crossing either side of the screen brings the hero in from the opposite side, preserving speed and the current jump without losing a heart.
- A spring appears on the third opening platform and then every 5–7 platforms. Landing on it consumes it and doubles jump height for 8 seconds, including subsequent ordinary platform bounces. Another spring refreshes the duration; pausing freezes it. A spring icon and shrinking green bar show the remaining boost.
- Physics/collision stays axis-aligned; only the character and weapon visual layers rotate.
- The vertical world is generated continuously above the player, with brick structures positioned for downward and diagonal shots.
- Single platforms are spaced 250–310 pixels apart, leaving roughly 3–4 visible at once. Brown brick, stone, cracked and slime-covered variants use the supplied artwork.
- All generated platforms glide left and right with smooth turns, independent phases, 50–110 pixels of travel each way and peak speeds of 35–60 pixels per second. They stay fully inside the screen. Springs and collision areas follow the platforms; pausing, the introductory hint and sensor permission freeze their motion. The first platform begins under the hero.
- Rockets pass through all platforms and springs, hitting only ghosts. Their explosions also leave platforms intact. Landing still damages platforms: reinforced stone takes two landings and cracks after the first; destroyed bricks create debris.
- Ghost enemies use the supplied videos as transparent animated sprites: calm while distant, angry within 200 pixels of the hero, and calm again beyond 250 pixels. The gap keeps their expressions from flickering at the boundary.
- A rocket or nearby explosion removes the ghost's collision immediately and plays the supplied death animation once. Touching a live ghost consumes one of three hearts from the first hit, with brief invulnerability and knockback.
- Ghost death plays at twice the source speed, completing the whole dispersal in about 0.92 seconds.
- Falling below the screen also consumes one heart. If hearts remain, the hero returns to the level with a short upward bounce and protection from ghosts; the height score is retained. Losing the third heart ends the run and opens the leaderboard.
- The supplied night-city video loops behind the level at 540×960, 24 FPS. Pausing freezes the video and ghost animations; returning to START stops the video.
- The HUD shows only the run's numeric height score at the top, using white bubble-letter digits with a black outline. Three hearts sit at the bottom center; transient messages appear above them.
- Landing on a platform produces a jump sized for the maximum 310-pixel platform gap plus 60 pixels of clearance. Firing cannot boost or redirect it.
- Movement and weapon strength are fixed. The game has no currency, collectible money, paid upgrades or cash rewards.
- Best height, destroyed-platform count and settings save to `user://brick_bazuka_save.cfg`. Old currency and upgrade fields are ignored on load and removed on the next save.
- At the end of a run, players enter a name and publish their score to a shared top-10 leaderboard. The name is remembered for the next attempt; repeat submissions do not duplicate a run. Scores use a separate private Google Sheet on the existing SOLLERS Apps Script service. Setup and API: [server/google-sheets/README.md](server/google-sheets/README.md).

## Asset layout

Project art lives in `assets/ui`, `assets/characters`, `assets/weapons`, `assets/blocks`, `assets/effects` and `assets/backgrounds`. The title image is used directly as the interactive cover. `assets/backgrounds/night_city_loop.ogv` is the in-game video, with a matching poster while the first frame loads. The transparent in-game hero and separately rotating bazooka remain independent layers. Unused legacy currency artwork is excluded from Web exports.

The hero is drawn through a textured outline that follows the boot soles, hiding the exhaust baked into the supplied sprite without redrawing the character. Springs use the outlined vector asset `assets/powerups/spring.svg`.

The three `assets/blocks/reference_*.png` sheets are unchanged copies of the supplied platform artwork. `PLATFORM_ART` in `scripts/main.gd` selects 13 regions at their original proportions; `assets/blocks/platform_key.gdshader` removes their magenta background and edge spill at draw time.

`assets/ui/tap_glove_down.png` preserves the supplied glove, rotated 180° with its checkerboard background removed. `tools/prepare_tap_glove.ps1 -Source <original.jpg>` prepares the transparent sprite locally without redrawing it.

`assets/characters/ghost/animations.tres` shares three RGBA atlases between enemies, with independent playback times. The 149 frames were extracted from the supplied MP4 clips at 24 FPS, keyed before downscaling to preserve outlines, and cleaned of magenta edge spill. Rebuild the assets from the original BAZOOKA folder with Python and FFmpeg:

```powershell
python tools/prepare_video_assets.py --ffmpeg <ffmpeg.exe> --source-dir <BAZOOKA-folder>
```

The originals are not modified. The preparation script requires FFmpeg with the PNG and Theora encoders; the game itself needs no Python or FFmpeg.

After each Web export, run `python tools/version_web_build.py`. This adds the pack's content hash to its URL so browsers load the rebuilt game instead of an older cached version.

The same step installs and versions `web/tilt-control.js` in the Web build before Godot starts. The bridge handles browser sensor permission, calibration and touch fallbacks; `scripts/tilt_control.gd` reads its axis and supplies keyboard/native sensor input. Orientation data stays on the device. Browser permission reference: [MDN DeviceOrientationEvent.requestPermission](https://developer.mozilla.org/en-US/docs/Web/API/DeviceOrientationEvent/requestPermission).

## Smoke test

```powershell
godot --headless --path . --script res://scripts/smoke_test.gd
godot --headless --path . --script res://scripts/keyboard_test.gd
node scripts/test_tilt.mjs
```
