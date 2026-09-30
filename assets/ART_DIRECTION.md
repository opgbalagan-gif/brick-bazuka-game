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
# September 30 supplied art

`assets/release-september` contains the user-supplied PNGs, copied unchanged; AtlasTexture resources select their occupied regions for rendering. Identical uploaded copies of the orange skin and buttons are deduplicated. The original artwork is used for boots, the rare safe, the cash case, START/РЕЙТИНГ buttons, the logo, skin previews and the artist portrait. The orange skin's separate playable body is `prisoner-body.png` and its rendering region is in `prisoner-body.tres`.

The playable orange body was edited using the built-in imagegen tool. Prompt: “Remove the entire green bazooka, scope and hanging sling from the supplied transparent orange prisoner №13 sprite. Reconstruct the small hidden hand/clothing areas. Preserve the exact white screaming mask, orange hood/outfit with black 13, gloves, tan boots, proportions, pose, black outline and pixel-art style. Keep the gripping hand ready for an independent weapon. Transparent background, no added weapon, accessories, shadows or jet flames.” The game keeps the bazooka as its own moving layer.

UI frames and the flying promo ticket are native Godot drawings. Cyrillic headings use the OFL-licensed Russo One font from Google Fonts; its license is stored alongside the font in `assets/fonts/OFL-RussoOne.txt`.
