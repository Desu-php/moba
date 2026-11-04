# Combat UX — камера и способности от третьего лица

Итерация от 4 ноября 2026 года. Изменения продолжают существующие контроллеры,
CombatService, NarutoAbilityService и сервисы призывов. Новая параллельная боевая
система не создаётся. Баланс, изучение навыков и доступность продвинутых веток
по-прежнему определяются существующими серверными правилами.

## Источник и границы переноса

Свежая статическая проверка `Naruto_Legend_1_7a_FIX20_3.w3x` подтвердила SHA256
`8c5750f178a7f1d66a4f04e8d0c585168e51f93c924149858fbb8d731193a5c8`.
В записи Hpal перечислены **пять** веток: A014 Расенган, A04N клоны,
A005 Гамакичи, A09J Sage, A017 KCM. Поэтому KCM и существующие дополнительные
приёмы сохранены; требование четырёх основных клавиш не используется для удаления
пятой ветки. Предыдущие контракты: [NARUTO-LEGEND.md](NARUTO-LEGEND.md),
[исходные ветки и прогрессия](source/naruto-progression-and-branches-contract.txt).

MPQ извлечён только для чтения, карта не запускалась. Материалы находятся **вне
репозитория**, в соседней папке `../map-reference`: `manifest.json`, `war3map.j`,
`war3map.w3a`, `war3map.w3u`, `naruto-objects.json`. Исходная карта не изменена;
её модели, звуки и JASS не включены в игровую сборку. Совпадение статических
данных не доказывает полную совместимость с native-механиками Warcraft.

## Управление на PC

| Действие | Управление |
| --- | --- |
| Движение, прыжок | WASD, Space |
| Камера и направление героя | Мышь, прицел в центре |
| Обычная атака / подготовленный Расенган | ЛКМ |
| Основные техники | 1 Расенган, 2 клоны, 3 Гамакичи, 4 Sage; 5 KCM сохранён |
| Изучение | Ctrl+1–5 или существующие кнопки `+` |
| Атаковать призывами | F: цель под прицелом; если цель недоступна, остаётся выбор с подтверждением ЛКМ |
| Следовать / удерживать позицию | R / Y, общая команда клонам и жабе |
| Масло / рубка взрослой жабы | G / H, прицеливание и подтверждение ЛКМ |
| Быстрый рывок KCM | Удерживать E для предпросмотра, отпустить для применения |
| Отмена прицеливания | ПКМ или Esc |
| Временно освободить курсор | Удерживать Left Alt |

Сохранены Q как альтернативная клавиша Расенгана, Z/X для доступных вариантов,
T для вражеской Sleep-ветки клонов, стрелки и J для существующих действий чакры
и медитации, 6 для Курамы, V/B для разрешённых Rikudo-техник. Контекст X в KCM
по-прежнему означает отмену формы. Клавиши не обходят изучение и условия формы.

## Изменённые компоненты

- `CameraController`, `CameraConfig`, `CombatCameraRules`: камера за плечом,
  немедленное вращение мышью, ограничение наклона, сглаживание следования и
  проверка препятствий сферой. При открытом меню, магазине, характеристиках или
  вводе текста курсор освобождается. Призывы исключены из проверки препятствий
  камеры. При чрезмерном приближении к стене локальная модель временно скрывается.
  Чувствительность, дистанция, высота, плечо и сглаживание задаются конфигурацией
  и ограниченными атрибутами `CombatCamera*`; отдельного меню настроек пока нет.
- `InputController`, `AbilityController`, `AbilityTargeting`: единый выбор цели,
  предпросмотр дальности/области/направления и причины отказа; отмена, release-cast
  для E и очистка состояния при потере фокуса или смене персонажа. Клик выбора
  цели расходуется на способность и не должен одновременно начинать M1.
- `CombatService`, `NarutoAbilityService`, `RasenganState`: серверный обработчик
  подтверждённого контакта расходует подготовленный Расенган ровно один раз.
  Сохраняются подготовка, время удержания, задержанный урон и отталкивание.
