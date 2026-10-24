# Natural blockers

Source supplied by user: `blockers-source.png` (Group фывм.png).
Top: mud; middle: one-hit sandstone; bottom-left: two-hit granite; bottom-right: cracked granite.
Packaging: `prototype/tools/slice_blocker_sheet.py`; game sprites: `godot/assets/board/blockers_natural/`.
Original PNG alpha is preserved. Sprites occupy about 90–95% of a cell; the cracked granite body has a separate anchor so loose fragments do not shrink it.

Gas and timber were generated with the built-in image_gen tool, then packaged as transparent sprites. Originals: `gas-source.png`, `timber-source.png`.

## Final gas prompt

Use case: stylized-concept. Asset type: single transparent sprite for a naturalistic mineral match-3 game. Create one compact cloud of mine gas, viewed straight on with slight top-down depth, square silhouette with curled smoky lobes and thin translucent wisps. Smoky muted sage green, pale sulfur yellow highlights, dark olive grey recesses. Finely textured volumetric smoke, realistic painterly 3D rendering, crisp readable broad shapes at 40 pixels, lighting from upper left. Natural geological expedition aesthetic, subdued earthy colors. Centered, isolated, ample transparent padding. No stone, no crystal, no bubbles, no grapes, no cartoon outlines, no neon, no text, no background. Actual transparent RGBA background.

## Final timber prompt

Use case: stylized-concept. Asset type: single transparent overlay sprite for a naturalistic mineral match-3 game. Create a compact square mine timber support bracing: two weathered dark oak beams crossing diagonally in an X, with small dark iron fasteners where they join. Straight-on orthographic front view, subtle shallow bevel depth, wood grain and chipped ends, warm earthy brown wood and worn grey iron, realistic painterly 3D rendering with upper-left lighting, broad readable details at 40 pixels. Beams narrow enough that a colorful gemstone behind the X remains visible through the four large transparent gaps. Nearly square overall proportions, centered with generous empty transparent padding. No wall, no rock, no gemstone, no frame around the X, no floor, no text, no background. Actual transparent RGBA background.

## Runtime

ROCK_MAX retains the original stone type after damage. First granite hit crossfades with a short shake (0.24 s); final contact splits the sprite into six textured shards (0.46 s). Gas expands and fades (0.4 s). One-shot effect nodes are freed after playback.
HUD goals use equal columns with centered icon and counter; collection effects target the actual icon center.
Validation: tests/blocker_playtest.tscn (pass -- animate to exercise all blocker effects); tests/deposit_regressions.tscn.
