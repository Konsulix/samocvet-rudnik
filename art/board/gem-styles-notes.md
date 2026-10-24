# Gem styles

The level's top-right gem button opens a selector with six-stone previews:

- `natural` / Natural: the previously selected rounded mineral set.
- `shaped` / Faceted: the user's `image 11.png`, preserved as `gems-shaped-source.png`.

Selection is saved in `Save.d.gem_style`, validated on load and defaults to Natural for old saves.
Only existing sprites and goal icons are redrawn. No level restart, board regeneration, move cost or goal-counter reset.
Textures are cached by resolved file path, so both styles can coexist and switch back correctly.

## Packaging and scale

Run `prototype/tools/slice_gem_sheet.py art/board/gems-shaped-source.png godot/assets/board/gems_shaped --balanced`.
The tool detects six alpha silhouettes, retains their proportions and original RGBA edges, and balances visible area to a target of 27,000 opaque pixels, with a maximum dimension of 224 pixels in a 256-pixel canvas.
The existing gameplay size multiplier of 0.9 is retained. This keeps the broad blue circle from dominating while allowing diamonds and triangles enough room. Mipmaps and the existing facet-detail shader are retained.

Source order: red, yellow, blue, green, purple, white.
Game colour IDs remain: red, blue, green, yellow, purple, white.

## Verification

`tests/gem_style_regressions.tscn` clicks the actual picker, validates all six textures, unchanged live nodes and gameplay state, reloads the saved selection and switches back through the texture cache.
Screenshots: `godot/build/gem-style-picker.png` and `gem-style-shaped.png`.
For a regular playtest: `-- level=7 gem_style=shaped` (persists the selection).
