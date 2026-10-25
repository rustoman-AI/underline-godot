# Underline: текст страницы Steam (черновик v1, 17 октября 2026)

Этап 4 `docs/RELEASE_PLAN.md`, пункты 6 и 7. Публикует только владелец, в Steamworks. Этот файл только текст.

Правила, по которым писано:
- EN и RU написаны каждый на своём языке. Смысл один, слова разные. Не выравнивать одну версию по другой.
- В тексте для игрока нет тире (ни «—», ни «–»). Никто не улыбается, никто не герой. Тон Frostpunk и This War of Mine.
- Скрытая правда о Тишине не раскрывается: ни всплеска, ни неба, ни «кто знал заранее». На странице только публичная версия (сверху перестали отвечать, наверх ушли и не вернулись) и крючок из тизера «кто-то до сих пор ведёт счёт».
- RU обращается к игроку на «ты», как игра (DECISIONS, 17 окт). Термины как в игре после прохода 14ebf4a: «тоннель», «ступень», «утренняя сводка», «станция» (не «двор»).
- Цифры, которые надо сверить при заморозке состава EA (этап 2), помечены в конце файла. На странице ничего не обещаем сверх того, что войдёт в сборку.

Формат длинного описания: разметка Steam (`[h2]`, `[list]`, `[*]`, `[b]`). В поле Steamworks вставлять блок целиком, без строк кода Markdown.

---

## 1. Короткое описание (поле «Short description», до 300 знаков)

### EN (249 знаков)
```
Hold one station. Keep the lights on. Do not ask what happened up there. A turn-based strategy of survival and station politics in the New York subway after the Silence. Dig, build, decide who eats, and deal with five powers whose help always costs.
```

### RU (241 знак)
```
Держи одну станцию. Береги свет. И не спрашивай, что случилось наверху. Пошаговая стратегия о выживании и политике в метро Нью-Йорка после Тишины. Копай, строй, решай, кому хватит еды, и договаривайся с пятью силами. Даром никто не помогает.
```

---

## 2. Длинное описание (поле «About This Game»)

### EN
```
[h2]After the Silence[/h2]
One night the surface stopped answering. The radios went quiet. Whoever went up the stairs never came back down.

The people who were underground stayed there. Now every station in New York is its own small country, and yours is at the far end of the Coney line, by the sea. Underline is a turn-based strategy game about keeping it alive for forty weeks.

Hold one station. Keep the lights on. Do not ask what happened up there.

[h2]A station is a place, not a number[/h2]
You see your station cut open from the side: the platform, the service levels above it, the rock below. Dig into the rock, build rooms, and put people where the work is. Air, food and power never line up in the same week. Something always runs short, and you choose what.

Your people have names. Each one had a trade before the Silence and kept one thing from it. They fall sick, they quarrel, they leave empty bunks behind. Sit with them long enough and they will tell you how they got here.

[h2]Five powers, and every one of them is right about something[/h2]
[list]
[*][b]The Depot[/b] keeps the lights on across the south, and burned something it does not talk about.
[*][b]The Iron Directorate[/b] keeps the lists. Without the lists everyone would have starved by the first month. Some names on them are marked surplus.
[*][b]The Synod of the Tunnel[/b] sits with the dying when nobody else will. Its exit is chained.
[*][b]The Free Exchange[/b] sells anything, and remembers who owes.
[*][b]The Lamplighters[/b] walk you through the dark tunnels, for a toll.
[/list]
Their leaders meet you in person and speak in their own voices. Each one will offer help you badly need, and the price is something you will carry for the rest of the run.

[h2]Every week, a choice that costs[/h2]
People are at the gate with a story about a collapse up the line. Taking them in means more mouths. Turning them away means everyone watched you do it. Pass laws that save food now and break hope later. Get through the flood, the cold and the cough. Win stations on the network map, then hold them, because a station you neglect will listen to whoever feeds it.

[h2]Nobody tells the whole story[/h2]
Each leader holds one piece of what happened that night, and each has a good reason to keep it. Earn their trust and the truth comes with proof. Take their deal and you will know it too, with nothing anyone will believe. You cannot learn all of it and keep your hands clean.

Somewhere up there, someone is still counting.
```

