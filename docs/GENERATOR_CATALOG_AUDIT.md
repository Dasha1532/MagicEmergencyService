# Аудит каталога объектов и аномалий

Статус: фактическое состояние экспериментального форка. Основная демоверсия в `main` не изменяется.

## Источник данных игры

Таблицы ниже являются отчётом, а не источником данных. Игра автоматически загружает определения из:

- `data/objects/*.tres` — свойства предметов, теги, состояния, сцены и ассеты;
- `data/anomalies/*.tres` — совместимость аномалий, начальные состояния, цели, безопасные планы и игровые тексты.

Файлы не перечисляются вручную в генераторе. `GenerativeJobCatalog` сканирует обе папки, загружает каждый `.tres` и отклоняет дубликаты ID, повреждённые ресурсы и неполные определения.

## Как читать таблицы

- `—` означает, что свойство явно неприменимо, а не забыто.
- «Готов» означает, что состояние имеет данные, безопасный путь решения, поддерживаемую сцену и визуальную обратную связь.
- «Описан» означает, что данные перенесены в каталог, но генерация отключена до обобщения специализированной симуляции.
- Универсальный слой — общий ассет эффекта, накладываемый поверх базового изображения предмета.

## Свойства предметов

| ID | Предмет | Постоянные теги | Масса | Прочность | Температура | Магия | Закреплён | Перемещаем | Стоимость | Поддерживаемые состояния | Визуальный профиль | Готовность генератора |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | --- | --- |
| `wardrobe` | Шкаф | furniture, wooden, flammable, freezable, heavy, container, fragile_contents, movable, animatable, large | 8 | 7 | 2 | 0 | нет | да | 520 + содержимое 180 | animated, moving, frozen, burning, scorched, damaged, destroyed | `wardrobe` | **Готов** в `eleonora_room` |
| `lava_faucet` | Лавовый кран | plumbing, metal, anchored, pressurized, heat_source, freezable | 8 | 5 | 9 | 0 | да | нет | 350 | lava_flowing, frozen, overheated, melted, scorched, damaged | `lava_faucet` | Описан; симуляция пока специализирована |
| `portal_mirror` | Портальное зеркало | mirror, glass, fragile, anchored, portal_capable, magic_conductor, freezable | 6 | 3 | 2 | 0 | да | нет | 680 | portal_open, cold_aura, covered, heat_damaged, closed, destroyed | `portal_mirror` | Описан; симуляция портала специализирована |
| `drain_gargoyle` | Водосточная горгулья | drain, stone, heavy, anchored, animatable, cloggable, drainage, freezable | 9 | 8 | 2 | 3 | да | нет | 760 | dormant, awake, clogged, flooding, frozen, damaged | `drain_gargoyle` | Описан; составная цель водоотвода не обобщена |
| `bathtub` | Ванна | plumbing, ceramic, anchored, water_contact, freezable, fragile | 9 | 6 | 2 | 0 | да | нет | 480 | frozen, ice_removed, damaged, destroyed | `bathtub` | Описан; в ручной заявке состояние разделено между ванной и краном |
| `escaped_ghost` | Привидение | spirit, incorporeal, magic_conductor, portal_linked | 0 | 0 | — | 7 | нет | да | 0 | calm, angry, captured, expelled | `escaped_ghost` | Описан; требует составной сцены с зеркалом или ловушкой |
| `ghost_trap` | Ловушка для привидений | equipment, container, magic_conductor, movable | 2 | 5 | 2 | 2 | нет | да | 250 | packed, installed, occupied | `ghost_trap` | Описан как вспомогательный объект, не как источник заявки |
| `protective_cloth` | Защитное полотно | equipment, fabric, movable, magic_resistant, cover | 1 | 3 | 2 | 1 | нет | да | 50 | packed, installed, heat_damaged | `protective_cloth` | Вспомогательный объект; не источник заявки |
| `thermal_regulator` | Рунический терморегулятор | equipment, metal, movable, temperature_control, magic_conductor | 2 | 6 | 2 | 3 | нет | да | 280 | packed, installed, active | `thermal_regulator` | Вспомогательный объект; не источник заявки |
| `repair_kit` | Служебный ремонтный набор | equipment, tools, container, movable | 3 | 7 | 2 | 0 | нет | да | 180 | packed, in_use | `repair_kit` | Вспомогательный объект; не источник заявки |

Для каждого объекта каталог требует наличие полей `mass`, `durability`, `temperature`, `magic_level`, `damage`, `anchored`, `movable` и `replacement_value`. Неприменимое значение должно быть записано явно как `null`; отсутствие ключа считается ошибкой каталога.

## Визуальные состояния предметов

