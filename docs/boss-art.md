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
- **Низ тела уходит в тень** (решено 26.10): нижние ~20% кадра — тело темнеет почти до чёрного, как будто тонет
  в темноте пещеры; яркое (лицо, руки на краю, акцент) — выше. Над вырезанным углом поля планки нет, и срез там
  виден: игра растворяет низ спрайта в темноту дизерингом по столбцам без планки (`boss_sprite.gdshader`:
  `exposed`/`sink_band`, `LevelBoss._expose`, полоса 22 pt) — уже тёмный низ делает этот переход незаметным.
  В промпт: *the lowest fifth of the body sinks into deep near-black shadow, as if into the dark of the cave.*
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
Решено 26.10: **полуящерица** — превращение уже начато (лицо девичье, строгое; чешуя на шее, скулах, руках),
при поражении **каменеет** (малахитовая статуя, трещины, корона гаснет). Рамка поля — малахитовые плиты в медной
окантовке, её коса свисает через край по боковой планке, по рамке бегают ящерки (кадры анимации, как хвост Полоза).
По Бажову: невысокая, коса с лентами «будто медная проволока», платье — шёлковый малахит, свита из ящерок.
26.10, вторая попытка: первые пробы вышли «милой фэнтези-девушкой» — дух Inscryption терялся. Нужна красота,
в которой чувствуется «что-то не так»: восковая серо-зелёная кожа с малахитовыми прожилками, глаза чуть больше и
шире посажены, без зрачков, немигающий взгляд, улыбка не доходит до глаз, слишком длинные пальцы; палитра грязная
и приглушённая (мутный малахит, ярь-медянка, чернёная бронза), полутьма на пол-лица, яркие только глаза и 2–3
кристалла. Полный промпт фазы 1 — ниже, правки фаз 2–3 — в `chain.sh` из сессии (идеи: улыбка слишком широкая →
звериная морда, от женщины остаются прядь и корона). Пробы: `src/mistress/a_p1..3`, `b_p1..3`.
> Character: The Mistress of the Copper Mountain from Bazhov's Ural tales - a mountain spirit wearing the shape of
> a beautiful woman, and the shape is not quite right. Beautiful at first glance, deeply unsettling at the second:
> waxy pale skin with a cold grey-green tint, like polished stone, with thin dark malachite veins under the skin at
> the temples and the throat; the eyes a little too large and set a little too far apart, flat glowing emerald with
> no pupils and no whites, an unblinking stare; a faint thin smile that does not reach the eyes; sunken cheeks,
> a long thin neck; the fingers too long, dark green claw-like nails; patches of lizard scales on the neck and hands.
> Palette: muted, dirty and desaturated like Inscryption... Style: grim and grimy; heavy black ink outlines, coarse
> dithered shading... no glossy fantasy-art rendering; not cute, not glamorous, no anime.
Фаза 3 «ящерица» выходила милой — нужен контраст «красота → уродство»: правка от p2 «hideous monster, not a cute
reptile»: костлявая голова варана, пасть до ушей, кривые игольчатые зубы, глаза разные и запавшие, чешуя рваная,
кожа лопнула и в ранах сырой малахит, волосы облезли, корона набекрень, лапы-крючья (`a_p3u`, `b_p3u`). Морда не
должна заходить под облачко (правее ~55% ширины в верхней половине).
На сетке тёмная Хозяйка сливается с зелёной пещерой: фон делать темнее и не такой зелёный (или контровой свет).