### RU
```
[h2]После Тишины[/h2]
Однажды ночью сверху перестали отвечать. Радио замолчало. Кто поднимался по лестнице, тот уже не спускался обратно.

Те, кто был под землёй, там и остались. Теперь каждая станция Нью-Йорка сама себе государство. Твоя стоит в конце линии Кони, у самого моря. Underline: пошаговая стратегия о том, как продержать её сорок недель.

Держи одну станцию. Береги свет. И не спрашивай, что случилось наверху.

[h2]Станция, а не цифра в отчёте[/h2]
Станция видна в разрезе: платформа, служебные ярусы над ней, порода внизу. Ты копаешь, строишь комнаты и ставишь людей туда, где нужны руки. Воздуха, еды и света никогда не хватает на всё сразу. Каждую неделю чего-то недостаёт, и выбирать, чего именно, тебе.

У каждого жителя есть имя. До Тишины у каждого было ремесло, и от прежней жизни каждый сберёг одну вещь. Люди болеют, ссорятся, по утрам находятся пустые койки. Посиди с ними подольше, и они расскажут, как сюда попали.

[h2]Пять сил, и у каждой своя правда[/h2]
[list]
[*][b]Депо[/b] держит свет на всём юге. И когда-то сожгло то, о чём там не говорят.
[*][b]Железная Дирекция[/b] ведёт списки. Без них к концу первого месяца не осталось бы никого. В списках есть графа «лишние».
[*][b]Синод тоннеля[/b] сидит с умирающими, когда больше некому. Выход у них заперт на цепь.
[*][b]Свободная Биржа[/b] продаст что угодно и не забудет, кто ей должен.
[*][b]Фонарщики[/b] проведут тебя тёмными тоннелями. За плату.
[/list]
Их лидеры приходят к тебе сами и говорят своими голосами. Каждый предложит помощь, без которой не обойтись, и цену за неё ты будешь нести до конца игры.

[h2]Каждую неделю выбор, и у каждого цена[/h2]
У ворот люди. Говорят, выше по линии обрушился свод. Примешь их, станет больше ртов. Прогонишь, и вся станция это запомнит. Законы сберегут еду сегодня и отнимут надежду через месяц. Впереди затопление, холод и кашель. Станции на карте сети можно перетянуть к себе, но удержать их труднее: забытая станция пойдёт за тем, кто её кормит.

[h2]Всей правды не скажет никто[/h2]
Каждый лидер хранит свой осколок того, что случилось той ночью, и у каждого есть причина молчать. Заслужишь доверие, и правда достанется тебе с доказательством. Примешь сделку, и правду ты тоже узнаешь, только предъявить её будет нечем. Узнать всё и остаться чистым не выйдет.

А наверху кто-то до сих пор ведёт счёт.
```

---

## 3. Особенности (отдельный блок под описанием или конец «About This Game»)

Если Steam-страница получит раздел «Features» в виде картинок с подписями, использовать эти строки как подписи. Иначе вставить список в конец длинного описания под заголовком `[h2]Features[/h2]` / `[h2]Что в игре[/h2]`.

### EN
```
[list]
[*][b]One station in cross section.[/b] Dig through rock, build and staff the rooms, and watch your people work, eat and get sick.
[*][b]Named residents with a past.[/b] Every one of them has a trade, a story and one thing they kept from before. Their stories are voiced.
[*][b]Five leaders who visit you.[/b] Voiced audiences, dirty deals, and opinions of you that do not reset.
[*][b]A real subway map.[/b] Grand Central, Wall St, Times Sq, Atlantic Av. Win stations by supply, persuasion or force, then keep them fed.
[*][b]Laws with a long tail.[/b] Rationing, curfew, double shifts, the Ledger of the Dead. Each one helps today and sends the bill later.
[*][b]Seasons of the Silence.[/b] Flood, cold and cough arrive with a warning, and each one lands on a station that is already tired.
[*][b]A truth in pieces.[/b] Five fragments, three sealed bunkers, several endings. What you learn depends on whom you trusted and what you gave up.
[*][b]Turn based, one week per turn.[/b] No timers. Take as long as you need to decide who goes without.
[/list]
```

