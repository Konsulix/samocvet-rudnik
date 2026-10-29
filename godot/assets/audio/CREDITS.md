# Музыка и звуки

Всё — под лицензией CC0 (общественное достояние): можно использовать без ограничений и без указания авторства.

## Музыка (`music/`)

MintoDog, серия «For Puzzle Game», [OpenGameArt](https://opengameart.org/content/for-puzzle-game-mintodogs-music):

- `home.ogg` — [Cozy Puzzle Stage Select](https://opengameart.org/content/cozy-puzzle-stage-select) (главный экран, депо, музей)
- `level1.ogg` — [Cozy Puzzle In-Game 1](https://opengameart.org/content/cozy-puzzle-in-game-1) (уровни, по очереди со вторым)
- `level2.ogg` — [Cozy Puzzle In-Game 2](https://opengameart.org/content/cozy-puzzle-in-game-2)

Все три зациклены (`loop` ставится в `Sfx.music`).

## Звуки (`sfx/`)

[Kenney](https://kenney.nl), пакеты [Impact Sounds](https://kenney.nl/assets/impact-sounds),
[Interface Sounds](https://kenney.nl/assets/interface-sounds), [Casino Audio](https://kenney.nl/assets/casino-audio)
и [Music Jingles](https://kenney.nl/assets/music-jingles). Какой звук на что — таблица `SAMPLES` в `scripts/autoload/sfx.gd`.
Ракета, молния и газ по-прежнему синтезируются, а под взрывом синтезированный удар лежит вторым слоем.

- `music/boss_poloz.mp3` — «Crystal Mine Serpent», тема боя с Великим Полозом; сделана владельцем проекта.
- `music/boss_mistress.mp3` — «The Green Stone», тема боя с Хозяйкой Медной горы (женский вокал); сделана владельцем проекта.
- `music/home_adit.ogg` — «Deep Mine Drones», главный экран рудника 1 (Old Adit); сделана владельцем проекта (Suno).
  Зациклена `prototype/tools/music_loop.py`: вступление один раз, петля с 11,7 с (`Sfx.LOOP_AT`), концовка срезана.
- `music/home_copper.ogg` — «Spirit of the Deep», главный экран рудника 2 (Copper Mountain); сделана владельцем проекта (Suno).
  Петля с 19,3 с, так же.

## Звуки рудника 2 и Хозяйки (`sfx/`, CC0, OpenGameArt)

- `bfh1_*` — rubberduck, [75 CC0 breaking / falling / hit sfx](https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx):
  корка, почка, обвал.
- `bug_*`, `breath_02`, `weird_*`, `roar_*` — rubberduck, [80 CC0 creature SFX #2](https://opengameart.org/content/80-cc0-creture-sfx-2):
  ящерки, шипение Хозяйки, смена фазы.
- `magical_*` — JaggedStone, [Magic Spell SFX](https://opengameart.org/content/magic-spell-sfx): цветение каменного цветка.

## Звуки главного экрана (`amb/`, CC0, OpenGameArt)

Нарезаны и переведены в моно `prototype/tools/amb_kit.py`; глушение и эхо — шина `Amb` в игре (`Sfx.amb_bus`).

- `cave.ogg` — JaggedStone, [Loopable Dungeon Ambience](https://opengameart.org/content/loopable-dungeon-ambience) (первые 60 с, шов сведён).
- `crickets.ogg` — Wolfgang_ (в примечании — Ted Kerr), [Crickets Ambient Noise - loopable](https://opengameart.org/content/crickets-ambient-noise-loopable).
- `winch_0/1.ogg` — bart, [Chain winch sounds](https://opengameart.org/content/chain-winch-sounds).
- `cart_0/1.ogg` — синтезированы (гул, стук на стыках рельсов, скрип) тем же скриптом.
- Кирка — те же Kenney `impactMining_*`, что и на поле.

## Кнопки, окна, резонатор, газ (`sfx/`, CC0) — вместо синтезированных и «цифровых» щелчков

Нарезаны `prototype/tools/sfx_cut.py`.

- `bookPlace1..3`, `bookFlip1` — Kenney, [RPG Audio / 50 RPG sound effects](https://opengameart.org/content/50-rpg-sound-effects): кнопки и окна.
- `bowl_ping` — Joseph Sardin, [BigSoundBank #1109 «Tibetan bowl singing»](https://bigsoundbank.com/tibetan-bowl-singing-s1109.html): резонатор (3 с установившегося звона).
- `gas_0..2` — бульканье (rubberduck, [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx);
  BMacZero, [Bubble Sound Effects](https://opengameart.org/content/bubble-sound-effects)) поверх приглушённого шипения
  (bart, [Steam release sounds](https://opengameart.org/content/steam-release-sounds)).
- `win_geode`, `lose_rockfall` — конец уровня вместо саксофонных джинглов Kenney, собраны в `sfx_cut.py` из звуков игры:
  победа — раскалывается жеода (`bfh1_rock_breaking_03`, `impactGlass_light_*` по нарастающей, `magical_5`, `bowl_ping` выше),
  поражение — обвал (`bfh1_rock_falling_07/04`, `bowl_ping` на октаву ниже и глуше, `impactBell_heavy_000` вдвое медленнее).
  Неудачный ход `bad` — те же камни, что при перестановке, ниже и тише, плюс мягкий синтезированный удар (вместо `error_006`).
- `reveal_0..4` — открытие находки вместо саксофонных `jingles_SAX10/16`: звоны `impactGlass_light_*` вверх по пентатонике
  (чем реже, тем больше), `magical_5`, высокий `bowl_ping`, у легендарной — медленный `impactBell_heavy_000`. `build_knock` —
  стройка вместо цифрового `confirmation_002`: доска и два удара молотка (`impactPlank_medium_000`) + латунная защёлка
  `metalLatch` (Kenney RPG Audio). Всё собрано в `sfx_cut.py`.

## Звуки экрана рудника 2 Copper Mountain (`amb/copper/`, CC0)

Собраны `prototype/tools/amb_copper.py`, играются `CopperSounds` через приглушённую шину `Amb`.

- `falls` — водопад у мельницы: ручей rubberduck (`loop_water_02`, [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx)) + синтезированный гул падающей воды.
- `furnace` — домна: PagDev, [Fireplace sound loop](https://opengameart.org/content/fireplace-sound-loop) + синтезированный низкий гул пламени.
- `chuff_0..2` — пар машины: bart, [Steam release sounds](https://opengameart.org/content/steam-release-sounds).
- `creak_0..2`, `wings_0..1`, `rivet_0..2` — Kenney RPG Audio (`creak1..3` ниже, `cloth1/3` быстрее — взмахи крыльев, `metalPot1..3` — клёпка).
- `crow_0..2` — zeroisnotnull, [crow caw](https://opengameart.org/content/crow-caw), три высоты.
- `meow` — IgnasD, [Meow](https://opengameart.org/content/meow).
- `bell` — колокол башни: `sfx/impactBell_heavy_000` медленнее и глуше.
- `coo_0..2` — голуби: mary905, [Dove cooing](https://commons.wikimedia.org/wiki/File:Dove_cooing.ogg) (Wikimedia Commons, общественное достояние), три фразы.
- `neigh_0..2`, `snort_0..1`, `hoof_0..1`, `wings_2` — Joseph Sardin, BigSoundBank (CC0): ржание #1/#3/#5
  ([#0284](https://bigsoundbank.com/neighing-of-a-horse-1-s0284.html), [#0863](https://bigsoundbank.com/horse-neighing-3-s0863.html), [#1542](https://bigsoundbank.com/horse-neighing-5-s1542.html)),
  дыхание #3/#4 ([#0287](https://bigsoundbank.com/breath-horse-3-s0287.html), [#1543](https://bigsoundbank.com/breath-horse-4-s1543.html)),
  копыта ([#0289](https://bigsoundbank.com/horses-s0289.html)), взлёт голубя ([#0840](https://bigsoundbank.com/flight-of-a-pigeon-s0840.html)).

## Звуки экрана рудника 3 Whalebone Cove — записи (`amb/sea/`)

Нарезаны `prototype/tools/amb_sea_rec.py` (заменили синтезированные прибой, удары волн и чаек; гул и хлюпанье Кракена — синтез `amb_sea.py`).

- `surf`, `crash_0..2` — Joseph Sardin, BigSoundBank (CC0): [Sea: Waves #0266](https://bigsoundbank.com/sea-waves-s0266.html), волны о скалу «Cliff #1» #2570.
- `gull_0..4` — [Gull 1](https://commons.wikimedia.org/wiki/File:Gull_1.ogg) (Wikimedia Commons, общественное достояние); `gull_5..6` — дальние, из [Gulls on the Harbor #2573](https://bigsoundbank.com/detail-2573-gulls-on-the-harbor.html) (CC0).
- `horn` — туманный горн маяка: [Original foghorn at East Brother Island Lighthouse](https://commons.wikimedia.org/wiki/File:Original_foghorn_at_East_Brother_Island_Lighthouse.ogg) (CC0).
- `lap` — лодка у причала: [Boat by a wharf 3](https://commons.wikimedia.org/wiki/File:Boat_by_a_wharf_3.ogg) (общественное достояние).
- `under` — море в разрезе: те же волны глухо + `loop_bubbles_02` rubberduck (CC0); `bubble_0..2` — пузыри водолаза (rubberduck `bubble_01..03`).
- `tryworks` — салотопня: `amb/copper/furnace` + `loop_bubbles_1` (rubberduck).
