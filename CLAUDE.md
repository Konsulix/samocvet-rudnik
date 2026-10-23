# Самоцветный рудник — памятка для новой сессии

Мобильная три-в-ряд с геологией. Живая версия — `godot/` (Godot 4.7.2, мобильный рендер),
прототип — `prototype/web/`. Отвечать пользователю по-русски; сама игра на английском (шрифт Nunito Sans).

## Как работать
- Godot: `C:\Users\Максим\Desktop\godot\Godot_v4.7.2-stable_win64_console.exe`.
  Снимок экрана: `"$G" --path godot --resolution 390x844 -- level=8 shot=user://lv.png after=3`
  (файл в `%APPDATA%\Godot\app_userdata\Gemcore\`). Другие ключи: `screen=depot|museum`,
  `reveal=<seed> [legend=heart]`, `win`, `autoplay=N`, `fill=14`, `noglow`.
- Витрина минералов: `res://tests/spec_gallery.tscn -- set=N still px=330`.
- После добавления новых class_name / ассетов: `"$G" --headless --path godot --import`.
- Строгая типизация GDScript: значения из Dictionary/Array — с явным типом.
- Blender 5.2: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`, скрипты в `prototype/tools/blender/`
  (запуск `-b -P script.py -- args`, пути передавать абсолютными).
- Экономить: минимум промежуточных скриншотов/рендеров, правки пачкой.

## Git / сборка под iPhone
- Репозиторий Konsulix/samocvet-rudnik (личный аккаунт; глобальный git-конфиг рабочий — не трогать).
- push в main → GitHub Actions собирает `.ipa` (артефакт `samocvet-rudnik-ipa`, ~10 мин).
  Токен для API: `printf "protocol=https\nhost=github.com\nusername=Konsulix\n\n" | git credential fill`.
  Скачивать артефакт: взять redirect_url с `/actions/artifacts/<id>/zip`, качать `curl -C -` (рвётся).
- Установка на телефон — через iloader пользователем. Пароли никогда не вводить.

## Что сделано (стиль)
- Генератор минералов `godot/scripts/specimen/` — главное достижение, стиль утверждён, НЕ трогать без запроса:
  гены образца (`spec_genome.gd`), стекло/порода/шейдеры (`shaders/spec.gdshaderinc`), мох и растения,
  наросты, легендарные живые эффекты (`spec_legend.gd`, молния `spec_bolt.gd`).
- Поле уровня: спрайты из Blender (`assets/board/`, `gem_sprites.py`, `board_sprites.py`), мраморный лоток,
  фон `assets/ui/level_bg.png` (`level_bg.py`), интерфейс «мрамор + сланец» (`UI.marble/slate/marble_button`).

## Что дальше
- Перевести в мраморный стиль: окна (победа/поражение/раскрытие находки — `autoload/overlay.gd`, `screens/reveal.gd`),
  главный экран (`screens/home.gd`, `mine_scene.gd`), депо, музей; эффекты взрывов (`game/fx_layer.gd`).
- Старое (можно удалять со временем): `board3d.gd`, `gem_cut.gd`, `piece_form.gd`, `board_gem/board_piece.gdshader`,
  `gallery_bg.gd`, `GemArt` для фишек.