**С каждой фазой (полем боя) она всё больше ящерица** — у каждой фазы своя основа и свои эмоции, основа следующей
делается правкой предыдущей (кадр сохраняется), при смене поля — вскрик и наплыв на новую основу:
**Утверждено 26.10** (цепочка a; остальные пробы в той же папке — черновики):
фаза 1 — живая красивая женщина без чешуи, человеческие глаза и руки; странное только в мелочах: неподвижный
взгляд, малахитовая жилка у виска, ящерка в волосах (`src/mistress/base.png` = `a_p1h`, правка `a_p1`);
фаза 2 — восковая серо-зелёная кожа в чешуе, улыбка слишком широкая, глаза без зрачков, когти (`p2_base.png` = `a_p2`);
фаза 3 — чудовище: облезлая голова варана, пасть настежь со слюной, корона набекрень, лапы-крючья, поза перед
броском (`p3_base.png` = `a_p3v5`, правка `a_p2`; дорабатывать не надо).
Эмоции сделаны 26.10 правкой основ (`src/mistress/`, лист — `art/boss/mistress_moods.png`): фаза 1 — `blink`,
`hurt`, `cast`; фаза 2 — `p2_*`; фаза 3 — `p3_blink/hurt/cast/scream/fall`, `p3_defeated` (правка `p3_fall`).
cast: ладонь с зелёным огнём — **низко перед грудью** (30–55% ширины, ниже 55% высоты), иначе её закрывает облачко.
Фон и рамка (26.10, пробы): `bg_a/bg_b` — тёмный малахитовый зал, приглушённый почти до чёрно-бирюзового (на нём
она читается), свечи в нишах, каменный цветок слева внизу; `frame_a/frame_b` — бруски малахита в чернёной меди
с заклёпками, коса по левому бруску, ящерки на рамке; `lizard.png` — ящерка сверху (для бега по рамке/полю).
Решено 26.10: **фон — `bg_a`** (= `src/mistress/bg.png`); сгенерированная рамка отклонена (грубая растянутая сборка),
**косы на рамке нет** (не подстроить под углы) — только малахит с медью, ящерки бегают по ней спрайтами.
Рамка — Blender, целиком по контуру каждого поля, как змей Полоза: `prototype/tools/blender/malachite_kit.py --
<out> boss 168 32 <area>` → `stage<N>.png/.json` (брусок малахита со скосами, полосы кольцами в мировых координатах,
медь: стяжки вразнобой — шаг, ширина, наклон, иногда парой; на внешних углах наугад медная пластина или неровный
малахитовый блок; брусок гуляет по ширине/высоте, внешний край в сколах; на бруске полосы идут **вдоль** него
(UV: длина × поперёк, изгиб шумом по длине — как в сгенерированных рамках), на угловых блоках — кольцами; `tail_frames: 0`). Проба на полях
Полоза (у Хозяйки своих полей ещё нет) — `art/boss/mistress_frame/`, макет — `art/boss/mistress_screen_mock2.png`.
26.10, вариант 2 — **рисованный набор деталей**: GPT нарисовал лист `src/mistress/frame_kit.png` (4 бруска с рваным
внешним краем, 3 скобы, 4 внешних и 4 внутренних угла, пурпурный фон). `art/boss/mistress_frame.py <scratch> <font>
<out> [area]` режет лист, собирает рамку по контуру каждого поля (бруски кусками, стыки под скобами, скобы вразнобой,
от угловых деталей берутся только медные накладки — их перемычки с чернильными концами давали шов; бруски сходятся
под накладкой; брусок 24 pt; лист приглушён (`TONE`: насыщенность ×0,72, яркость ×0,8) под тон сцены) и сразу
приводит к сетке 1 pt с обводкой → `kit_stage<N>.png/.json`.
Макет — `art/boss/mistress_screen_mock3.png`.
Ниже — первый промпт (вышел «милым», не использовать как есть).
Эмоции: фазы 1–2 — blink, hurt, cast; фаза 3 — blink, hurt, cast, scream, fall (каменеет), defeated (статуя).
Правки картинок — `art/boss/gen_edit.sh` (общий для всех боссов). На экране руки с ящеркой не должны уходить
за верхнюю планку рамки: у Хозяйки спрайт ниже утапливать нельзя, как Полоза (нужно смещение по боссу).
> The Mistress of the Copper Mountain from Bazhov's Ural tales, half-turned into a lizard: a stern, uncanny young
> woman with a cold beautiful face, pale skin with a green tint, emerald eyes with no pupils; small green lizard
> scales spread over her neck, cheekbones, the backs of her hands and forearms, her fingers end in dark claws;
> a long heavy dark braid woven with thin copper ribbons that look like copper wire, the braid hangs over the bottom
> edge; a tall crown of emerald crystals; a gown of polished malachite with banded green stripes and copper trim.
> She leans forward with her forearms resting on the bottom edge of the frame as on a stone ledge, head turned to
> the right, looking down; a small malachite lizard sits on her hand. Palette: malachite greens, copper, dark bronze,
> emerald accents. No red or orange.

Варианты: blink — *eyes closed*; hurt — *flinches, eyes shut, head turned away*; cast — *raises one clawed hand,
a green glow in the palm, eyes glowing green*; phase3 — *cold furious stare, scales spread further over her face,
crown crystals glowing, malachite cracks on her gown*; scream — *hisses with mouth open, forked tongue*;
fall — *half turned to stone, cracks spread from the hands*; defeated — *whole figure a dull malachite statue,
crown dark*. Отдельно (тот же стиль): малахитовая ящерица 1:1, вид сверху — бегает по полю и по рамке.
Части: голова, глаза, руки на краю, корона, коса.

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
