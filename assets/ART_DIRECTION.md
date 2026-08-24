# BRICK BAZUKA art direction

- Native canvas: 540×960 (9:16), nearest-neighbour texture filtering.
- Core palette: midnight navy, electric cyan, brick orange, cash green and warm gold.
- UI: heavy dark silhouettes, two-stage cyan borders, bright lime primary actions.
- Game objects are rendered from the SVG assets in these folders plus procedural brick damage, particles and HUD accents.
- `characters/main_hero.png` is the transparent extraction of the hero supplied by the user.
- `characters/main_hero_body.png` is the weaponless transparent visual layer used for independent body and bazooka rotation.
- `weapons/bazooka_reference.png` is the transparent rotating bazooka layer matching the user-supplied olive launcher reference.
- `weapons/bazooka_body.png` is the transparent lettering-free gameplay layer; the game mirrors this body horizontally and draws `SNW` separately so the label always remains readable.