- `CloneCommands`, `CloneNavigation`, `NarutoSummonService`, `GamakichiService`:
  Follow/Attack/Hold с проверкой владельца, жизни, раунда и повторных запросов;
  общая навигация жабы и клонов, отмена старого маршрута, контроль коллизий и
  корректная высота появления жабы. Follow/assist остаётся поведением по умолчанию.
- `AbilityHUDController`, `AbilityVFXController`, `VFXController`: цена чакры,
  состояние прицеливания и нехватки ресурса, подсказки команд при живых призывах,
  отдельный эффект контакта Расенгана, подтверждение попадания и короткий импульс
  камеры. Числа урона зависят от фактического серверного DamageService.

## Расенган: осознанная адаптация

В карте обычный A014 стоит 100 чакры, имеет cooldown 60 секунд и подготовку
2 секунды. JASS `46389–46535` создаёт помощника и сферу, затем оставляет
подготовленный удар. Обработчик `48693–48789`, зарегистрированный на
`EVENT_PLAYER_UNIT_ATTACKED` в строке `49107`, начинает контроль через .01 секунды
и наносит урон через следующую секунду.

В Roblox усиление теперь расходуется на допустимый контакт в момент удара M1,
после серверных проверок дистанции, направления, видимости и цели. Простое начало
замаха или удар в пустоту не расходуют сферу. Обычный физический урон этого удара
заменяется усиленным; двойного урона быть не должно. Событие `RasenganContact`
обозначает контакт, а число урона появляется при позднем фактическом списании HP.
Это исправление UX и достоверности попадания; оно не выдаётся за точное
воспроизведение события начала атаки Warcraft. Произвольный новый рывок не добавлен.

## Проверки и текущий статус

Полный доступный прогон `scripts/check.ps1 -Mode Full` завершился успешно:
204 Luau-файла, 39,17 секунды (финальный игровой код и сохранённый стенд). Он включает сборки Rojo, проверки типов и чистые
тесты; добавлены проверки правил камеры и команд/навигации призывов, обновлены
серверные сценарии Расенгана и жабы. Команда и пути инструментов описаны в
[TESTING-FAST.md](TESTING-FAST.md). Повторная проверка требуется после последующих
изменений кода, затрагивающих эти результаты.

Подготовлена отдельная локальная сборка `build/combat-ux-manual.rbxlx` из
production-проекта; открытие в Roblox Studio и режим Edit подтверждены.
В этой итерации проведены реальные проверки Play через Studio MCP на отдельной
площадке с одним игроком. Это не подтверждает полную проверку мультиплеера 5v5.
Изменения не закоммичены и не опубликованы.

## Ручная проверка в Studio

1. Обновить сборку до окончательного кода. Проверить WASD, прыжок, поворот мышью,
   стену за спиной, угол наклона, смерть/respawn и восстановление камеры.
2. Открыть магазин, характеристики, Roblox-меню и чат: курсор свободен, камера
   не вращается при вводе; после закрытия захват восстанавливается. Проверить Alt.
3. Проверить каждую изученную способность, отказ по чакре/cooldown/форме,
   быстрое повторное нажатие, отмену ПКМ/Esc и отсутствие лишней M1 при выборе.
   Проверить E: удержание, отпускание, отмену, потерю фокуса во время удержания.
4. Расенган: подготовка, промах без потери сферы, один контакт и один урон,
   цель за стеной, выход из дистанции до контакта, смерть/stun до и после
   контакта, восстановление управления. Сверить момент эффекта и изменения HP.
5. Клоны и жаба: пройти сквозь группу, сменить цель F, вернуть R, остановить Y;
   обойти препятствие, не застрять при отмене маршрута. Проверить масло, рубку,
   срок жизни, смерть владельца и отсутствие скачков камеры рядом с жабой.
6. Проверить HUD на разных размерах окна: ранги, чакра, cooldown, активный выбор,
   читаемость дополнительных клавиш и отсутствие перекрытия центра.
7. Запустить два клиента: разные владельцы/команды, независимые ресурсы и призывы,
   одинаковый урон и эффекты у наблюдателя. Выполнить актуальные Hero/Gamakichi
   регрессии и доступную проверку матча 5v5; отдельно зафиксировать то, что
   реально не проверено. Проверить Output клиента и сервера на ошибки.

