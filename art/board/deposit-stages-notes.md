# Объекты 2×2

Источник пользователя: `deposit-stages-source.png`.
Прозрачный лист: `deposit-stages-transparent.png`.
Инструмент: встроенный imagegen, редактирование с `transparent_background=true`.
Нарезка: `prototype/tools/slice_deposit_sheet.py`; результат в `godot/assets/board/deposits`.

Верхний ряд — жеода; нижний — минерал. В каждом ряду четыре состояния
добычи и конечное состояние оставшейся породы. Четыре касания снимают
оболочку. Каждый прямой бустер повреждает минерал на 25%; после полного
повреждения награды нет, остаётся блок. Жеода сохраняет награду при бустерах
и всегда остаётся на поле после сбора.

## Запрос удаления фона

Нарезка привязывает основной каменный блок к общей области `(64,64,384,384)`
в спрайте 512×512. Координаты кладки заданы отдельно от прозрачных полей и
осыпавшихся фрагментов; все пять состояний рисуются по одному якорю.
На поле эта область занимает `2 * TS - 2` пикселя. Константа
`BoardSprites.DEPOSIT_CORE` должна соответствовать скрипту нарезки.

Edit target: the attached exact sprite sheet. Task: background extraction ONLY.
Remove the entire grey/brown/black studio background and all cast shadows into
a genuinely transparent alpha background. Preserve all ten rock deposit assets
pixel-faithfully, with their internal dark stone cavities opaque. Preserve the
original 2-row by 5-column layout with generous gaps, consistent object size,
same view, texture, color, cracks and contents. Top row bronze/gold mineral:
5 sequential stages from closed stone block, cracked, small exposed center,
large exposed center, final empty rock cavity with golden stone resting at
lower right. Bottom row amethyst geode: 5 sequential stages closed, cracked,
small cavity, wider cavity, final open empty host rock with scattered purple
crystal fragments. Keep exactly these stages as depicted. No redesign, no text,
no borders, no added items. Separate individual objects cleanly for game sprite
slicing. Keep all detached fragments belonging to each object, no floor.
Output a transparent PNG sprite sheet, 5 equal columns and 2 equal rows.

Названия рядов в художественном запросе описывают содержимое изображения;
игровые роли рядов уточнены пользователем и перечислены выше.
