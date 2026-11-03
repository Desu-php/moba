# Anime Battlegrounds — Naruto MOBA для ПК

Функциональная база: интеграция **49d0a6b** от 2 ноября 2026; текущий срез добавляет пробуждение спящего союзника через M1. Клавиатура и мышь; desktop resizing поддерживается, mobile/touch не входит в продукт. CI сообщил **0 checks**, это не CI PASS.

MOBA 5×5 от третьего лица: Альянс шиноби против Акацуки, три линии, башни, трон, волны миньонов, обычный лес, экономика, предметы, XP и возрождение. Production требует по пять назначенных игроков на сторону; Studio имеет явное исключение 1×1 для небольших тестовых сцен. После уничтожения трона матч остаётся в Finished: бой, волны и способности прекращаются, автоматического следующего раунда нет. Новый матч требует нового сервера.

Всем назначается Наруто (OrangeNinja). M1 — повторяемая направленная ближняя атака click/hold по одной цели, без комбо; скорость зависит от характеристик и ограничена2,5 атаками/с. Союзный урон отключён. Верхний HUD содержит по пять портретов, счёт и время; нижняя консоль — способности, уровень, HP/MP, предметы и золото.


Спящего союзника можно разбудить направленным M1 в ближнем бою: союзный HP не уменьшается, этот взмах не расходует Расенган и не поражает другую цель. Подробности: [ALLY-SLEEP-WAKE](docs/ALLY-SLEEP-WAKE.md).

## Пять линий Наруто

Ранги изучаются последовательно за очки: **Ctrl+1–5** или кнопка **+**; **C** показывает характеристики. Cap30, STR/AGI/INT растут с уровнем. Дополнительные действия принадлежат пяти линиям, а не образуют новые линии обучения.

| Линия / уровни | Реализованный bounded runtime | Границы |
| --- | --- | --- |
| **1 / Q — Расенган I–III**,4/11/18 | Helper/right-hand orb → явная атака → задержанный урон от текущих STR/уровня и двухэтапный push. Z выбирает Odama в начальном окне; X — доступный melee Rasenshuriken в следующем | Не все form/ranged-варианты готовы. X при активном KCM отменяет KCM |
| **2 — клоны I–IV**,1/5/9/13 | Self3/4/5/7, допустимая massIV30; жизнь20с, .30 outgoing/20 incoming, follow/assist/F, bounded pathfinding. T выбирает enemy Sleep II+ | Первый unlock и post-200 порядок massIV — политики; поздние point/form-ветки закрыты |
| **3 — Gamakichi, десять рангов**,1/3/…/19 | Early/adult summon, follow/assist/F; G масло, H четыре волны взрослого рубящего канала | Первый unlock, placement/control и cadence канала адаптированы; Nsi4 attack-speed reduction отсутствует |
| **4 — Sage I–III**,6/10/14 | Prep10/7/4с, mana25/CD150; direct restore200/350/500. Right Arrow выбирает meditation, J возвращает текущую ману принадлежащих герою meditation clones | III HP300, I/II armor3/7 provisional; ordinary/KCM clone initial mana0 и group recall — политики |
| **5 — KCM I–III**,13/20/27 | Отдельная чакра, entry200/CD10, drain40/с, X cancel, E dash; III дополнительно требует фактический Hagoromo grant | Retained-stat morph policy и отдельный слой Sage; не native metamorph parity |

Left Arrow с уровня16 переводит200 отдельной чакры в200 обычной маны. **6** вызывает bounded Kurama при уровне21+ и2500 чакры, CD160, effective form30с с отдельной25с release-lock логикой. **V/B** выбирают HY/HZ ground techniques только при фактическом текущем KCM III/Rikudo grant: каждая1800 обычной маны/CD60, собственные счётчики и эффекты. Sharing и three-head остаются domain-only, без игровых действий.