## Фактический прогон 04.11.2026

- Финальный полный автоматический прогон: PASS, 204 файла, 39,17 с; 23 новых проверки правил камеры. Включены сборка, типизация и проверка изоляции сохранённых Setup/Runner тестового стенда. Лог: build/combat-ux-check-release.log.
- Реальный серверный прогон в Play: **43/43, PASS, 9,47 с**. Машиночитаемый исходный результат: [COMBAT-UX-QA.json](COMBAT-UX-QA.json).
- Клавиатурой проверены WASD (за 0,5 с W — около 8 studs), C (свободный курсор/обратный захват), 1/2/3, F/R/Y, предпросмотр H и отмена ПКМ.
- Расенган: клавиша 1 → подготовка → ЛКМ по близкой цели: 476 урона, единичный расход и отталкивание. ЛКМ в пустоту: Holding=true, HP цели не изменился, WalkSpeed=16.
- KCM II: в тестовой сцене выбран ранг II без выдачи дара Хагоромо; 5 включает форму, удержание E показывает валидный предпросмотр, отпускание перемещает героя к z≈-21 и ставит 40-секундный cooldown. Ранг III без дара корректно отклоняется.
- После обнаруженного в первом Play повторного включения CanCollide добавлена отдельная группа SurvivalSummons. Новый призыв: 30 клонов, 1590 частей, **0 частей, способных блокировать владельца**; столкновения summon/summon=false. 43 проверки дополнительно подтвердили неподвижность Hold и возобновление движения Follow у клонов/жабы.
- Камера перед стеной: x=8,402 при ближней поверхности стены x=9; дистанция сокращается, в открытом месте восстанавливается до 11,000 studs. Союзная жаба, закрывающая прицел, получает локальную прозрачность 0,75.
- Наблюдались 22 клиентских DamageFeedback и реальные экземпляры чисел ConfirmedDamage после попаданий призывов. Рубка жабы в серверном прогоне: четыре волны, суммарно 480 урона; масло применяется только после прилёта.
- Прогон также проверил отсутствие повторного списания чакры, переход Rasengan→Odama→Rasenshuriken, отмену stun без возврата cooldown, Sage III и восстановление движения, запрет дружественной цели, очистку жабы/каста/команд при смерти.

Воспроизводимый стенд: собрать `tests/combat-ux.project.json` в `build/combat-ux-tests.rbxlx`, открыть и нажать Play с одним игроком. Во время автоматических проверок не нажимать игровые клавиши. Итог доступен в Workspace.CombatUXRegressionState/CombatUXRegressionReport; последняя проверка намеренно убивает героя. В production эти скрипты не входят.

Ограничения: полноценный матч 5v5 и отдельная двухклиентная регрессия этой ревизии не запускались. HY/HZ и поздние формы не проходили полный ручной бой; их ограничения доступа и механика сохранены. Звук проверен по запуску объекта без ошибок, субъективное звучание не оценивалось. Studio выдаёт прежнее сообщение Asset type mismatch для rbxassetid://203785492 (ссылка не обнаружена в исходниках проекта). Ошибка первоначальной попытки QA через прямой MCP require относилась к отдельному контексту кэша инструментов; тест перенесён в обычный Script и прошёл. Коммит и публикация отсутствуют.

Нативная мышь: проверены горизонтальный и вертикальный повороты; LookVector камеры изменился с (0,-0.174,-0.985) до (0.827,-0.442,-0.349), направление героя совпало с горизонтальной проекцией камеры. MouseBehavior остался LockCenter.

Сохранённый Setup/Runner затем запущен автоматически в новой Play-сессии: повторно PASS 43/43, 9,50 с. Исходный Output сохранён в COMBAT-UX-STUDIO.log. После проверки Play остановлен, временные тестовые Script удалены из редактора; игровые изменения оставлены. Полный матч 5v5 не проверен.

## Расенган: интерфейс и анимация усилений

Дополнительная итерация 04.11.2026 по запросу о понятности трёх вариантов:

- `RasenganEvolutionHUD` показывает слева постоянную цепочку 1 → Z → X: названия,
  разные значки, ранг II/III, стоимость 100/+200/+200 чакры, секундное окно и
  подсказку удара ЛКМ. Активная стадия выделяется; закрытое окно, недостаток чакры,
  очередь нажатий и ограничения формы отображаются явно. Панель не закрывает
  персонажа и центральный прицел. Базовый Расенган остаётся доступен в формах;
  требование обычной формы относится только к усилениям Z/X.
- `RasenganUpgradeQueue` сохраняет два явных последовательных нажатия во время
  ожидания подтверждения сервера. Быстрое 1/Z/X больше не теряет усиления из-за
  незавершённого предыдущего запроса. Очередь не выбирает усиление сама и не
  расширяет серверные окна; очищается при отказе, отмене, смерти, меню и смене каста.
- `HeroPoses` и `HeroMotionController`: компактная сфера в ладони, крупная Одама с
  поддержкой второй рукой, Расенсюрикен над головой; разные подготовка и удар.
  Подготовка видна сразу, ноги продолжают двигаться при удержании заряда.
- `RasenganVisual`: голубое ядро, три вращающихся потока чакры, плавный рост,
  Одама диаметром 4,3 studs и Расенсюрикен с четырьмя заострёнными лопастями.
  Геометрические потоки используют 72 коротких сегмента для близкого героя и 16
  для клонов/дальних моделей. Сохраняется общий предел эффектов и дальность.
  Вращения вычисляются от начала каста, чтобы Unix-время не теряло точность в CFrame.
- Контакт, подтверждённый урон и завершение получают вариант техники и собственные
  эффекты. Расенсюрикен создаёт сферический ветровой вихрь. Баланс и ближний способ
  применения сохранены. Внешние модели, изображения и Blender-ассеты не требуются.

Проверки этой итерации: полный прогон **PASS, 208 файлов, 39,90 с**;
`build/rasengan-presentation-check.log`. Очередь усилений — **32 проверки PASS**,
позы/состояния — **87 проверок PASS**. Повторный серверный Play-прогон — **43/43 PASS,
9,48 с**. Реальными клиентскими нажатиями проверены 1, 1/Z и быстрое 1/Z/X;
последнее дало Holding/Rasenshuriken с расходом 500 чакры до регенерации.
ЛКМ с Одамой: один Contact, один Impact, один Finish; HP близкой цели уменьшилось
на 418, заряд очистился, дальняя цель и цель за стеной не получили урон.
Визуально проверены все три силуэта и итоговая боковая панель; ранние засвеченные
варианты заменены более читаемыми цветами и потоками. Полный матч 5v5 не запускался.

Локальный `build/combat-ux-manual.rbxlx` сохранён в Studio; все **133** игровых
исходника внутри файла сверены с `src` без отличий. Тестовая площадка и выдача рангов
создаются только в Play и не входят в сохранённый проект. Изменения не опубликованы.

## Коррекция выбора вариантов по запросу пользователя

Предыдущая боковая цепочка отменена. После Q базовый слот заменяется доступными
вариантами: Z — Одама (ранг II), X — Расенсюрикен (III). Q → X работает напрямую;
каждый выбор стоит +200, всего 300 чакры. Базовое окно выбора длится до окончания
заряда (15 с); сервер сохраняет проверки ресурса, ранга, формы и контроля.
Неизученные варианты скрыты. Без выбора остаётся обычная сфера и удар ЛКМ.

Для всех видимых слотов добавлены подробные hover-описания: действие, условия,
чакра, восстановление, управление. Alt освобождает курсор. Активный вариант имеет
своё описание. Боковой RasenganEvolutionHUD больше не запускается.

Эффекты: Расенсюрикен при контакте создаёт оболочку с 72 сегментами трёх вращающихся
полос и 24 внутренними режущими потоками; дым клонов объёмнее, рубка Гамакичи
рисует дугу меча; Sage/KCM получили движущиеся потоки чакры с очисткой состояния.
Это процедурная стилизация; импортированных анимаций из аниме нет.

Studio: подтверждены отсутствие боковой панели, два варианта вместо Q, прямой
Q → X и его попадание по цели; описание клонов просмотрено наведением мыши.
Чистые тесты проверяют прямую ветку и отсутствие расхода cooldown Одамы.

