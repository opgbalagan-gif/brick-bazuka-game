# BRICK BAZUKA

Vertical 9:16 arcade prototype for Godot 4. The bazooka is both the weapon and the movement system: aim, shoot, recoil, fly, smash bricks and collect cash.

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
- Tap upgrade cards on the home screen to purchase levels.

## Gameplay systems

- The restored assisted controller supplies the original tap boost, horizontal correction, gravity, air drag and platform bounce.
- Bazooka recoil is additive (`velocity += -shot_direction * recoil_force`) and never replaces existing velocity.
- Physics/collision stays axis-aligned; only the character and weapon visual layers rotate.
- The vertical world is generated continuously above the player, with brick structures positioned for downward and diagonal shots.
- Normal, reinforced, graffiti and cash bricks have distinct behavior/appearance.
- Rockets have directional flight, trails and explosion radius; destroyed bricks create debris and can drop cash.
- The original platform bounce is restored; bazooka recoil remains an additional trajectory-control impulse.
- Jet Boots, Bazooka, Cash Magnet and Shield levels affect the live run.
- Three persistent missions automatically pay rewards once their targets are reached.
- Money, upgrade levels, mission progress, best height, daily reward and settings save to `user://brick_bazuka_save.cfg`.

## Asset layout

Project art lives in `assets/ui`, `assets/characters`, `assets/weapons`, `assets/blocks`, `assets/pickups`, `assets/effects` and `assets/backgrounds`. The supplied hero is stored as a transparent main-character sprite; supporting art is original SVG and procedural pixel-style rendering.

## Smoke test

```powershell
godot --headless --path . --script res://scripts/smoke_test.gd
```
