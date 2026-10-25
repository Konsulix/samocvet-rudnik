# Боссы: ТЗ для генератора картинок

Решено 25.10: боссы — пиксельная книжная иллюстрация в духе Inscryption, поле и фишки остаются 3D.
Картинку делает генератор, дальше её обрабатывает наш конвейер. Это ТЗ описывает, что просить у генератора,
чтобы конвейер сработал без ручной правки.

## 1. Конвейер (что будет с картинкой)
1. **Генератор** → босс на однотонном фоне, без интерфейса, плюс варианты «тот же кадр, изменено одно» (п. 4).
2. **Вырезка:** фон по цвету-ключу → прозрачность; части для анимации — разницей между вариантами.
3. **Сетка 1 pt, преобладающий цвет** (`art/boss/cellmode.py`): картинка приводится к экранному размеру, каждый
   пиксель = самый частый цвет клетки. Палитра рудника ~58 цветов + 6 ярких акцентов (глаза, свечи, лава).
4. **Godot:** фильтр «ближайший», целый масштаб (1 pt = 3×3 на iPhone). Эффекты — на палитре: бег цветов
   (лава, свечение), перекраска по фазам, вспышка от удара, свет босса на рамке поля.

## 1а. Разметка экрана боя (утверждается; макет — `art/boss/layout.py` → `art/boss/layout_*.png`)
Экран 390×844 pt (плюс вырез iPhone сверху). Интерфейс — тёмный сланец с окантовкой из металла рудника
(Old Adit — золото, Copper Mountain — медь, Fire Horizon — обсидиан/раскалённый край).
- **Верхняя строка** (y 10–58): крестик · плашка босса в две строки (крупно имя, мелко «прозвище · глубина»,
  потом сюда же «попытка N») · ходы. Селектора фишек и плашки цели уровня нет.
- **Сцена босса:** во всю ширину, y ~58–318 → **390×260 pt, кадр 3:2**. Правый верхний угол (~120×64 pt) —
  облачко намерения: значок действия, подпись в одно слово, отсчёт ходов. Реплика на старте — то же облачко,
  ненадолго раскрытое в текст.
- **Здоровье — на верхней планке рамки поля**, во всю её ширину, засечки фаз на 66% и 33%.
- **Рамка поля — своя у каждого босса.** Пробы: порода `poloz` в `board_kit.py` (3D, тонко и скромно) и
  сгенерированная пиксельная рамка-кольца (`src/poloz/frame.png`) — она сливается с телом босса, выглядит сильнее.
  У сгенерированной рамки толщина ~7% выходит за края экрана — либо рамку тоньше (~4%), либо поле на 5% меньше.
- Бустеры внизу — пока старые, перевести в тот же сланец.

## 2. Технические требования (для всех боссов)
- **Размер босса.** Горизонтальный кадр **3:2, 1536×1024**. Голова — в левой-центральной части (~40% ширины,
  ~40% высоты), смотрит вправо-вниз; **правая верхняя четверть пустая** (облачко намерения); кольца/тело
  во всю ширину по нижнему краю; верхнего края ничего не касается. На экране — 390×260 pt, клетка сетки ≈4 px исходника.
- **Фон — сплошной ярко-пурпурный `#FF00FF`**, без теней, дымки и свечения на фоне. Если генератор умеет прозрачный
  PNG — лучше прозрачный. Свечение, искры, дым вокруг — не рисовать, их добавим сами.
- **Ничего, кроме босса:** никакого текста, плашек, рамок, полоски здоровья, игрового поля, фишек, подписи, водяного знака.
- **Нижний край — ровный горизонтальный срез** по низу кадра: босс «сидит» на рамке поля. Руки, кольца, лапы
  можно положить на этот край — это связь с полем.
- **Поза:** корпус слева, голова/взгляд повёрнуты **вправо и чуть вниз** — к облачку намерения и на поле.
- **Свет сверху-слева** (как у фишек), тёплый контровой от свечей; тени глубокие, почти чёрные.
- **Рисунок:** чёткие тёмные контуры, плоские заливки с 2–3 ступенями тени, крупные читаемые формы. Без размытия,
  мягких градиентов, фотореализма, 3D-рендера. Мелкая фактура (чешуя, трещины) — крупнее, чем кажется нужным:
  на экране она должна читаться при ширине ~260 pt.
- **Цвета не спорят с фишками:** у фишек чистые красный, синий, зелёный, жёлтый, фиолетовый. Босс —
  приглушённый, тёмный; насыщенный только акцент (глаз, лава, кристаллы короны), и он один на босса.
- **Один и тот же «кадр» для всех вариантов** (п. 4): та же поза, масштаб, положение в кадре. Делать вариант
  через редактирование исходной картинки («измени только …»), а не новой генерацией.

## 3. Палитры рудников
| Рудник | Основные цвета | Акцент | Нельзя |
|---|---|---|---|
| Old Adit (Полоз) | бурый и серый камень, тёмная охра, белый кварц, янтарь свечей | золото: жилы в камне, чешуйки, **золотой глаз** | зелень (это цвет Хозяйки) |
| Copper Mountain (Хозяйка) | малахит (тёмно- и светло-зелёный с полосами), медь, тёмная бронза | изумрудные кристаллы короны, зелёные глаза | красный, оранжевый |
| Fire Horizon (Сердце вулкана) | чёрный базальт, тёмно-бордовый, пепел | лава оранжево-жёлтая, жёлтая сера, **один глаз** | зелёный, синий |

