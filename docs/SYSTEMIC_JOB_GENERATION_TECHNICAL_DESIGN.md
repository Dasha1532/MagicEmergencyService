# Техническое проектирование системной генерации заявок

Дата: 29 сентября 2026 года. Статус: проект архитектуры для согласования, без реализации.

## 1. Цели

Система должна:

1. Сохранять авторские комнаты Godot с фиксированными объектами и допустимыми зонами.
2. Создавать заявки из текущего постоянного состояния мира, а не из произвольного смешивания комнаты, мебели и эффекта.
3. Описывать объект слоями: материал → свойства → функциональные части → состояния → воздействия → универсальные переходы.
4. Применять действия одинаково к совместимым объектам: нагрев, заморозку, телекинез, физическое намерение, ремонт, антимагию и оживление.
5. Сохранять каждое действие, происхождение состояния и причинную связь между заявками.
6. Ставить последствия прошлых действий выше новых случайных аномалий.
7. До публикации проверять визуальную готовность и наличие доступного безопасного решения.
8. Хранить память жильца о конкретных сотрудниках и учитывать допуск, доверие и предпочтения при назначении.
9. Внедряться постепенно через адаптеры существующих ручных симуляций.

## 2. Нецели обязательного MVP

- Процедурная перестановка предметов между авторскими комнатами.
- Генерация новых сцен, изображений или анимаций во время игры.
- Полная физическая симуляция жидкостей, огня и разрушения.
- Свободный естественно-языковой диалог с ожившими объектами.
- Массовая генерация романтических реплик.
- Одержимость как синоним оживления. Без отдельного поведения, визуала, решений и последствий она не является самостоятельной аномалией и в MVP не входит.
- Одновременная замена всех существующих ручных заявок.

## 3. Аудит существующей реализации

### 3.1. Уже существует и пригодно для переиспользования

#### Физические и игровые параметры объектов

`res://scripts/repair_simulation.gd`, `world_object` лавового крана:

- `definition_id`, `tags`;
- `temperature`, `pressure`, `damage`, `durability`, `mass`;
- `anchored`, `movable`, `replacement_value`;
- `frozen`, `burning`, `scorched`, `visual_state`;
- фактические теги `faucet`, `lava_flowing`, `pressurized`, позднее `overheated`, `melted`, `repaired`, `sealed_by_melt`.

`res://scripts/wardrobe_simulation.gd`, `world_object` шкафа:

- `mass`, `durability`, `temperature`, `magic_level`;
- `movement_force`, `mobility`, `noise`;
- `anchored`, `movable`, `position_zone`, `requested_zone`;
- `moving`, `held`, `frozen`, `brittle`, `burning`, `scorched`, `destroyed`;
- `size_class`, `fire_spots`, `max_fire_spots`, `burn_stage`, `next_fire_spread_at`;
- `damage`, `contents_type`, `contents_damage`, `replacement_value`, `contents_value`;
- `visual_state`, `resident_voice_variant`.

`res://scripts/gargoyle_simulation.gd`:

- `definition_id`, `awake`, `clogged`, `bypass_open`, `damaged`;
- `clog_removed_before_damage`, `frozen`, `magic_level`, `damage`.

`res://scripts/portal_mirror_simulation.gd`:

- `definition_id`, `magic_level`, `temperature`;
- `portal_open`, `covered`, `cold_aura`, `stable`, `destroyed`, `damage`.

`res://scripts/frozen_bath_simulation.gd` хранит предметные булевы состояния: `bath_damaged`, `bath_still_frozen`, `ice_removed`, `cold_trace_removed`, `extra_frost`, `regulator_installed`, `faucet_diagnosed`.

`res://scripts/ghost_followup_simulation.gd` хранит составное состояние: `ghost_state`, `mirror_state`, `frame_damage`, `trap_state`.

#### Общие правила и эффекты

`res://scripts/object_interaction_rules.gd` уже содержит универсальный `apply_telekinesis(world_object, target_zone)`:

- отвергает `destroyed`;
- запрещает перемещение `anchored`;
- учитывает `movable`;
- требует целевую зону;
- меняет `position_zone` и снимает `held`.

Это полезный первый адаптер, но масса, отделимые части и последствия вырывания пока не учитываются.

