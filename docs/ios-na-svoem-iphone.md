# Сборка и установка на свой iPhone без Mac

Работает с Windows и бесплатным Apple ID. Платный аккаунт разработчика и TestFlight не нужны.

## Как устроено

1. Код и сцены — в `godot/`, открываются в Godot 4.7.2 на Windows.
2. Каждый push в `godot/**` запускает `.github/workflows/ios.yml` на облачном Mac GitHub:
   Godot экспортирует Xcode-проект, `xcodebuild` собирает приложение **без подписи**, получается `samocvet-rudnik.ipa`.
   Для публичного репозитория минуты macOS бесплатные. Сборка идёт ~8 минут, ещё сколько-то в очереди.
3. `.ipa` берётся из артефактов запуска (Actions → нужный запуск → Artifacts → `samocvet-rudnik-ipa`).
4. **iloader** подписывает `.ipa` своим Apple ID и ставит на iPhone по кабелю.

## Установка (iloader)

- Нужен установленный iTunes (классический, с сайта Apple) — ради драйверов.
- iloader: только с github.com/nab138/iloader/releases (на 21.10.2026 рабочая версия 2.3.10).
- Войти Apple ID → выбрать iPhone → Import IPA → указать `.ipa`.
- На iPhone один раз: Settings → General → VPN & Device Management → своё «iPhone Developer» → Trust. Затем Developer Mode, если попросит.

## Ограничения бесплатного Apple ID

- Подпись живёт **7 дней** — потом переустановить тем же способом.
- Не больше 3 таких приложений одновременно.
- Нет покупок внутри приложения, пушей, iCloud.

## Грабли, на которые уже наступили

- **Без иконки Godot не экспортирует iOS** («Invalid icon (icons/settings_58x58)»). Иконка — `godot/icon.png` (рисуется `godot/tools/make_icon.py`), прописана в `project.godot` и в пресете.
- **Sideloadly: «Login failed (-80046): This action cannot be completed at this time».** С 12–13.10.2026 Apple поменяла вход, и бесплатные установщики сломались. iloader 2.3.7+ это обходит. Не долбить вход много раз подряд — Apple временно блокирует. Код 2FA брать с доверенного устройства, SMS в этих инструментах сломаны.
- **iloader: «device does not have pairing file».** Windows не смогла обновить файл сопряжения (в `C:\ProgramData\Apple\Lockdown` оставался старый `<UDID>.plist` и висел `.plist.tmp`). Лечится в PowerShell от администратора с отключённым телефоном:
  `Stop-Service "Apple Mobile Device Service"; Remove-Item "$env:ProgramData\Apple\Lockdown\<UDID>.plist*" -Force; Start-Service "Apple Mobile Device Service"`,
  затем подключить iPhone и снова нажать «Доверять».
- **iloader: «error sending request for url (…ani.sidestore.io…)».** Разовый сбой перегруженного anisette-сервера — повторить или сменить сервер в настройках.
- **Два аккаунта GitHub на компьютере.** В этой папке git настроен локально на Konsulix (`user.name`, `credential.https://github.com.username`), глобальные рабочие настройки не тронуты.
