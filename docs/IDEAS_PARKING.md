# Парковка идей и текущий объём (12 октября 2026)

Правило: **новая идея не попадает в работу, пока не вышли результаты плейтеста.** Любая идея сначала записывается сюда одной строкой. В работу её может перенести только владелец проекта.

## В работе сейчас (всё остальное ниже на парковке)
1. **Исправления по отзыву тестера:** портреты по полу, профессия, «До тишины» и «Вещь» в досье, 12 новых портретов (`docs/briefs/cursor_profiles_portraits.txt`).
2. **Мелкие правки после ночного QA:** русские названия станций и строки соперников, контраст, автомасштаб (`docs/briefs/cursor_after_qa.txt`).
3. **Вторая сборка 0.1.0-playtest2** для тестеров (входит в пункт 1).
4. **Ожидание журналов и анкет тестеров.** Дальше решаем по данным.
5. **Досье (вкладки):** написаны для всех 25 жителей Кони. Закрыто.

## Парковка (не делаем, пока нет данных плейтеста)
| Идея | Откуда | Статус | Документ |
|---|---|---|---|
| Режимы сложности (Ровно, Суровая зима, Долгая тьма) | EA E4 | Парковка. Патч готов: `build/diff/parked/difficulty_schema8.patch`. Бот-осторожный переживает даже максимальные множители, коридоры брифа недостижимы, запасы ниже ×0,89 ломают старт | `docs/briefs/cursor_difficulty_modes.txt` |
| Пул событий, батч 2 (общины, продолжения для жителей) | EA E2 | Парковка | `docs/EA_PLAN.md` |
| Нити: Сёстры, Ночной ходок, Родители, Первая любовь | Night Moon | Парковка | `docs/QUESTS.md` |
| Мини-игры: блокнот, сравнение фото, радио, счёт мисок, вентиль, допеть строку | Night Moon | Парковка | `docs/QUESTS.md` |
| Пассивные комментарии навыков в уликах («Диско-лайт») | Night Moon | Парковка | `docs/DESIGN_ANSWERS.md` |
| Маршруты и слухи подозреваемых (6–8) | Night Moon | Парковка | `docs/DESIGN_FRAME.md` |
| Доставки и экономика посылок («Космические рейнджеры») | Night Moon | Парковка (скорее мини-игра позже) | `docs/DESIGN_FRAME.md` |
| Допрос с деревом реплик | Night Moon | Отклонено для EA | `docs/DESIGN_ANSWERS.md` |
| Живой чат с ИИ на каждого | Night Moon | Отклонено | `docs/DESIGN_ANSWERS.md` |
| «Кабинет мыслей» как в Disco Elysium | Night Moon | Отклонено | `docs/DESIGN_ANSWERS.md` |
| Анимация стрелок манометров и пара кодом | Night Moon | Парковка | `docs/DESIGN_ANSWERS.md` |
| Ложные обвинения и «эхо ошибки»: неверный вердикт возвращается аудиенцией семьи (Family_ID) | Night Moon | Парковка (зависит от вердиктов, которых нет) | — |
| Профессия влияет на выгоду расстановки по комнатам | Night Moon | Парковка (частично уже есть через навыки) | — |
| Комбинировать характеристики людей, чтобы комната набрала нужное (менеджмент навыков при заполнении клетки) | Night Moon | Парковка (частично уже есть: у комнаты один главный навык, выработка зависит от навыков, потолок 2,5) | data/rooms.json, data/balance.json |
| Озвучка карточки «Как держать станцию» (6 строк, диктор Daniel) | ты | Парковка до правок по плейтесту | data/howto.json |
| Ещё 8 женских и 4 мужских портрета для новичков (сейчас свободны 3 мужских и 0 женских, у беженок общие лица с основными жительницами) | Cursor, QA | Парковка. Первый кандидат, если тестеры заметят одинаковые лица | `docs/briefs/art_resident_portraits_12.txt` |
| Мелкие русские формулировки: «уходит к Дирекции/Депо/Синоду/Бирже/Фонарщикам» (дательный), «Бунт. Платформа обращается против тебя» | Cursor | Парковка до следующей сборки | — |
| Больше именных жителей и станций (оптимально 25–35 именных, 15 станций в EA) | Night Moon | Парковка до данных плейтеста | — |
| Вселение в жителя от первого лица (как в Dungeon Keeper) | Night Moon | Отклонено | — |
| Экосистема фракций в духе «Метро» (малые, прочие, скрытая рука, поверхность) | владелец | Парковка, далеко | `docs/IDEAS_PARKING.md` ниже |
| Франшиза и «интерактивная книга» | Night Moon | Идея, далеко | — |
| Логотип и страница Steam | маркетинг | Парковка до результата плейтеста | `docs/MARKETING.md` |
| Ключевой арт и капсулы | маркетинг | Парковка | `docs/MARKETING.md` |
| Лор для пяти «обобщённых» жителей (Ким, Крис, Мина, Дрю, Энн) | досье | Парковка (нужны только вне Кони) | — |
| Детское лицо для Лео (13 лет) | арт | Парковка | — |
| Озвучка эпилогов, событий и новых строк | Muse | Парковка, кредиты не тратим | — |
| Вторая и третья цепочка артефактов, расширение сюжета | сюжет | Парковка | `docs/STORY.md` |
| Новые фракции, новые станции, второй игровой фракция | GDD | Парковка до после EA | — |
| Андроид и мобильная версия | GDD | Парковка | — |