`res://scripts/object_status_effects.gd` и `res://scenes/ObjectStatusEffects.tscn`:

- читают `frozen`, `burning`, `scorched`, `destroyed`, `fire_spots`;
- показывают `assets/effects/status/frost.png`, `fire.png`, `soot.png`;
- поддерживают несколько очагов огня и tween-анимацию.

`res://scripts/resident_reaction_resolver.gd` уже обобщает реакцию на `burning`, `damage`, `destroyed`, исчерпанную `durability` и `visual_state == melted`.

`res://scripts/employee_reaction_resolver.gd` умеет выбирать реплику по:

- `action_ids`, `intent_ids`;
- `object_equals`, `object_min`, `object_max`, `required_tags`;
- персональным `action_reactions` и `ability_reactions`.

#### История действий и причинные продолжения

Все основные симуляции сохраняют `action_log`. Текущий минимальный формат обычно содержит `employee_id`, `action_id`, иногда `intent`, и вложенный `result`.

Уже реализованы причинные переходы:

- `repair_simulation.gd` формирует `follow_up = {type: frozen_bath, source_job_id: lava_leak}` после определённого исхода;
- `portal_mirror_simulation.gd` формирует `escaped_ghost` с `cold_aura` и `frame_damage`;
- `game_state.gd` ищет `follow_up` в `job_reports` и открывает последующую заявку;
- пожар шкафа развивается по времени вне комнаты через `job_repair_states`.

#### Сохранение генеративных экземпляров

`res://scripts/game_state.gd`, версия сохранения 15:

- `job_repair_states`, `job_reports`, `pending_job_report`;
- `campaign_seed`, `next_generated_job_index`, `generated_jobs`;
- `financial_ledger`, назначения и прогресс сотрудников;
- миграции старых полей и materialized generated job.

`res://scripts/generated_job_generator.gd` уже показывает правильные технические идеи: детерминированный seed, сохранённый экземпляр, `generator_version`, проверка доступного плана до публикации.

### 3.2. Существует разрозненно

- Один и тот же смысл представлен то числом (`temperature`), то булевым флагом (`bath_still_frozen`), то тегом (`melted`), то `visual_state`.
- `damage` присутствует у большинства объектов, но шкала, предел и связь с `durability` неодинаковы.
- Материал шкафа задан тегом `wooden` только в `generative_job_catalog.gd`; материал крана следует из логики, но не хранится как поле.
- Содержимое есть только у шкафа; лёд и листья моделируются специальными флагами, а не дочерними экземплярами/частями.
- Физические намерения богато реализованы только у шкафа (`hold`, `release`, `move_left`, `move_kitchen`, `break_legs`). Завешивание, ловушка и открытие/закрытие оформлены отдельными action ID.
- Follow-up хранится внутри итогового отчёта, но единой очереди событий, времени срабатывания и статуса обработки нет.
- Реакции жильца на ущерб есть, но постоянной памяти resident↔employee нет.
- Визуальные состояния существуют в сценах, но нет машиночитаемого контракта «какие поля состояния гарантированно визуализируются».

### 3.3. Пока отсутствует

- Типизированные `Resource`-определения материалов, объектов, частей, воздействий и правил.
- Постоянный `ObjectInstance` с уникальным ID на всю кампанию.
- Происхождение каждого активного состояния.
- Единый неизменяемый `ActionEvent` с временем, причиной, before/after и связью с заявкой.
- `ConsequenceRule` и очередь отложенных событий.
- Общий планировщик разрешимости по текущей бригаде, доступу в квартиру и оборудованию.
- Стабильный профиль характера оживлённого объекта и модель переговоров.
- Память жильцов, запрет входа, предпочтительный сотрудник и восстановление доверия.
- Раздельные профессиональное доверие, личная симпатия и романтический интерес.
- Защита от причинных циклов и повторной генерации одной и той же жалобы.
- Asset gating как обязательная часть публикации заявки.

## 4. Обязательная целевая модель

### 4.1. Слои

