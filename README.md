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

- Phones start with finger controls and no sensor permission prompt. Hold the left or right half for 0.18 seconds to steer, or drag horizontally to steer immediately. Drag distance controls speed; sliding back across the starting point reverses direction. Release to brake. The corner arrow buttons also move the hero.
- A short tap fires once on release at the nearest visible ghost. Holds and swipes do not shoot. A second finger can tap to shoot while the first keeps steering. Canceled touches, focus loss, pause, results and restart clear gesture state.
- The **НАКЛОН** button switches to optional phone tilt. On iPhone, then tap **ВКЛЮЧИТЬ НАКЛОН** and allow motion/orientation access. **ПАЛЕЦ** switches back. Each run calibrates the initial phone position as neutral; a 3-degree dead zone filters hand tremors. Rotation and returning from a hidden tab recalibrate the sensor. Sensor access requires HTTPS (or localhost); finger controls work without sensor support or permission.
- On desktop, use **←/→** or physical **A/D** (**Ф/В** on a Russian layout) to move. The first movement key dismisses the introductory overlay and starts play. Keyboard hints appear on the title screen and before the first move; platform jumps remain automatic. Taps and clicks fire independently of movement.
- The published Web game introduces phone controls in the menu and first-play hint on every device. Mouse movement and holds do not steer the hero; a desktop preview can still use the keyboard and click to fire.
- The hero faces horizontal travel and keeps the last facing during vertical flight. Lean follows movement; shooting never reverses the body. The bazooka aims independently behind the hero so it cannot cover the face.
- Rockets leave the bazooka's downward-facing muzzle, clear the barrel for 0.08 seconds, then track the selected ghost as it moves. If it disappears, they seek another visible ghost; with no ghosts, a shot continues straight down. Shooting does not change the hero's position, velocity or trajectory in any direction.
- Enter or Space: start from the title screen; during play, fire a homing rocket. Either key also resumes a paused run without firing.
- Escape: pause.
- The title screen has one active control: START. Its painted button launches the game.
- On phones, the introductory glove and short hint explain holding, swiping and tapping. The first touch or arrow-button movement dismisses the hint and starts play.

## Gameplay systems