## Экосистема фракций (из пасты про вики «Метро», запись для будущего)
Ярусы: большие силы (у нас пять), малые общины (у нас 25 в текстах), прочие группы (бандиты, сталкеры, мутанты), скрытая рука (бункеры, знавшие заранее), поверхность. Не копировать «Метро» буквально: без неонацистов и без реальных партийных знаков.

## Правила, чтобы не разрастаться
1. Не больше **одного активного набора задач на агента** за раз (Cursor, ChatGPT, Muse).
2. Новая идея = одна строка здесь. Обсуждать позже.
3. Музыка, озвучка, арт и крупный код только после слов владельца «в работу».
4. После плейтеста: смотрим журналы и анкеты, выбираем **одну** следующую цель.

- Settings text "No hover ticks or drips..." (ui/station.gd:8326, data/ru.json:909) is stale: hover ticks no longer exist. Reword with the next code pass. (12 Oct, from Cursor playtest3 report)

- F22: station view scale and width ("increase map scale, make it wider", Taiga). Needs a clarifying answer from the author first: station cross-section or network map, and what is too small. Check against the B2 camera clamp and the 0.75 to 1.5 zoom limits before any change.

- F22 update: Ruslan also says the map should be bigger (two testers now, with Nicholas). Candidate NEXT package after numbers clarity, once we know which view (station or network) and what is too small. Network view today: min zoom = fit to the area, max = 3.5x fit (ui/network_view.gd:36,380).

- Intro (about 45 s, 5 to 6 cards): in-engine slideshow of existing art with slow pan, text from data (EN/RU), optional narrator via Muse on "go". No AI video. Candidate after numbers clarity and map size, if playtest data still says "I do not understand the goal". (12 Oct, owner)

- Station toast ("Станция/Station" corner message) draws over open modal cards (seen on the generator card, covers the Demolish button edge). Layer it under modals. (12 Oct, numbers clarity screenshots)
- Design note: switching the workshop off lowers materials storage and the surplus burns (about -12 in one night). Now visible in the forecast as "Store full". Decide after playtest data whether the rule needs a warning on the switch. (12 Oct, Cursor)

- Upgrades: part B (one per week, cost x1.5, optional 1 week of work) waits for the owner yes, see docs/briefs/cursor_upgrade_visible.txt. Related older F12/F13 (cooldown, build tiers) stay parked. (12 Oct, owner playtest)

- Night Moon ideas (13 Oct): one murder-mystery branch (a character dies after day one, find who), a radio madman with daily news, skill synergy per room (Strength, Wits, Speech, Perception), a saboteur spy, a clearer reason to grow the station. Artur: too much now, write for later. Also reference game UNFROST (detective logic, very positive Steam reviews).
- F42: Brooklyn stations too far apart (owner issue). Changes the map and travel time, owner decides.

- CANDIDATE NEXT GOAL (13 Oct, from outside AI text pasted by the owner and Night Moon feedback "three identical buttons"): give each station order its own role, price and risk. Expedition = one-off errand for a concrete haul (needed first: a station is a name and a rumour until someone has been there), Convoy = move people or goods to stay (gives beds, production, storage; can be refused or robbed), Influence = long work on opinion that makes the first two cheaper and safer. Plus a real reason to expand: the home station has a people ceiling and overcrowding hurts (already exists as Overcrowding +2/wk; "capacity with debuffs" is F19). Decide only after the playtest logs show whether players find the orders interchangeable. Needs the lead's design pass and Cursor; changes balance, so the 30-seed gates.
- Daughter of the warden and the dog Bimbo in the tunnel: a full quest chain, later, one of the first story quests.
- Resident lines when assigned to a room ("again hydroponics, I am allergic", "Rob took the 16 key again"): cheap, later as one batch of text.
- One simple mini-game on a frequent action (repair or filter work) instead of five different ones: later.
- A station with a clear market and exchange rate (Heroes style): later.

- VISUAL POLISH BATCH (14 Oct, two AI reviews of playtest7, F49). Quick wins in order of value: (1) top bar: dark pill behind each resource and amber or red text when the weekly net is negative; (2) dug, being-dug and empty cells look different (crack and dust while digging, a faint cable or debris on dug-empty cells, darker unmined rock); (3) people readable: soft shadow or warm rim under sprites, slightly clearer working pose; (4) panel contrast: lighter panel or stronger gold border, more space between buttons; (5) incident marker on the room when an event hits it (rats on hydroponics); (6) territories and route lines hand-drawn (dashes, ink stroke) instead of vector circles (F47). Not now: rivet frames, per-room light colours, dust and steam particles. Code only, no new art. One Cursor package after the tester logs.

- COMPACT STATION CARD (14 Oct, F50; raises item 7 of the polish batch): header (name, opinion number and bar, two or three state icons, close), at most 3 to 4 buttons that are available now with their cost (Errand with people and food, Envoy with influence, Trade, Squad), unavailable ones greyed with the reason on hover, everything else (needs, risk text, long descriptions, special approaches) under a "Details" fold. Cuts the length of the sheet and the repeated "Next dawn". Check against F46 (wrong banner) in the same pass. Also from the same texts, later: route lines as ink dashes or string, territories as hatching, fog-of-war as burnt edges instead of "?" circles, an MTA tunnel layer. Not now: the people drawer (already collapsed on the map).