```text
RoomDefinition (авторская сцена)
  └─ ObjectDefinition (постоянный объект)
       ├─ MaterialDefinition[]
       ├─ ObjectPartDefinition[]
       ├─ FunctionDefinition[]
       └─ VisualStateContract

WorldState
  └─ ObjectInstance
       ├─ PropertySet
       ├─ StateInstance[] + StateOrigin
       ├─ AnimacyProfile?
       └─ ActionEvent references

ActionRequest + intent
  → InteractionRule[]
  → StateTransition[]
  → ActionEvent
  → ConsequenceRule[]
  → Immediate/DeferredEvent
  → generated JobInstance
```

Комната определяет, какие объекты существуют и где они могут находиться. Генератор выбирает только совместимую аномалию/последствие для конкретного экземпляра.

### 4.2. Рекомендуемые Godot Resource-классы

Пути — предлагаемые, их пока нет.

```gdscript
# res://scripts/systemic/data/material_definition.gd
class_name MaterialDefinition
extends Resource

@export var id: StringName
@export var tags: PackedStringArray
@export var heat_capacity: float
@export var ignition_temperature: float = INF
@export var melt_temperature: float = INF
@export var freeze_brittleness_threshold: float = -INF
@export var conducts_magic: bool
@export var combustible: bool
```

```gdscript
class_name ObjectDefinition
extends Resource

@export var id: StringName
@export var display_name_key: StringName
@export var material_ids: PackedStringArray
@export var base_mass: float
@export var base_durability: float
@export var anchored: bool
@export var movable: bool
@export var animatable: bool = true
@export var part_definitions: Array[ObjectPartDefinition]
@export var function_definitions: Array[FunctionDefinition]
@export var visual_contract_id: StringName
```

```gdscript
class_name ObjectPartDefinition
extends Resource

@export var id: StringName               # basin_ice, gargoyle_leaves, dishes
@export var material_id: StringName
@export var detachable: bool
@export var mass: float
@export var contained_by_part: StringName
@export var anchored: bool
@export var visual_state_keys: PackedStringArray
```

```gdscript
class_name FunctionDefinition
extends Resource

@export var id: StringName               # dispense_water, drain_rain, contain_dishes
@export var controlling_part_id: StringName
@export var enabled_by_default: bool
@export var output_kind: StringName       # ordinary_water, lava, rain_drainage
```

Вода не является магией. `ordinary_water` появляется только как выход `dispense_water`, дождь — как источник окружения, вода после нагрева — как результат таяния `ice`. Магическими могут быть причина замерзания, замена выходного вещества или управление функцией.

## 5. Постоянный ObjectInstance и происхождение состояния

```gdscript
class_name ObjectInstanceState
extends Resource

@export var instance_id: StringName       # old_quarter_5.bathroom.faucet
@export var definition_id: StringName
@export var room_instance_id: StringName
@export var current_zone: StringName
@export var numeric_properties: Dictionary
@export var flags: Dictionary
@export var parts: Dictionary             # part_instance_id -> PartInstanceState
@export var active_states: Dictionary     # state_id -> StateInstance
@export var animacy_profile: Dictionary
@export var revision: int
```

Минимальные общие свойства:

- `mass`, `durability`, `damage`, `temperature`, `magic_level`;
- `anchored`, `movable`, `destroyed`;
- `position_zone`, если объект допускает зоны;
- `functions`, например `dispense_water = enabled`;
- `contents` как части/вложенные экземпляры, а не только строка.

Каждое состояние хранит происхождение:

```gdscript
{
  "state_id": "cold_trace",
  "magnitude": 4.0,
  "created_at_day": 1,
  "created_at_minutes": 615,
  "origin_event_id": "event.lava_leak.freeze.17",
  "origin_job_id": "lava_leak",
  "origin_actor_id": "liliya",
  "cause_chain_id": "chain.old_quarter_5.faucet.1",
  "expires_at": -1,
  "residual": true
}
```

Это позволяет объяснить игроку и отладчику, почему ванна замёрзла и кто оставил след.

## 6. Действия и физические намерения

Способность сотрудника и намерение разделяются.

```text
physical_interaction + hold
physical_interaction + carry(target_zone)
physical_interaction + break(part_id)
repair + anchor(target_anchor)
physical_interaction + cover(target, cloth)
equipment + install(trap, zone)
physical_interaction + open(part)
physical_interaction + close(part)
telekinesis + extract(part)
telekinesis + carry(object_or_part, zone)
heat + target
freeze + target
animate + target
talk + request_id
```