## Sage throw, map area parity and Creator Store visuals — 2026-11-04

- Active Sage, rank III: Q → X, wait until Holding, LMB throws along the crosshair. A separate throw pose and travelling wind blade precede the blue dome. Outside Sage, the existing melee technique remains.
- Source: supplied Naruto_Legend_1_7a_FIX20_3.w3x, extracted war3map.j. Ordinary A013 release around 47880–47974 and shared area trigger 48232–48356: initial radius 300, +5 before each 0.04-second pulse for the first 40 pulses, cap 500; first damaging radius 305. Delay 0.5 seconds, area lifetime 3.5 seconds. Each pulse uses integer floor((600 + 4 * floor(current STR)) / 87), with current strength reread per pulse. Primary hit stun 4.5 seconds; pull 4 WC units/pulse; structures excluded. Other advanced forms use different initialization and were not substituted.
- Existing prototype conversion is 1 WC unit = 1/16 stud, giving initial 18.75, first damage 19.0625, maximum 31.25 studs. This conversion is an adaptation, not a constant from Warcraft. Targeted WC3 travel is adapted to crosshair flight and Roblox world collision; damage uses the project's existing mitigation and line-of-sight policy.
- Client dome and server area use the same shared radius function and start/end times. Inner streams and bands are clamped inside the damage sphere. Client geometry audit: 6720 sampled part corners, zero radius overshoot. Wall shielding makes the actual damage set a subset of the sphere where obstacles intervene.
- Server throw regression: 14/14 checks passed (rank/form/charge lifecycle, preparation, malformed aim, duplicate rejection, wall stop/shielding, no self damage, cancellation after invalid life). Real keyboard/mouse throw hit two exposed targets for 792 each at test strength; protected target stayed at 100000 HP.
- Creator Store normal/Sage costumes and wind-blade mesh are integrated. Textured chakra uses the user's existing Naruto Pack. See CREATOR-ASSETS.md for provenance and conversion details.
- Fixed the Sage portrait overlap/missing face: hide the original dynamic head; use exactly one visible imported face, build a neutral portrait bust, preserve R15 clothing, explicitly preload its textures. Live audit: one WorldModel, one portrait model, one visible head, zero particles/scripts, Sage face fetch Success. Normal/Sage appearances were visually checked.
- Final full local checks PASS (40.85 seconds), build/creator-portrait-check.log. All 142 source files match the saved Studio build/combat-ux-manual.rbxlx after normalizing trailing whitespace. No publication. Manual QA deck/ranks and prolonged Sage are Play-only and are not saved into production.

## Development release and console — 2026-11-04

- `releases/Naruto-Legend-Development.rbxlx` is a standalone Studio place, built from `development.project.json`. Play starts a solo match on the normal map after the countdown. `Naruto-Legend-Game.rbxlx` uses normal participant requirements. Rebuild both with `scripts/release.ps1`; see `releases/README.txt` for Russian controls and commands.
- F8 opens the developer console: `level 30`, `learnall`, `nocd on`, `nocd off`, `refresh`, `solo`, `help`. Commands affect only the requesting player, use a bounded whitelist and rate limit, and are gated by server-side `IsStudio`. The remote and console are not started on published servers. Solo override is also Studio-only.
- Level changes use progression rules and publish the correct round ID so character health, strength and HUD update together. Learn-all spends normal skill points and respects rank requirements. No-cooldown clears timers, including variants and forms, without bypassing preparation, control, costs or form requirements. Refresh restores living hero HP and ordinary chakra; it does not resurrect or refill Kurama's separate resource.
- Full source/type/pure-test/build checks PASS (41.59 seconds), `build/developer-commands-check.log`. Opened the actual development release in Studio and ran `tests/developer/Runner.server.luau`: 17/17 checks PASS, including level 30, strength 56, actual Humanoid maximum health 1420, HUD attributes, cooldown on/off, resource restoration and preserving a real Rasengan preparation.
- Existing asset warning for `203785492` remains in Studio output; no developer-command errors. These are local playable builds, not a published Roblox experience. Full multiplayer match validation was not repeated for this release.
