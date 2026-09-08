# SkillReg

---

Создание централизованного хранилища через SkillReg.

## Prerequisites

- Node.js 18+ (проверить: `node --version`)
- Пакетный менеджер: npm, pnpm или yarn
- SkillReg account / test organization — зарегистрировать на [skillreg.dev](https://skillreg.dev)

## Установка и первичная настройка CLI

Создайте организацию в UI https://app.skillreg.dev

```bash
npm install -g @skillreg/cli
skillreg --version
```

### Интерактивный setup wizard

```bash
skillreg setup
```

Это не просто логин — мастер за 4 шага сразу настраивает CLI под ваш повседневный сценарий использования:

```
Welcome to SkillReg! Let's set up your CLI.

Step 1/4 — Authentication
  How do you want to log in?
  ❯ Browser login (recommended)
    Paste a token manually
  ✓ Logged in successfully!

Step 2/4 — Default organization
  ✓ Default org set to: my-company

Step 3/4 — Default agent
  Which AI agent do you use?
  ❯ Claude (recommended)
    Codex
    Cursor
  ✓ Default agent set to: claude

Step 4/4 — Install scope
  Where should skills be installed by default?
  ❯ Project (recommended)
    User (global)
  ✓ Default scope set to: project
```

Важная деталь: **`skillreg setup` нужно выполнить один раз на машину** — дальше настройки сохраняются в `~/.skillreg/config.json`, и вам не придётся каждый раз указывать `--org`. Для теста имеет смысл всё же явно указывать `--org <your-org>` в командах ниже — так вы будете уверены, что тестируете нужную organization, а не ту, что стала default'ной случайно.

Проверить, что вы залогинены и под каким пользователем:
```bash
skillreg whoami
```

---

## Создание скилла

```bash
skillreg init poc-alpha
```

Команда не просто создаёт пустую папку — она сразу генерирует готовый шаблон `SKILL.md` с YAML frontmatter:

```
✓ Created skill: poc-alpha/
  └── SKILL.md

Next steps:
  1. Edit poc-alpha/SKILL.md
  2. skillreg push poc-alpha --org <your-org>
```

Содержимое `poc-alpha/SKILL.md` сразу после `init`:
```yaml
---
name: "poc-alpha"
description: ""
metadata:
  author: ""
  version: "0.1.0"
---

# poc-alpha

## Instructions

[Add your skill instructions here]

## Examples

[Add usage examples here]
```

Отредактировать `poc-alpha/SKILL.md` — заполнить `description`, `## Instructions` и `## Examples` реальным содержимым тестового скилла. **Поле `name` в frontmatter должно совпадать** с именем, под которым вы будете публиковать (по умолчанию — имя директории) — иначе CLI выдаст предупреждение о несоответствии.

### Publish V1

```bash
skillreg push ./poc-alpha --org <your-org>
```

Под капотом `push` выполняет три шага, о которых стоит явно знать при тестировании (это влияет на то, что можно и что нельзя протестировать через содержимое файла):

1. **Validate** — проверяет валидность `SKILL.md`, формат имени скилла, корректность semver-версии.
2. **Package** — **вырезает из `.md`-файлов любые секции с инжектированными переменными окружения** (чтобы секреты никогда не попадали в реестр), затем упаковывает всё в `.tar.gz` с SHA-256 чексуммой.
3. **Upload** — заливает архив в реестр под указанную organization, версию и distribution tag (по умолчанию `latest`).

Ожидаемый вывод:
```
Packaging poc-alpha@0.1.0...
  ✓ Pushed poc-alpha@0.1.0
    SHA256: a1b2c3d4...
```

**Если в organization включён approval workflow** — версия попадёт в реестр со статусом *pending*, а не сразу станет доступна для `pull`. Это прямо связано с разделом "Approval workflow" ниже — стоит сразу иметь это в виду и не удивляться, если `pull` на этом этапе ничего не найдёт.

Полезный флаг для безопасного тестирования перед реальной публикацией:
```bash
skillreg push poc-alpha --org <your-org> --dry-run
```
Покажет, что будет запушено (версия, количество файлов, размер, SHA256), не отправляя ничего на сервер.

Проверить список опубликованных скиллов организации:
```bash
skillreg list --org <your-org>
```
Вывод — таблица `NAME / VERSION / DOWNLOADS / UPDATED`.

### Search/info

```bash
skillreg search "poc alpha"
```
Полнотекстовый поиск по имени, описанию и тегам **среди публичных** скиллов реестра (обратите внимание — для приватных organization-скиллов основной способ найти свои — `skillreg list`, а не `search`).

```bash
skillreg info @<your-org>/poc-alpha
```
Покажет версию, видимость (`public`/`private`), число установок, дату создания/обновления, SHA256 и готовую install-команду — удобно сверить с тем, что вы ожидаете увидеть после `push`.

---

## Install latest

```bash
skillreg pull @<your-org>/poc-alpha \
  --agent cursor \
  --scope project
```

Ожидаемый вывод:
```
Pulling poc-alpha@latest from @<your-org>...
  ✓ Installed to .cursor/skills/poc-alpha
```

**Куда физически кладётся скилл** зависит от комбинации `--agent`/`--scope` — стоит явно свериться с таблицей путей, чтобы не искать файл не в той папке при проверке:

| Agent | Project scope (default) | User scope |
|---|---|---|
| Claude | `.claude/skills/<name>` | `~/.claude/skills/<name>` |
| Codex | `.codex/skills/<name>` | `~/.codex/skills/<name>` |
| Cursor | `.cursor/skills/<name>` | `~/.cursor/skills/<name>` |

Все поддерживаемые agents одной командой:
```bash
skillreg pull @<your-org>/poc-alpha --agent all
```
Установит сразу в `.claude/skills/`, `.codex/skills/` и `.cursor/skills/` одновременно.

**Отдельный момент, которого нет в исходном гайде, но важен для реалистичного PoC:** если ваш `SKILL.md` объявляет переменные окружения (секция `env:` во frontmatter), `pull` запустит **интерактивный wizard**, который запросит значение для каждой переменной — обязательные нельзя пропустить, опциональные можно оставить пустыми (сработает default, если он объявлен). Значения сохраняются **локально** в `~/.skillreg/env/<org>/variables.env` и никогда не уходят в реестр. Если хотите протестировать голую установку без этого диалога — используйте флаг `--no-env`.

Local inventory:
```bash
skillreg local
```
Покажет все локально установленные скиллы по всем агентам сразу, сгруппированные по agent+scope:
```
Claude (user scope)
  @acme/deploy-k8s          v2.1.0

Claude (project scope)
  @acme/lint-config          v3.0.0
```
Флаг `--path` дополнительно покажет полный путь к файлам каждого скилла — полезно, если нужно свериться вручную, что именно легло на диск.

---

## Версии

Конкретная:
```bash
skillreg pull @<your-org>/poc-alpha@1.0.0
```

Semver range (CLI сам резолвит лучшую подходящую версию по стандартным правилам semver — `^`, `~`, `>=` и т.д.):
```bash
skillreg pull @<your-org>/poc-alpha@^1.0.0
```
При использовании range CLI сначала показывает, во что он резолвится, и только потом качает:
```
Resolving poc-alpha@^1.0.0 from @<your-org>...
  → Resolved to 1.3.2
Pulling poc-alpha@1.3.2 from @<your-org>...
  ✓ Installed to .claude/skills/poc-alpha
```
Если ни одна опубликованная версия не подходит под диапазон — CLI завершится с ошибкой и **покажет список доступных версий**, чтобы вы могли скорректировать запрос. Стоит специально протестировать этот негативный сценарий (например, запросить `@^99.0.0`) — так вы увидите, насколько понятна ошибка для обычного сотрудника.

Выпустить новую версию — два способа:

**Явно указать версию:**
```bash
skillreg push ./poc-alpha --org <your-org> --version 2.0.0
```

**Автоматически увеличить (то, что описано в исходном гайде):**
```bash
skillreg push ./poc-alpha --bump patch --org <your-org>
```
`--bump` сам читает текущую версию из frontmatter `SKILL.md`, увеличивает её и **записывает новое значение обратно в файл** — то есть после этой команды локальный `SKILL.md` тоже изменится, это не только серверная операция. Доступные значения:
- `--bump patch` — `0.1.0` → `0.1.1` (багфиксы)
- `--bump minor` — `0.1.0` → `0.2.0` (новая функциональность, обратно совместимая)
- `--bump major` — `0.1.0` → `1.0.0` (breaking changes)

Обновить consumer до latest повторным pull:
```bash
skillreg pull @<your-org>/poc-alpha \
  --agent cursor \
  --scope project
```
Проверить, что содержимое V2 пришло локально — откройте установленный файл и сверьте текст/версию во frontmatter с тем, что вы поменяли перед вторым `push`.

---

## Mass install

```bash
skillreg pull-all \
  --org <your-org> \
  --agent all \
  --scope project
```

Ожидаемый вывод (для организации с несколькими скиллами):
```
Pulling 4 skill(s) from @<your-org>...

  ✓ react-testing@1.3.2
  ✓ code-review@0.5.0
  ✓ db-migrations@2.1.0
  ✓ api-design@1.0.0

Done: 4 pulled, 0 failed
```

`pull-all` тянет **все опубликованные скиллы** организации разом, каждый на своей latest-версии — в отличие от `pull` для одного конкретного скилла. Это отдельный тест против GitLab-варианта (раздел 3, RoleCraft): насколько удобно сотруднику поставить весь approved набор команды одной командой, без необходимости перечислять каждый скилл вручную (как пришлось бы делать через `rolecraft bundle owner/repo1 owner/repo2 ...`).

Обратите внимание на итоговую строку `Done: X pulled, Y failed` — специально протестируйте сценарий, где часть скиллов **не** должна быть доступна для установки (например, если approval workflow ещё не пройден для одной из версий, см. следующий раздел) — так вы увидите, корректно ли `pull-all` продолжает работу и репортит частичный отказ, а не падает целиком.

---

## Approval workflow

Включить approval в тестовой organization (это делается в веб-интерфейсе organization settings, не через CLI).

**Последовательность:**
1. Developer публикует новую version (`skillreg push ...` из раздела выше).
2. **До approve** пользователь пытается pull:
   ```bash
   skillreg pull @<your-org>/poc-alpha
   ```
   **Ожидаемое поведение (PASS):** команда должна либо явно сообщить, что версия в статусе pending и недоступна, либо просто не найти версию для установки — зафиксируйте точный текст ошибки/сообщения, это важно для документирования UX сотрудников.
3. Admin approve — через веб-интерфейс SkillReg (organization dashboard), находит версию в очереди на модерацию и одобряет.
4. Пользователь повторяет тот же самый `pull` — теперь должен пройти успешно.
5. Зафиксировать expected behavior и audit trail — проверьте в веб-интерфейсе, есть ли запись о том, кто и когда approve'ил версию (это governance-функция, которая напрямую отличает SkillReg от голого git-репозитория — фиксация факта одобрения человеком).

---

## CI token

```bash
skillreg token create --name "ci-deploy" --scopes read,write --org <your-org>
```

Ожидаемый вывод:
```
✓ Token created successfully!

  Name:   ci-deploy
  Scopes: read, write
  Token:  sr_live_a1b2c3d4e5f6g7h8i9j0...

  ⚠ Copy this token now — it will not be shown again.
```

**Критически важно:** полное значение токена показывается **только один раз**, в момент создания. Если не скопировали сразу — токен придётся отзывать и создавать новый, восстановить его нельзя. Обязательно сохраните его в безопасное место (секрет-менеджер CI, а не в открытый текстовый файл) прямо в момент теста.

Список токенов организации:
```bash
skillreg token list --org <your-org>
```
```
NAME          PREFIX         SCOPES        LAST USED
ci-deploy     sr_live_a1b2   read, write   2 hours ago
```
В списке показывается только **префикс** токена, не полное значение, это ожидаемо.

### Модель scopes — важно протестировать разграничение

- **`read`** — pull, search, list, info. Ничего писать в реестр нельзя.
- **`write`** — включает всё из `read`, плюс `push`.
- **`admin`** — включает всё из `write`, плюс управление токенами и настройками организации.

Создать token с минимально достаточными scopes и проверить non-interactive `skillreg push` из CI — то есть создайте токен именно со scope `write` (не `admin`, следуя принципу минимальных привилегий), передайте его в переменной окружения CI-раннера и выполните `push` без интерактивного логина:
```bash
SKILLREG_TOKEN=sr_live_... skillreg push ./poc-alpha --org <your-org>
```
(имя переменной окружения стоит уточнить на странице **Environment Variables** в документации SkillReg — здесь используется предполагаемое стандартное название, отличное от env-переменных самого скилла, описанных выше)

**Дополнительно стоит протестировать негативный сценарий:** попробуйте выполнить `push` токеном со scope только `read` — команда должна **отказать** с понятной ошибкой прав доступа. Это прямая проверка того, что scopes реально соблюдаются на сервере, а не только декларативны в CLI.

После теста — отозвать токен:
```bash
skillreg token revoke <id> --org <your-org>
```
`<id>` — это внутренний ID токена (не имя и не префикс), возьмите его из вывода `skillreg token list`.
```
✓ Token "ci-deploy" has been revoked.
```
Проверьте, что после revoke тот же токен в CI-переменной больше не работает (аналогично тесту revoke в разделе про Skilly — отзыв должен реально блокировать доступ, а не только помечаться в UI).

---

## Desktop App

На Windows/macOS/Linux (скачать с [skillreg.dev/download](https://skillreg.dev/download)):

1. **login** — тот же ли flow, что в CLI (`skillreg setup` → browser login), или отдельный?
2. **search** — работает ли тот же полнотекстовый поиск, что и `skillreg search`, но с визуальным списком результатов.
3. **skill details/version history** — аналог `skillreg info`, но с историей всех версий, а не только текущей.
4. **install** — генерирует ли Desktop App готовую команду для терминала, либо ставит скилл напрямую сам, минуя CLI (это важно понять — от этого зависит, нужен ли нетехническому сотруднику терминал вообще).
5. **update/reinstall** — есть ли явная кнопка «обновить до latest» без необходимости помнить синтаксис `pull`.
6. **permissions** — видит ли обычный member те же скиллы/organizations, что через CLI, или UI показывает более узкий/широкий набор.
7. **отображение approved vs pending** — ключевая проверка UX approval workflow для нетехнического пользователя: видно ли явно в интерфейсе, что версия ещё не одобрена, до того как он попытается её поставить (в отличие от CLI, где это можно узнать только по факту ошибки при `pull`).

---

## Добавление уже существующего скилла (без `skillreg init`)

Если у вас уже есть готовый `SKILL.md` — например, вы мигрируете скиллы из GitLab-варианта или из Skilly, где скиллы уже написаны и проверены — `skillreg init` не нужен вообще. `init` — это просто удобный скаффолдинг для скиллов с нуля, а не обязательный шаг публикации.

### Шаг 1 — проверить, что существующий SKILL.md соответствует формату SkillReg

Обязательные поля YAML frontmatter, которые проверяет `push` на этапе Validate:
```yaml
---
name: "my-existing-skill"
description: "Краткое описание"
metadata:
  author: "your-name"
  version: "1.0.0"
---
```

Если скилл был написан под другой инструмент (RoleCraft, Skilly, голый `SKILL.md` без версии) — у него может **не быть** поля `version` в нужном месте (`metadata.version`, а не просто `version` на верхнем уровне) или вообще не быть валидного semver. Перед пушем стоит явно свериться:
```bash
cat ./existing-skill/SKILL.md | head -20
```
и поправить frontmatter вручную под ожидаемую структуру, если формат отличается.

### Шаг 2 — опубликовать по прямому пути, без init

`skillreg push` принимает **любую директорию** с валидным `SKILL.md`, необязательно созданную через `init`:
```bash
skillreg push ./existing-skill --org <your-org>
```

Если имя в frontmatter (`name: "my-existing-skill"`) не совпадает с именем папки (`existing-skill`) — CLI выдаст **предупреждение**, а не ошибку, но лучше исправить одним из двух способов:
```bash
# Вариант А — переименовать папку под имя из frontmatter
mv ./existing-skill ./my-existing-skill
skillreg push ./my-existing-skill --org <your-org>

# Вариант Б — явно переопределить имя флагом, оставив папку как есть
skillreg push ./existing-skill --org <your-org> --name my-existing-skill
```

### Шаг 3 — если версии в frontmatter нет вообще (мигрируете со скилла без версионирования)

Явно задать версию при первом пуше, не трогая сам файл:
```bash
skillreg push ./existing-skill --org <your-org> --version 1.0.0
```
Это самый безопасный вариант для миграции большого количества старых скиллов, у которых версии никогда не было — вы не редактируете сотни файлов вручную, а просто передаёте стартовую версию флагом при каждом пуше.

Проверить результат тем же способом, что и для нового скилла:
```bash
skillreg info @<your-org>/my-existing-skill
```

---

## Массовая загрузка

Хранилище скиллов ограничено уровнем подписки, поэтому скорре всего (если не оформили подписку) при выполнении команд массовой загрузки будет получен - `Push failed: Skill limit reached (10 on free plan)`

### Способ 1 — `push-all`, если это применимо к вашей структуре

В документации `push-all` описан так: он **сканирует «ваш настроенный каталог скиллов» (configured skills directory)** на предмет подпапок с `SKILL.md` и пушит каждую:
```bash
skillreg push-all --org <your-org>
```

### Способ 2 — скриптовый цикл

Если вы не смогли настроить `push-all` под свою структуру (отправляет скиллы из текущего репозитория):

```bash
find skills -name "SKILL.md" -exec dirname {} \; | xargs -P 5 -I {} sh -c ' npx skillreg push {} --org <YOUR-ORG> --version 1.0.0 2>&1 | tee -a /tmp/skillreg-push-results.log '  
```

Флаг `-P 5` — ограничение параллелизма; стоит **явно протестировать разные значения** (1, 5, 20) и посмотреть, где у SaaS-реестра начинается rate limiting (это как раз один из пунктов "Что обязательно выяснить до production" — "ограничения API/CI").

### Массовая подгрузка из SkillReg

**`pull-all` на стороне юзера после массовой загрузки** — `skillreg pull-all --org <your-org> --agent all`

---