`ActionRequest` содержит `actor_id`, `ability_id`, `intent_id`, `target_instance_id`, необязательный `target_part_id`, `target_zone`, `tool_instance_id`, `job_id`.

### Телекинез

Обязательное правило:

- материальный и отделимый объект/часть переносится, если его эффективная масса не превышает способность сотрудника;
- закреплённый объект не переносится штатно;
- попытка вырвать закреплённое создаёт повреждение крепления/стены только при явно выбранном разрушительном намерении;
- лёд из ванны, листья из пасти и посуда — части с собственной массой и `detachable = true`;
- перенос всегда ограничен зонами авторской комнаты.

Текущий `ObjectInteractionRules.apply_telekinesis()` следует расширять, а не обходить уникальными ветками.

## 7. Универсальные материалы, воздействия и переходы

| Воздействие | Предусловия | Универсальный результат | Примечание |
|---|---|---|---|
| Нагрев | Материальный объект | повышает `temperature` | Сила зависит от действия и материала |
| Нагрев льда | часть/состояние `ice` | уменьшает массу льда, создаёт обычную воду | Вода не магия; источник — таяние |
| Нагрев металла | material=`metal` | нагрев → деформация → плавление → уничтожение функции/объекта | Пороги из `MaterialDefinition` |
| Нагрев горючего | `combustible`, достигнут порог | `burning`, затем `scorched`, damage | Дерево шкафа — первый адаптер |
| Заморозка воды | имеется обычная вода | создаёт часть/состояние `ice` | Нужен источник воды: кран, дождь, таяние до повторного замерзания |
| Заморозка огня | `burning` | снижает температуру; при пороге снимает огонь | Сажа и ущерб остаются |
| Заморозка материала | материальный объект | `frozen`; некоторые материалы получают `brittle` | Не вся заморозка создаёт лёд |
| Антимагия | `magic_level > 0` или magical state | ослабляет/снимает магическое состояние | Не ремонтирует физический ущерб |
| Ремонт | ремонтопригодная часть, навык/инструмент | восстанавливает durability/function | Не обязан снимать магию |
| Физический удар | материальный объект | damage по силе и хрупкости | Может отделить часть или уничтожить |
| Удержание | подвижный объект, достаточная сила | `held`, временно не движется | Не постоянное решение |
| Перенос | movable/отделим, масса допустима | меняет разрешённую зону | Только в авторской сцене |
| Закрепление | допустимое крепление/зона | `anchored = true` | Снимает движение, но не сознание |
| Завешивание | зеркало поддерживает `coverable`, есть полотно | `covered = true` | Реальное свойство зеркала, не общий статус всех объектов |
| Установка ловушки | допустимая зона и предмет | создаёт установленный equipment instance | Не воздействует без цели |
| Открыть/закрыть | есть часть/функция | меняет функцию/портал/дверцу | Требуется конкретная часть |
| Оживление | любой материальный объект, есть визуальный допуск | создаёт постоянный `AnimacyProfile`, включает сознание и управление функциями | Физическое движение не обязательно |

## 8. ActionEvent и журнал событий

Текущий `action_log` мигрирует в append-only журнал:

```gdscript
class_name ActionEvent
extends Resource

@export var event_id: StringName
@export var cause_event_id: StringName
@export var cause_chain_id: StringName
@export var day: int
@export var time_minutes: int
@export var job_instance_id: StringName
@export var room_instance_id: StringName
@export var actor_id: StringName
@export var target_instance_id: StringName
@export var target_part_id: StringName
@export var ability_id: StringName
@export var intent_id: StringName
@export var parameters: Dictionary
@export var before_revision: int
@export var transitions: Array[Dictionary]
@export var result_tags: PackedStringArray
```

Событие не редактируется после записи. Состояние объекта — результат последовательного применения событий плюс периодические snapshot-ы. Для игрового сохранения допустимо хранить текущий snapshot и журнал после snapshot, а полный журнал кампании — отдельно для отчётов и причинности.

## 9. ConsequenceRule и очередь отложенных событий

