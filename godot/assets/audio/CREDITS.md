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