- The game world is shown at 80% scale: a 675×1200 play area fits inside the 540×960 portrait view. Hero, bazooka, platforms, ghosts, pickups and effects share the same transform and collision coordinates. Score, masks, menus, touch controls and name input retain their original readable size. Camera scrolling, wrapping, targeting, respawns and cleanup use the expanded world bounds.
- Touch, tilt and keyboard steering control horizontal movement with smooth acceleration and braking. Active finger steering takes priority over tilt. Gravity and platform bounces control vertical movement. Shots apply no jump impulse, horizontal correction or recoil to the hero; only the weapon plays a firing animation.
- Crossing either side of the screen brings the hero in from the opposite side, preserving speed and the current jump without losing a life.
- Each spring is consumed on landing and gives exactly one double-height jump (about 740 pixels). The next ordinary platform gives the normal 370-pixel jump, even immediately afterward. A new spring gives a new single high jump. The first spring is on the third opening platform; later springs become rarer as the run's height increases. They start 5–7 safe rows apart, with two more rows of spacing for each 500 height points: 9–11 rows at 1,000 points and 17–19 at 3,000. Restarting resets this spacing. There is no timed boost or boost bar.
- Physics/collision stays axis-aligned; only the character and weapon visual layers rotate.
- The vertical world is generated continuously above the player. The first four boards are reinforced and survive the first landing. At low heights the generator strongly favors reinforced boards; this preference gradually decreases through 1,500 height points.
- Safe platforms are 110–160 world units wide (88–128 pixels in the portrait view) and retain their artwork's proportions. Rows stay 250–310 world units apart (200–248 pixels on screen), so more of the route is visible while jump reach stays the same. Brown brick, stone, cracked and slime-covered variants use the supplied artwork.
- After the first four safe rows, a fake platform appears beside an ordinary platform every 3–5 rows (spring and boot rows postpone it). Its three loose, cracked stone slabs crumble immediately on landing: the hero keeps falling, including after a spring jump. Falling rubble marks the collapse. Each fake is an extra decoy with no spring; a safe platform remains beside it, moving at the same speed with a fixed 48-pixel gap. Rockets pass through decoys too.
- Jet boots first appear on the sixth safe row, then every 12–16 rows (spring rows postpone them). Touching the boots consumes them and propels the hero upward at 820 pixels/second for 2.8 seconds, while left/right steering still works. Contact defeats ghosts without losing lives. A boot icon and fuel bar show remaining flight; exhaust appears only while the boots are active. Gravity returns with brief protection after fuel runs out. Pause freezes fuel; restart and fall recovery clear it.
- Generated platform rows glide left and right with smooth turns, independent phases, 50–110 pixels of travel each way and peak speeds of 35–60 pixels per second. Rows with decoys have less travel when needed to keep both platforms inside the screen. Springs and collision areas follow the platforms; pausing, the introductory hint and sensor permission freeze their motion. The first platform begins under the hero.
- Rockets pass through all platforms and springs, hitting only ghosts. Their explosions also leave platforms intact. Landing still damages platforms: reinforced stone takes two landings and cracks after the first; destroyed bricks create debris.
- Ghost enemies appear 260 world units below the hero, materialize for 0.35 seconds, then approach at up to 320 world units/second (previously 540). They turn with gentler acceleration, giving more time to react. Attacks begin after 2.5 seconds and recur every few seconds, becoming more frequent at greater heights. At most three attackers coexist; missed attacks expire after 4.5 seconds. Collision checks cover the traveled path so attacks and jet flight cannot pass through each other unnoticed.
- Ambient ghosts also inhabit the route, including the opening section. They drift at 25–42 world units/second, appear every 2–4 eligible rows, and do not use the attack slots. Spring and jet-boot rows postpone ambient spawns to keep pickups clear. They can be shot or defeated during jet flight like attacking ghosts.
- A rocket, nearby explosion or jet-boot collision removes the ghost immediately and plays the supplied death animation once. Otherwise touching an attacking ghost consumes one of three lives, with brief invulnerability and knockback; that attacker disappears after the hit.
- Ghost death plays at twice the source speed, completing the whole dispersal in about 0.92 seconds.
- Falling below the screen consumes one life. If lives remain, the hero respawns on the nearest visible non-fake platform, follows its movement for 0.6 seconds, then resumes jumping. Respawning does not damage the platform or reset the height score. Nearby ghosts are cleared and two seconds of protection give room to recover. If no safe platform remains, a recovery platform is provided. Losing the last life opens the leaderboard.
- The supplied night-city video loops behind the level at 540×960, 24 FPS. Pausing freezes the video and ghost animations; returning to START stops the video.
- The HUD shows the run's numeric height score at the top, using white bubble-letter digits with a black outline. Three masks sampled from the hero's face show lives at the bottom: white masks are remaining lives and dim masks are spent lives. Transient messages appear above them.
- Landing on a platform produces a jump sized for the maximum 310-pixel platform gap plus 60 pixels of clearance. Firing cannot boost or redirect it.
- Movement and weapon strength are fixed. The game has no currency, collectible money, paid upgrades or cash rewards.
- Best height, destroyed-platform count and settings save to `user://brick_bazuka_save.cfg`. Old currency and upgrade fields are ignored on load and removed on the next save.
- The РЕЙТИНГ button opens the board from the menu or pauses the current game. Closing it resumes that same run. A lightweight standalone `leaderboard.html` is also published beside the game. A valid name is saved on the device immediately, independently of network access, and becomes read-only beside ИЗМЕНИТЬ. The Web game and standalone page share the name through localStorage; separate devices/browsers set their own names.
- Ratings preserve the last real downloaded table and label its update time during outages, with a dated public snapshot included in each release. Failed requests retry automatically with backoff. Score submissions persist on the device across restarts and retry the same signed run until confirmed, avoiding duplicate rows. Server-rejected or expired submissions remain local and are marked accordingly; offline scores are never presented as confirmed public results. Scores use a separate private Google Sheet on the existing SOLLERS Apps Script service. Setup and API: [server/google-sheets/README.md](server/google-sheets/README.md).

## Asset layout

Project art lives in `assets/ui`, `assets/characters`, `assets/weapons`, `assets/blocks`, `assets/effects` and `assets/backgrounds`. The title image is used directly as the interactive cover. `assets/backgrounds/night_city_loop.ogv` is the in-game video, with a matching poster while the first frame loads. The transparent in-game hero and separately rotating bazooka remain independent layers. Unused legacy currency artwork is excluded from Web exports.

The hero is drawn through a textured outline that follows the boot soles, hiding the exhaust baked into the supplied sprite during ordinary play. Jet flight reveals the original exhaust. HUD masks use a separate textured outline around the original face. Springs use `assets/powerups/spring.svg`; jet pickups use the laced work boots in `assets/ui/boots_icon.svg`.

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
godot --headless --path . --script res://scripts/homing_test.gd
godot --headless --path . --script res://scripts/fake_platform_test.gd
godot --headless --path . --script res://scripts/gameplay_fixes_test.gd
godot --headless --path . --script res://scripts/touch_control_test.gd
godot --headless --path . --script res://scripts/mouse_ambient_test.gd
godot --headless --path . --script res://scripts/rating_reliability_test.gd
node scripts/test_name_input.mjs
node scripts/test_tilt.mjs
```

The Web leaderboard uses `web/name-input.js` to place a real browser text field over the Godot form, enabling native phone keyboards, Cyrillic input and IME. It follows canvas resizing, stops gameplay key propagation, and disappears when leaving results. Export versioning installs this bridge alongside the tilt bridge. Native builds retain the focused Godot LineEdit.