```gdscript
class_name ConsequenceRule
extends Resource

@export var id: StringName
@export var priority: int
@export var trigger_event_tags: PackedStringArray
@export var required_state_query: Dictionary
@export var delay_min_minutes: int
@export var delay_max_minutes: int
@export var emitted_event_type: StringName
@export var cooldown_days: int
@export var max_per_cause_chain: int = 1
```

`DeferredEvent`:

```text
event_id, rule_id, due_day, due_minutes, priority,
source_event_id, cause_chain_id, target_object_id,
payload, status(pending/claimed/cancelled/resolved), attempt_count
```

Порядок обработки:

1. Просроченные опасные технические последствия.
2. Причинные follow-up прошлых работ.
3. Социальные последствия и жалобы.
4. Только затем новые случайные аномалии.

Если новое действие устранило причину, ожидающее событие отменяется с записью причины отмены.

## 10. Генерация заявки из состояния мира

Генератор не создаёт объект. Он выполняет запрос:

1. Выбирает квартиру/комнату с существующим `RoomInstance`.
2. Получает её постоянные `ObjectInstance`.
3. Сначала забирает подходящее `DeferredEvent`.
4. Если последствий нет, рассматривает только аномалии из белого списка объекта и комнаты.
5. Проверяет, что требуемые начальное, промежуточные, ошибочные и итоговые состояния имеют visual contract.
6. Материализует цели из фактического состояния, а не сбрасывает объект к шаблону.
7. Планировщик доказывает минимум один доступный безопасный путь.
8. Учитывает доступ жильца, запреты сотрудников, оборудование, занятость и срок.
9. Сохраняет `JobInstance` с source event и snapshot revision.

Одна аномалия считается новой только если отличается одновременно:

- поведением;
- визуалом;
- набором решений;
- последствиями.

Поэтому одержимость не публикуется как переименованное оживление.

## 11. Жизненный цикл заявки

```text
candidate
→ asset_gated
→ solvability_validated
→ queued
→ published
→ assigned
→ access_validated
→ in_progress
→ resolved | failed | expired
→ consequences_scheduled
→ archived
```

При назначении повторно проверяются доступ в квартиру и разрешимость. Если предпочтительный сотрудник недоступен, это пожелание, а не обязательное условие. Если все доступные решения заблокированы, заявка не публикуется либо предлагает действие восстановления доступа.

## 12. Оживление, характер и переговоры

### 12.1. Семантика

Любой материальный объект принципиально оживляем, но публикация требует визуального допуска. Оживление даёт:

- сознание и память;
- характер;
- речь/звуковую реакцию;
- управление штатными функциями объекта;
- физическое движение только если конструкция и ассеты его поддерживают.

Оживлённый кран может говорить и управлять потоком, соглашаться или отказываться, не отрываясь от стены. Для обычной воды потребуется отдельный визуал струи; звук уже существует: `res://assets/audio/water.ogg`, подключён в `audio_manager.gd` как `RUNNING_WATER`.

### 12.2. Стабильный AnimacyProfile

При первом оживлении профиль генерируется один раз из seed объекта и сохраняется:

```text
profile_id
temperament: calm/proud/anxious/playful/grumpy
cooperation_base: -100..100
talkativeness: 0..100
noise_preference: 0..100
owner_attachment: -100..100
employee_attitudes: employee_id -> score
promises: []
grievances: []
created_by_event_id
```

Повторный диалог не перебрасывает характер. Решение рассчитывается из:

```text
cooperation = base temperament
            + отношение к просителю
            + соответствие просьбы штатной функции
            + выполненные обещания
            - прошлый ущерб/угрозы
            - конфликт с желаниями владельца
```

Результат переговоров: `agree`, `agree_with_condition`, `refuse`, `become_hostile`. Он сохраняется как событие и меняет профиль.

## 13. ResidentMemory и отношения

```gdscript
class_name ResidentEmployeeRelation
extends Resource

@export var resident_id: StringName
@export var employee_id: StringName
@export var professional_trust: int
@export var personal_affinity: int
@export var romantic_interest: int
@export var access_status: StringName      # allowed, warned, banned
@export var preference_weight: int
@export var memories: Array[Dictionary]
```

Шкалы разделены:

- **professional_trust** — качество, аккуратность, соблюдение сроков;
- **personal_affinity** — тон общения и личная симпатия;
- **romantic_interest** — отдельная шкала, доступная только разрешённым взрослым парам.

Ущерб обычно бьёт по профессиональному доверию. Грубость — по личной симпатии. Романтическая шкала никогда не выводится из общего высокого доверия автоматически.

### Доступ в квартиру

Перед отправкой бригады:

- `banned` запрещает конкретному сотруднику вход;
- UI объясняет причину и предлагает заменить сотрудника;
- если без него нет решения, заявка не должна становиться неразрешимой: нужен другой план, снятие запрета или предварительная заявка восстановления доверия;
- запрет имеет источник, условия пересмотра и не исчезает случайно.

Восстановление доверия: компенсация, официальное извинение, успешная работа другого типа, выполнение просьбы жильца или истечение мягкого предупреждения. Для жёсткого запрета требуется явное событие примирения.

Предпочтительный сотрудник добавляет бонус доверию/оплате/реплике, но не блокирует заявку.

## 14. Банки диалогов

Тексты остаются авторскими и согласуемыми. Рекомендуемая структура `DialogueBank`:

```text
bank_id
speaker_kind: resident/employee/object
speaker_id
target_id or allowed_pair_id
tone: professional/friendly/flirt/angry
context_tags[]
required_relation_ranges
forbidden_tags[]
lines[]
cooldown
once_per_chain
```

Условия:

- флирт выбирается только при `allowed_pair_id`, подтверждённом взрослом статусе обоих персонажей и достаточном `romantic_interest`;
- для Элеоноры и Бориса можно подготовить отдельный согласуемый банк профессиональных, дружеских и затем кокетливых реплик;
- для Ники используется дружеский/профессиональный тон без флирта независимо от общей симпатии;
- отсутствие подходящей фразы всегда ведёт к нейтральному fallback, а не к ослаблению ограничений;
- выбранная реплика может быть детерминирована контекстом и cooldown, но не менять отношения случайно сама по себе.

## 15. Разрешимость и планировщик

Планировщик работает по абстрактному состоянию и тем же правилам, что runtime.

Вход:

- snapshot объектов и частей;
- доступные сотрудники, навыки, сила/лимит массы;
- оборудование;
- допуск resident↔employee;
- доступные зоны комнаты;
- оставшееся время;
- visual-gated действия.

Выход:

- минимум один безопасный план;
- альтернативные планы;
- стоимость времени/ресурсов;
- обязательные сотрудники;
- доказательство, что итог удовлетворяет цели и не создаёт немедленную неразрешимую катастрофу.

Поиск: ограниченный BFS/A* по дискретным состояниям с canonical hash. Разрушительные терминальные действия допускаются как проигрышный исход, но не засчитываются безопасным планом.

После назначения план проверяется повторно. Внутренние найденные планы игроку не показываются.

## 16. VisualStateContract и asset gating

Для каждого шаблона сцены:

```text
contract_id
scene_path
object_instance_slot
supported_state_queries[]
required_assets[]
transition_presentations[]
audio_cues[]
fallback_policy
```

Публикация разрешена, только если визуально читаются:

- начальная проблема;
- каждое обязательное промежуточное состояние;
- безопасный итог;
- ключевой разрушительный итог;
- остаточное состояние, которое породит follow-up.

Наличие поля в Dictionary не считается визуалом. Универсальный overlay допустим только после ручной настройки размера и позиции в конкретной сцене.

## 17. Защита от циклов и повторов

- `cause_chain_id` наследуется всеми последствиями одной исходной причины.
- Каждое правило имеет `max_per_cause_chain` и cooldown.
- Сигнатура события: `rule_id + target_instance_id + normalized_state_origin`.
- Повтор с той же сигнатурой не ставится, пока прежний pending/resolved event не вышел из cooldown.
- Максимальная глубина причинной цепочки MVP: 4.
- Терминальный объект не получает аномалии, требующие его функций.
- Если follow-up возвращает состояние к предку цепочки без нового внешнего события, он подавляется как цикл.
- Последствия имеют приоритет над случайным контентом, но дневной лимит не даёт одной квартире занять всю кампанию.

