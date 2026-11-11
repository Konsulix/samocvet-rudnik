# Где уходит время сборки камня

Профиль по функциям GDScript без редактора: копия `godot/scripts` с таймером на каждой функции верхнего уровня.
Рабочее дерево не трогается (ассеты, шейдеры и `.godot` подключаются ссылками-junction).

1. Копия: папка `P` со своими `scripts/`, `tests/`, `project.godot`, `icon.png*`; `assets data shaders scenes .godot` —
   `cmd //c mklink //J <P>\<имя> <godot>\<имя>`. Удалять ссылки только `cmd /c rmdir`, не `rm -rf` (сотрёт оригинал).
2. В `project.godot` копии первой строкой автозагрузок: `Prof="*res://scripts/prof.gd"`; `prof.gd` → `scripts/`,
   `build_prof.gd/.tscn` → `tests/`.
3. `python instr.py <P>/scripts/specimen/*.gd` — обёртки с таймером (функции с `await` и внутренних классов не трогает).
4. `"$G" --path <P> res://tests/build_prof.tscn -- set=beasts|skulls|finds n=N [reps=2] [each] [top=40]` — таблица
   «своё время / вызовы / с вложенными». `noprof` — без таймеров (в копии без шага 3 — настоящие времена),
   `thread` — сборка в потоке (кадров ожидания заметно больше, чем мс/16 → ждём видеочип), `hash` — md5 всей геометрии
   камня (сверка «до/после» правки).

`patch_opt.py <корень проекта> [fern surf edges subdiv free]` — ускорения, найденные 11.11 (геометрия бит-в-бит та же).
