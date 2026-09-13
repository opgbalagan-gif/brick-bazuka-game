# BRICK BAZUKA art direction

- Native canvas: 540×960 (9:16), nearest-neighbour texture filtering.
- Core palette: midnight navy, ghostly gray-blue, brick orange, toxic lime and warm gold.
- UI: dark ink silhouettes, lime borders and green primary actions.
- The supplied night-city title art is rendered unaltered as the interactive start screen. The supplied gameplay art is used as a source atlas for the lower city architecture only; floating blocks and the hero are rendered separately so they can move and break.
- Game objects are rendered from the updated SVG assets in these folders plus procedural brick damage, ghost clouds, particles and HUD accents, matching the supplied asset sheet.
- `characters/main_hero.png` is the transparent extraction of the hero supplied by the user.
- `characters/main_hero_body.png` is the weaponless transparent visual layer used for independent body and bazooka rotation.
- `weapons/bazooka_reference.png` is the transparent rotating bazooka layer matching the user-supplied olive launcher reference.
- `weapons/bazooka_body.png` is the transparent lettering-free gameplay layer; the game mirrors this body horizontally and draws `SNW` separately so the label always remains readable.