## 18. Диагностируемость

Debug-интерфейс, скрытый в обычной игре, должен показывать:

- ID комнаты, объекта, job instance и cause chain;
- текущую revision и активные состояния с origin event;
- почему кандидат заявки принят или отклонён;
- отсутствующий ассет/visual query;
- найденные безопасные планы;
- pending consequences и cooldown;
- изменение памяти жильца;
- replay ActionEvent до текущего состояния.

Лог генерации должен быть детерминированным по seed и snapshot revision.

## 19. Сохранение и миграция

Новая версия сохранения добавляет:

```text
world_objects
action_events
event_snapshots
deferred_events
cause_chains
resident_relations
animacy_profiles
generator_history
dialogue_cooldowns
```

Миграция выполняется по этапам:

1. Текущие `job_repair_states` остаются источником истины для старых ручных заявок.
2. Для объектов завершённых/активных заявок создаются стабильные instance ID.
3. Старый `action_log` оборачивается в legacy ActionEvent без выдуманного времени.
4. Существующий `follow_up` превращается в claimed/resolved DeferredEvent.
5. Отсутствующие origin помечаются `legacy_unknown`, а не угадываются.
6. `generated_jobs` продолжают загружаться через прежний адаптер до миграции конкретного шаблона.

Каждая миграция идемпотентна и тестируется загрузкой реальных старых fixtures.

## 20. End-to-end: цепочка лавового крана

1. В `old_quarter_5.bathroom` существует постоянный металлический кран с функцией `dispense_water`.
2. Начальная заявка добавляет состояние `lava_substitution`: функция вместо обычной воды выдаёт лаву; растут температура и давление.
3. Лилия применяет `freeze`.
4. Правила снижают температуру, прекращают лавовый поток и создают остаточное магическое состояние `cold_trace` с origin на конкретное действие Лилии.
5. `ActionEvent` сохраняет before/after, сотрудника, кран и cause chain.
6. `ConsequenceRule cold_trace_freezes_dispensed_water` ставит событие на следующее утро.
7. Утром штатная функция крана выдаёт обычную воду. Вода не магия; из-за `cold_trace` она превращается в лёд в ванне.
8. Генератор создаёт заявку «вода замерзает» из реального состояния крана и ванны, связывает её с исходной заявкой.
9. В новой заявке сотрудник оживляет кран. Создаётся и сохраняется `AnimacyProfile`; кран остаётся закреплённым, но получает речь и управление `dispense_water`.
10. Через переговоры кран соглашается прекратить поток, пока сотрудник снимает холодный след. Результат зависит от постоянного характера и прошлых действий.
11. Холодный след удалён, лёд растоплен или извлечён, обычная вода снова течёт (`water.ogg` и новый визуал обычной струи).
12. Оживление не снимается автоматически: кран остаётся живым как постоянное состояние.
13. Через несколько дней `talkativeness` и накопленные события разговоров/пения пересекают порог раздражения владельца.
14. Очередь создаёт социальную заявку: кран разговаривает и поёт по ночам. Это новая ситуация, потому что отличается поведением, решениями и последствиями, а не только текстом карточки.

## 21. End-to-end: память Элеоноры

### Негативная ветка — Лилия

1. Лилия нагревает деревянный шкаф; он загорается и уничтожается.
2. ActionEvent связывает Лилию, `heat`, пожар, пепел и компенсацию.
3. Память Элеоноры получает `destroyed_wardrobe_by_heat`: большой минус professional trust, личное раздражение и `access_status = banned` для Лилии.
4. В следующей заявке UI сообщает: Элеонора просит не присылать Лилию.
5. Если игрок назначает Лилию, проверка доступа не позволяет начать поездку/войти в квартиру и предлагает заменить состав.
6. Планировщик заранее не считает планы с Лилией доступными.
7. Восстановление возможно через компенсацию и отдельное официальное извинение; после согласованного события запрет меняется на `warned`, затем успешная аккуратная работа может вернуть `allowed`.

### Положительная ветка — Борис