### RU
```
[list]
[*][b]Станция в разрезе.[/b] Копай породу, строй и укомплектовывай комнаты, смотри, как люди работают, едят и болеют.
[*][b]Жители с прошлым.[/b] У каждого ремесло, своя история и одна вещь из прежней жизни. Истории озвучены.
[*][b]Пять лидеров приходят к тебе сами.[/b] Аудиенции с озвучкой, грязные сделки, и отношение к тебе, которое не обнуляется.
[*][b]Настоящая карта метро.[/b] Гранд-Сентрал, Уолл-стрит, Таймс-сквер, Атлантик-авеню. Станции берутся поставками, уговорами или силой, а потом их надо кормить.
[*][b]Законы с долгим хвостом.[/b] Пайки, комендантский час, двойные смены, Книга мёртвых. Каждый помогает сейчас, а счёт приходит потом.
[*][b]Сезоны Тишины.[/b] Затопление, холод и кашель приходят с предупреждением, и каждый бьёт по станции, которая и так устала.
[*][b]Правда по осколкам.[/b] Пять осколков, три запертых бункера, несколько концовок. Что ты узнаешь, зависит от того, кому поверил и чем заплатил.
[*][b]Пошагово, неделя за ход.[/b] Никаких таймеров. Думай сколько нужно, прежде чем решить, кто останется без пайка.
[/list]
```

Сверить с игрой перед публикацией: русские названия законов, сезонов и станций взяты из `data/ru.json` («Пайки», «Книга мёртвых», «Затопление», «Гранд-Сентрал»). Если в игре их переименуют, поправить и здесь.

---

## 4. Теги

Steam позволяет до 20 тегов; первые пять весят больше всего. Порядок ниже и есть порядок приоритета. Названия тегов как в списке Steam (английские, Steam переводит сам).

| № | Тег | Почему |
|---|---|---|
| 1 | Strategy | Жанр |
| 2 | Survival | Главная петля: воздух, еда, свет |
| 3 | Base Building | Разрез станции, копка, комнаты |
| 4 | Choices Matter | Сделки, законы, события с ценой |
| 5 | Post-apocalyptic | Сеттинг |
| 6 | Turn-Based Strategy | Неделя за ход (в плане стоит «Turn-Based»; в Steam есть и общий «Turn-Based», можно поставить оба) |
| 7 | Political | Пять сил, лидеры, карта сети |
| 8 | Resource Management | Воздух, еда, энергия, материалы, жетоны |
| 9 | Colony Sim | Люди с навыками и судьбой |
| 10 | Management | |
| 11 | Story Rich | Осколки правды, концовки, истории жителей |
| 12 | Dark | Тон |
| 13 | Mystery | Тишина |
| 14 | Atmospheric | |
| 15 | Singleplayer | |
| 16 | 2D | |
| 17 | Political Sim | Если хватит места |
| 18 | Indie | |

Не ставить: Hand-drawn (рисунок сделан генератором, тег будет вводить в заблуждение), Horror, Roguelike, Relaxing, Cute, Funny.

---

## 5. Раскрытие ИИ-контента (анкета Steamworks, раздел «AI Generated Content Disclosure»)

В анкете два поля: заранее сгенерированный контент (Pre-Generated) и генерация во время игры (Live-Generated). У нас только первое. Текст ниже идёт в поле описания; Steam показывает его на странице игры, поэтому писано для игроков, по-английски (анкета принимает один язык).

### Черновик (EN, в поле Pre-Generated)
```
This game was made by a very small team using AI tools during development. All AI content was generated in advance. Art and text were chosen and edited by people; voice, music and sound were chosen by people and checked for technical quality. Nothing is generated while you play, and the game does not connect to any AI service.

What AI tools were used for:
Art: station pictures, character portraits, room and resident art, and store artwork were generated with image models and then selected and corrected by hand.
Voice: leader and resident voices and the narration were generated with ElevenLabs from scripts written for the game.
Music and sound: the music and most sound effects were generated with ElevenLabs.
Writing: the story, dialogue and game text were drafted with the help of an AI writing assistant and edited by the team.

The full list of tools, voices and licenses is in CREDITS.md, which ships with the game.
```

