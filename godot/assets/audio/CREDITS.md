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