1. Борис аккуратно ремонтирует ножки и закрепляет шкаф без ущерба посуде.
2. Элеонора получает память `quality_wardrobe_repair`: рост professional trust и небольшой рост personal affinity.
3. Для следующей заявки `preference_weight` Бориса повышается; в карточке может появиться просьба прислать его.
4. Отсутствие Бориса не блокирует заявку, если планировщик нашёл другой безопасный путь.
5. Профессиональные и дружеские реплики доступны по соответствующим шкалам.
6. Кокетливая реплика возможна только из отдельного согласованного банка пары Элеонора↔Борис, если оба взрослые, пара разрешена и достигнут порог romantic interest.
7. Ника при высокой личной симпатии получает только дружеский банк без флирта.

## 22. Тестовая стратегия

### Unit

- переходы материалов на порогах температуры;
- вода появляется только от источника/таяния;
- масса, отделимость и anchored для телекинеза;
- оживление создаёт один стабильный профиль;
- переговоры детерминированы состоянием, не случайны на каждый клик;
- правила памяти меняют правильную шкалу;
- cycle signature и cooldown.

### Property-based / генеративные

- любое опубликованное задание имеет visual contract;
- минимум один безопасный план существует и воспроизводится runtime-правилами;
- один seed + snapshot дают одинаковый JobInstance;
- невозможные пары объект×аномалия никогда не публикуются;
- follow-up не превышает глубину и лимит цепочки.

### Интеграционные

- полная цепочка лавовый кран → холодный след → лёд → оживлённый разговорчивый кран;
- шкаф: пожар → запрет Лилии → отказ допуска;
- шкаф: качественный ремонт → предпочтение Бориса;
- сохранение/загрузка между каждым этапом;
- миграция v15;
- старые ручные smoke-тесты проходят без изменения поведения.

### Визуальные

- screenshot-сравнение каждого состояния visual contract;
- проверка overlay на реальном размере объекта;
- звук начинается/останавливается вместе с состоянием;
- отсутствие технических тегов в пользовательском UI.

## 23. Поэтапное внедрение

### Этап 0 — контракты, без изменения поведения

- Ввести типы данных и registry рядом с текущими Dictionary.
- Описать материалы `metal`, `wood`, `stone`, `glass`, `ice`, `leaves`.
- Описать visual contracts существующих сцен.
- Добавить диагностический валидатор каталогов.

### Этап 1 — события и происхождение

- Унифицировать ActionEvent, сохраняя старый `action_log` через адаптер.
- Добавить ObjectInstance ID к лавовому крану и шкафу.
- Записывать origin для cold trace, burning, damage.

### Этап 2 — очередь последствий

- Перенести два существующих follow-up (`frozen_bath`, `escaped_ghost`) в DeferredEvent без изменения сюжета.
- Добавить приоритет, cooldown и cycle guard.

### Этап 3 — универсальные воздействия

- Общие heat/freeze/fire и telekinesis для крана/шкафа/льда/листьев.
- Существующие симуляции вызывают правила через адаптер и сохраняют свои UI/итоги.

### Этап 4 — память жильцов и доступ

- ResidentEmployeeRelation, изменения после отчёта.
- Запрет входа и предпочтительный сотрудник.
- Сценарии Лилии и Бориса у Элеоноры.

### Этап 5 — оживление и переговоры

- Стабильный AnimacyProfile.
- Сначала шкаф/гаргулья с готовыми визуалами.
- Кран только после появления визуала обычной воды и согласованных реплик.

### Этап 6 — системный генератор

- Выбор последствия или whitelist anomaly для постоянного объекта.
- Планировщик, asset gating, anti-repeat history.
- Минимум три механически разные ситуации в кампании.

### Будущие расширения, не обязательные для MVP

- более сложные социальные сети между жильцами;
- несколько одновременно спорящих оживлённых объектов;
- ремонт частей стен/креплений как самостоятельных объектов;
- одержимость после отдельного дизайна поведения и набора ассетов;
- расширенные романтические линии после отдельного сценарного согласования.

## 24. Ключевое архитектурное решение

Системная генерация — не декартово произведение «комната × предмет × магия». Это выбор допустимого события для постоянного экземпляра в авторской комнате с последующим применением общих физических правил, проверкой визуального контракта, разрешимости и причинности. Благодаря адаптерам текущие ручные заявки остаются рабочими и постепенно становятся источниками постоянного состояния мира.