## 4. Что сдать по каждому боссу
Все файлы — один кадр, отличаются только указанным. Кладём в `art/boss/src/<boss>/`.

| Файл | Что | Зачем |
|---|---|---|
| `base.png` | основная поза, спокоен | основа |
| `blink.png` | глаза закрыты | моргание |
| `hurt.png` | вздрогнул, глаза зажмурены, голова чуть назад | реакция на большое комбо |
| `cast.png` | пасть/рот открыты, взгляд на поле | босс действует (раз в 3 хода) |
| `phase3.png` | ярость: трещины светятся, взгляд злой | последняя фаза |
| `bg.png` | пещера рудника без персонажа, 2:3 (1024×1536), середина 35–90% высоты спокойная и тёмная (там поле), детали по краям | фон экрана боя |
| `frame.png` | рамка поля из тела/материала босса, 8:9, проём и углы `#FF00FF`, толщина ~4% | своя рамка |

Свои детали у каждого — в п. 5 («Части»). Если генератор не держит кадр между вариантами — сдать то, что
получилось; части тогда вырежу по маске, а не разницей.

## 5. Промпты
Писать по-английски. Общий хвост — в конец каждого промпта:

> *Style:* dark fairy-tale book illustration in pixel-art style, inspired by Inscryption; bold dark ink outlines,
> flat colour fills with 2–3 shade steps, chunky readable shapes, crisp hard edges, no blur, no soft gradients;
> gloomy and dark overall, deep near-black shadows, the body mostly in shadow, light only from the upper left as a
> dim warm rim; the brightest thing is the boss' accent. Single character only. LANDSCAPE 3:2 frame, 1536x1024:
> the head in the LEFT-CENTRE (about 40% of the width and height), facing RIGHT and looking down to the bottom-right;
> the body spreads across the whole width along the bottom edge and is cut off flat by it; the TOP-RIGHT quarter
> stays EMPTY background; nothing touches the top edge. Solid flat magenta #FF00FF background, no shadow
> on the background, no glow, no particles. No text, no UI, no frame, no border, no game board, no gems, no watermark.

Для вариантов (редактирование картинки):

> Same image, same character, same pose, same framing and size, same background. Change only: *<что меняется>*.

### Великий Полоз (Old Adit)
По Бажову — огромный змей, хранитель золота. Не голем и не старик.
> A colossal ancient serpent made of brown and grey stone, coiled in heavy rings, the coils look like boulders
> overgrown with patches of dry moss; thin gold veins run through the stone like seams of ore, a few golden scales;
> long whiskers like old tree roots hang from the snout; one glowing **golden** eye; white quartz crystals grow
> from the coils. The head rises on the left half of the frame and turns to the right, looking down; the lowest coil
> lies along the bottom edge. Palette: brown stone, dark ochre, white quartz, amber, gold. No green.

Варианты: blink — *eye closed*; hurt — *head pulled back, eye squeezed shut, stone chips flying off*;
cast — *jaws open wide, the eye blazing gold*; phase3 — *gold veins glowing bright, cracks across the coils, eye furious*.
Части: голова, глаз, нижняя челюсть, кольца тела.

### Хозяйка Медной горы (Copper Mountain)
> The Mistress of the Copper Mountain from Ural folk tales: a beautiful stern young woman with dark braided hair,
> pale skin with a faint green tint, a tall crown of emerald crystals, a gown of polished malachite with banded green
> stripes and copper trim, a malachite necklace; she leans forward with her forearms resting on the bottom edge of
> the frame, as if leaning on a stone ledge, head turned to the right, looking down. Palette: malachite greens,
> copper, dark bronze, emerald accents. No red or orange.

Варианты: blink — *eyes closed*; hurt — *flinches, eyes shut, head turned away*; cast — *raises one hand, a green
glow in the palm, eyes glowing green*; phase3 — *cold furious stare, crown crystals glowing, malachite cracks on
her gown*. Дополнительно (отдельной картинкой, тот же стиль): малахитовая ящерица 1:1, вид сверху — бегает по полю.
Части: голова, глаза, руки на краю, корона.

### Сердце вулкана (Fire Horizon)
> The Heart of the Volcano: a living mass of black basalt shards and cooled lava crust, piled into a rough dome,
> with cracks of molten orange-yellow lava between the plates; in the centre a single huge eye of molten lava with a
> dark slit pupil, framed by a ring of glowing rock; small yellow sulfur crystals on the edges. The mass rests on
> the bottom edge, the eye looks to the right and down. Palette: black basalt, dark crimson, ash grey, molten orange,
> yellow sulfur. No green, no blue.

Варианты: blink — *eye closed by basalt eyelid plates*; hurt — *plates shift apart, eye squeezed, lava drips*;
cast — *plates open wider, eye blazing white-yellow*; phase3 — *all cracks glowing white-hot, plates floating apart*.
Части: панцирь, глаз (радужка отдельно), трещины (маску вытащу по цвету лавы сам).

## 6. Как проверяю сданное
1. Фон удаляется по `#FF00FF` чисто (нет пурпурной каймы).
2. Варианты совпадают с `base` по кадру — разница только в нужной части.
3. После сетки 1 pt силуэт и глаз читаются на снимке уровня 390×844 рядом с фишками.
4. Цвета босса не сливаются ни с одним цветом фишек.
