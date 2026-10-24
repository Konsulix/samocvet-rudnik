# Каменное поле

`stone-frame-source.png` — предоставленный пользователем набор элементов.
`stone-board-reference.png` — предоставленный пользователем референс окружения.

Рамка и плитка нарезаны без перерисовки инструментом
`prototype/tools/slice_stone_board.py` в `godot/assets/board/stone_field/`.
Рамка следует границе игровых клеток: `board_contour.gd` выделяет замкнутые
контуры, в том числе отверстия и отдельные участки. `board_view.gd` строит
вдоль них каменный бортик с фаской, используя фактуру из предоставленной рамки.
Подложка есть только под игровыми клетками; через вырезы виден фон уровня.
Размер поля учитывает толщину рамки. Геометрия проверяется на 30 раскладках
и отдельных случаях с отверстиями и диагональными контактами в
`tests/board_contour_regressions.tscn`.

Фон создан встроенным imagegen, сохранён в `godot/assets/ui/level_bg_stone.png`.
Blender не использовался. Для уменьшенных плиток и рамки включены mipmaps.
Внешний вид обычных фишек, анимация добычи и её правила сохранены.

## Запрос для фона

Use case: background-extraction / precise-object-edit. Reference is the exact
desired environment art direction for a mobile mining match-3 level background.
Create a portrait 2:3 game background plate derived from this reference.
REMOVE THE ENTIRE GAME BOARD, all frame, all grid, all individual tiles and all
loose playing pieces; replace their entire area seamlessly with continuous
natural dark grey fine-grained stone ground. Preserve the tactile
realistic-stylized faceted dark rocks, restrained bronze/gold mineral veins,
emerald crystal outcrops and tiny patches of moss from the reference around the
extreme edges. Composition for a portrait phone: 75 percent central area is calm
plain low-contrast charcoal stone for an overlaid game board; top 17 percent is
also mostly calm stone for a separate overlaid HUD; small decorative emerald
clusters in upper left and lower right corners, small gold-veined host rocks
upper right and lower left, all pushed to outer edges. Keep decoration subtle
and cropped by frame, with generous empty space. Top-down orthographic viewpoint,
neutral soft directional natural light from upper left, realistic matte rock
texture. NO game board, NO rectangular frame or border, NO grid or tile seams,
NO UI, NO text, NO standalone game tokens, NO dramatic colored glow or fog.
This is a reusable seamless-looking environmental backdrop, not a mockup.
Brightness: readable charcoal grey and warm slate, not pitch black; emerald
color subdued so actual game pieces stand out. Output full-bleed portrait
background.