Live-Generated: **No.** Галочку не ставить.

### Решено 17 октября (руководитель, по поручению владельца)
- Пункт 1: вариант (б), фраза сужена. Про звук написано только то, что было: выбран людьми и проверен технически.
- Пункт 2: строка «Writing» остаётся. Тексты черновиком пишет ИИ, это нужно раскрыть.
- Пункт 6: строку про код не добавляем, это инструмент разработки, а не контент игры.

### Что надо решить и проверить до отправки анкеты
1. **«Checked by people» для звука сейчас неправда.** По журналу решений (11 окт) озвучку, музыку и звуки принимаем по технической проверке, на слух позже. Варианты: (а) владелец или нанятый человек слушает всё, что идёт в сборку, до отправки анкеты, и тогда текст остаётся; (б) честно сузить фразу: «checked by people» оставить для арта и текста, а про звук написать «checked for technical quality». Писать про проверку людьми то, чего не было, нельзя.
2. **Текст игры.** В брифе этапа 4 перечислены только арт, голоса, музыка и звуки. Но тексты, события и реплики пишет ИИ-руководитель проекта, а Steam требует раскрывать любой ИИ-контент, который попадает в игру или в материалы магазина. Поэтому в черновике есть строка «Writing». Убирать её можно только если владелец решит, что тексты переписаны людьми настолько, что это уже не ИИ-контент. Сама эта страница магазина тоже написана ИИ.
3. **Арт для магазина** (капсулы, ключевой арт по `docs/briefs/art_steam_capsules.txt`) тоже генерируется, это покрыто строкой «store artwork».
4. **CREDITS.md неполный.** Сейчас там шрифты, звуки, музыка, голоса лидеров и Kenney. Нет генераторов картинок (ChatGPT, Antigravity), голоса рассказчика тизера, Godot (MIT). Это этап 5 плана; закрыть до отправки анкеты, потому что раскрытие на него ссылается.
5. **Права.** Перед отправкой сверить коммерческие права в тарифах ElevenLabs и генераторов картинок на даты генерации (этап 5, пункт 2).
6. Код писали с помощью ИИ-ассистента (Cursor). По текущим правилам Steam инструменты разработки, которые не попадают в игру как контент, раскрывать не обязательно. Если владелец хочет полной открытости, добавить строку «Code was written with the help of AI coding assistants.»

---

## 6. Что сверить при заморозке состава EA (этап 2)

Все цифры и обещания на странице должны совпасть со сборкой EA. Перед публикацией пройтись по списку:
- «forty weeks» / «сорок недель»: длина прогона в EA (сейчас 40).
- Пять сил и пять лидеров с озвучкой: да, в игре.
- Озвученные истории жителей: в игре 30 историй EN и RU (CREDITS.md). Число жителей на странице не называем.
- «Five fragments, three sealed bunkers, several endings»: осколков 5, бункеров 3 (`docs/STORY.md`). Число концовок не называем, пока не заморожен состав (E3 может добавить концовку).
- Карта: Гранд-Сентрал, Уолл-стрит, Таймс-сквер, Атлантик-авеню есть на карте сети из 25 станций (`data/map_schematic.json`; Таймс-сквер это id `central`). Не писать «весь Нью-Йорк».
- Захват станций «поставками, уговорами или силой»: проверить, что все три пути работают в сборке после исправлений playtest11. Если силового пути нет, убрать «or force» / «или силой».
- Законы, упомянутые по имени: Rationing, Curfew, Double shifts, The Ledger of the Dead есть в `data/laws.json`.
- Сезоны: затопление (10-я неделя), холод (20-я), кашель (30-я) есть в `data/balance.json`. «The dark» не упоминать: его нет.
- Блок для раннего доступа (вопросы Steam «Why Early Access» и т. п.) здесь не написан: он зависит от решения по составу EA и датам. Написать отдельно после этапа 2.