WASD — движение. F выбирает противника для принадлежащих герою боевых призывов. В режиме выбора click задаёт цель, Esc/правая кнопка отменяет; такой click не становится M1. Обучение, cooldown/resource/form gates отражены в HUD. Копирование display-атрибутов не даёт форму.

## Источник и ограничения

[Контракт карты](docs/source/naruto-progression-and-branches-contract.txt) и [актуальный backlog](docs/NARUTO-KIT-BACKLOG.md) различают source-факты и адаптации. Naruto Legend задаёт техники; Dota — структуру MOBA/HUD, Smite — третье лицо. Это не полное соответствие Naruto Legend.

1WC unit=1/16stud, XP/экономика, M1/AGI cadence, retained-stat формы, inherited HP/mana/armor и native status edges — отмеченные Roblox/MVP policies. Эффекты оригинальные процедурные; Warcraft/Valve ассеты и JASS не импортированы. Wind Palm удалена. HU/HV graph статически известен, runtime закрыт; A057 inherited cost остаётся неизвестной, ANso native edges требуют отдельного решения. Sharing/three-head и прочие закрытые варианты не рекламируются как работающие.

Четыре лесных лагеря: aggro14stud, leash30, возврат с лечением, respawn45с при активном матче, награда35Gold/50nearby allied XP. Это настройки MVP, не Naruto Legend parity. Вертикальный лес отложен. Выбор героев, рейтинги, DataStore, полноценный matchmaking и монетизация пока отсутствуют. Полноценной миникарты и beast-model art нет. R15-позы/ауры — адаптация; короткий Studio-прогон не доказывает длительную стабильность или итоговое художественное качество.

## Запуск и проверки

Rojo7.7.1, Luau0.744, luau-lsp1.70.1. Из корня checkout:

```powershell
rojo serve default.project.json
```

Подключите Rojo к собственной QA-сцене, сохраняя пользовательскую сцену. Альтернатива — открыть собранный build/anime-battlegrounds.rbxlx. Для локального матча используйте Server & Clients,2 клиента. Разрушьте три башни, затем открывшийся трон; после результата следующий раунд не начинается.

```powershell
./scripts/check.ps1 -Mode Fast -LuauDirectory '<Luau directory>' -LuauLspDirectory '<luau-lsp directory>' -RojoPath '<rojo.exe>'
./scripts/check.ps1 -Mode Targeted -LuauDirectory '<Luau directory>' -LuauLspDirectory '<luau-lsp directory>' -RojoPath '<rojo.exe>'
./scripts/check.ps1 -Mode Full -LuauDirectory '<Luau directory>' -LuauLspDirectory '<luau-lsp directory>' -RojoPath '<rojo.exe>'
```

[TESTING-FAST](docs/TESTING-FAST.md) объясняет focused suites, fingerprints и свежий PASS/REUSED. Итоговый [MCP QA02.11](docs/MCP-QA-2026-11-02.md) содержит реальные runtime/input/visual результаты и ограничения: final code gate40.31с,195Luau файлов/22сборки. Это evidence своей ревизии/области, не автоматический PASS будущих изменений. [TESTING.md](TESTING.md) остаётся историческим отчётом27.10.

## Устройство проекта

Domain хранит правила рангов, ресурсов, статусов и кастов; services связывают их с Roblox. Сервер проверяет участника, цель, ресурсы, жизнь/epoch и текущий Character. Cleanup не переносит каст на respawn; формы сохраняют рост/предметы, оплаченные cooldowns не сбрасываются reconnect. Публикация коммита в Git не означает публикацию Roblox experience.

Подробности: [обучение](docs/LEARNING-STATS.md), [Sage/meditation](docs/SAGE-MEDITATION.md), [KCM](docs/NarutoKcmGameplay.md), [HY/HZ](docs/NARUTO-RANGED-RUNTIME.md), [лес](docs/JUNGLE.md), [single-match](docs/ROUNDS.md), [M1](docs/BASIC-ATTACK.md), [навигация клонов](docs/CLONE-NAVIGATION.md).