| Предмет | Состояние | Визуал | Тип | Примечание |
| --- | --- | --- | --- | --- |
| Шкаф | walking | `assets/objects/walking_wardrobe/walking.png` | отдельный ассет | Есть |
| Шкаф | idle | `assets/objects/walking_wardrobe/idle.png` | отдельный ассет | Есть |
| Шкаф | damaged | `assets/objects/walking_wardrobe/broken_legs.png` | отдельный ассет | Показывает именно сломанные ножки |
| Шкаф | destroyed | `assets/objects/walking_wardrobe/ash_pile.png` | отдельный ассет | Есть |
| Шкаф | frozen | `assets/effects/status/frost.png` | универсальный слой | Есть, отдельной замёрзшей картинки шкафа нет |
| Шкаф | burning | `assets/effects/status/fire.png` | универсальный слой | Есть, поддерживает несколько очагов |
| Шкаф | scorched | `assets/effects/status/soot.png` | универсальный слой | Есть |
| Лавовый кран | normal / damaged | `assets/objects/lava_faucet/faucet_normal.png`, `faucet_damaged.png` | отдельные ассеты | Есть |
| Лавовый кран | lava_flowing | `assets/objects/lava_faucet/lava_stream.png` | отдельный слой | Есть |
| Лавовый кран | frozen / scorched | `frost.png`, `soot.png` | универсальные слои | Есть |
| Лавовый кран | overheated / melted | исходный кран + шейдер | процедурный визуал | Есть без отдельного PNG |
| Портальное зеркало | open / closed / covered / heat-damaged / destroyed | `assets/objects/portal_mirror/*.png` | отдельные ассеты | Все используемые комбинации присутствуют |
| Горгулья | dormant / awake / damaged / frozen | `assets/objects/drain_gargoyle/*.png` | отдельные ассеты | Есть также чистые варианты после удаления засора |
| Горгулья | flooding / frozen_flooding | `assets/effects/gargoyle_attic/*.png` | отдельные слои среды | Есть |
| Ванна | frozen / damaged / damaged_empty | `assets/objects/frozen_bath/*.png` | отдельные ассеты | Целая размороженная ванна берётся из фоновой сцены |
| Привидение | calm / angry | `assets/objects/escaped_ghost/*.png` | отдельные ассеты | Есть |
| Привидение | captured / expelled | объект скрывается | отсутствие объекта — визуальное состояние | Отдельный PNG не требуется |
| Ловушка | installed / occupied | `empty.png`, `occupied.png` | отдельные ассеты | `packed` показывается складским ассетом |
| Защитное полотно | packed | `assets/objects/protective_cloth/folded.png` | отдельный ассет | Есть |
| Защитное полотно | installed / heat_damaged | `portal_mirror/covered.png`, `covered_heat_damaged.png` | составной ассет | Полотно нарисовано вместе с зеркалом |
| Терморегулятор | packed / installed | `regulator.png`, `faucet_regulated.png` | отдельный и составной ассеты | Активная работа выражена состоянием установленного крана |
| Ремонтный набор | packed | `assets/objects/repair_kit/toolbox.png` | отдельный ассет | Во время работы отдельная картинка набора не показывается |

## Каталог аномалий

| ID | Аномалия | Требуемые свойства предмета | Начальные эффекты | Проверяемая цель | Безопасный путь | Генерация | Визуальная обеспеченность |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `restless_animation` | Беспокойное оживление | movable + animatable | animated, moving | остановить движение и освободить проход | перемещение + крепление; позднее антимагия или телекинез | **Включена** | walking/idle шкафа — есть |
| `active_fire` | Самовозгорание | flammable | burning, scorched | убрать активный огонь | заморозка | **Включена** | универсальные fire + soot — есть |
| `deep_freeze` | Магическое промерзание | freezable | frozen, brittle | снять промерзание без нового пожара | контролируемый нагрев | **Включена** | универсальный frost — есть для шкафа; отдельные frozen-ассеты есть у горгульи и ванной |
| `lava_leak` | Лавовая течь | plumbing + pressurized + heat_source | lava_flowing | остановить поток | заморозка в ручной симуляции | Отключена | кран и поток лавы — есть |
| `open_portal` | Открытый портал | portal_capable | portal_open, cold_aura | закрыть или безопасно изолировать портал | антимагия или защитное полотно | Отключена | open/closed/covered и повреждения — есть |
| `sleeping_drain` | Магический сон водостока | animatable + cloggable + drainage | dormant, clogged, flooding | восстановить отвод воды | оживление; механический обход | Отключена | горгулья и затопление — есть |
| `escaped_spirit` | Сбежавшее привидение | incorporeal + portal_linked | calm; при ошибках angry | вернуть или изолировать духа | портал + антимагия; ловушка | Отключена | calm/angry, зеркало и ловушка — есть |
| `cold_trace` | Остаточный холодный след | plumbing + water_contact + freezable | frozen | убрать причину и лёд | нагрев; антимагия/регулятор + удаление льда | Отключена | замёрзшие ванна и кран — есть |

## Найденные пробелы

1. У ручной заявки `frozen_bath` нет единого `definition_id`: ванна и кран пока хранятся в одном специализированном словаре. Для генерации их нужно разделить на два `ObjectInstance`.
2. У шкафа нет отдельного растрового изображения «цельный, но обгоревший» и «цельный, но полностью покрытый льдом». Состояния читаются через универсальные слои копоти и инея; для текущего прототипа это допустимо.
3. Для привидения состояния `captured` и `expelled` показаны исчезновением объекта, что считается полноценным визуальным состоянием. Отдельные изображения не требуются.
4. Аномалии портала, горгульи, привидения и холодного следа имеют ассеты, но пока зависят от уникальной логики своих сцен. Валидатор поэтому не разрешает генератору публиковать их.
5. Каталог пока содержит только комнаты, реально подготовленные для генерации. Наличие ассета объекта само по себе не делает сочетание «комната × предмет × аномалия» допустимым.
6. Учебные книги и комплекты не входят в эту таблицу: они являются данными магазина и способностей, а не объектами аварийной сцены. Физическое снаряжение, которое появляется в сценах, включено.

## Автоматические проверки

`GenerativeJobCatalog.validate_catalog()` проверяет:

- обязательные поля каждого объекта и аномалии;
- наличие всех базовых свойств объекта, включая явно неприменимые;
- существование визуального профиля объекта;
- существование сцен и файлов всех заявленных ассетов;
- существование целей, на которые ссылаются аномалии.

`GenerativeJobCatalog.compatible_anomalies()` дополнительно фильтрует варианты по тегам объекта, запрещённым тегам, визуально поддерживаемым эффектам и разрешению конкретной комнаты.
