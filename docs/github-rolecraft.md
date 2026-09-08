# GitLab + RoleCraft

---

Создание централизованного хранилища скиллов по схеме: GitLab/GitHub + RoleCraft.

Это **тот же центральный GitLab/GitHub**, но другой installer.

> Ниже раздел расширен командами, которых **нет** у `npx skills` (это ключевые отличия, ради которых вообще имеет смысл тестировать RoleCraft как альтернативу). Источник — официальный README и `docs/commands/*` в [github.com/rolecraft-sh/rolecraft](https://github.com/rolecraft-sh/rolecraft). Там, где я не нашёл 100% подтверждённый синтаксис флагов, помечаю это отдельно — сверьте через `--help` перед тем, как закладывать в процесс.

## Установка CLI

```bash
npx rolecraft --help
```

или:

```bash
npm install -g rolecraft
```

Требование: Node.js ≥ 20. CLI zero-dependency (только встроенные модули Node) — это отдельный плюс с точки зрения supply-chain безопасности по сравнению с инструментами, тянущими сторонние зависимости.

## Установка

```bash
rolecraft install ./company-skills/skills/poc-alpha --cursor
```

Из GitLab:

```bash
rolecraft install \
  git@gitlab.company.local:ai-skills/company-skills.git \
  --cursor
```

**Важное отличие от `npx skills`: каждый `install` автоматически прогоняет security-скан** — статический анализ на prompt injection, command injection, обфусцированный код, credential harvesting. Скилл получает оценку 0–100, и потенциально опасные скиллы блокируются по умолчанию (обойти можно флагом `--yes`, но осознанно). У `npx skills` такого встроенного сканирования нет.

Перед финальным PoC уточнить через:

```bash
rolecraft install --help
```

как CLI выбирает конкретный skill, если source содержит несколько `SKILL.md`: цель этого теста — не предполагать поведение, а зафиксировать его на вашей структуре repository.

## Agent detection

```bash
rolecraft setup
```

или установка в несколько targets:

```bash
rolecraft install ./company-skills/skills/poc-alpha \
  --cursor --copilot
```

RoleCraft заявляет поддержку 86+ агентов одной и той же командой — стоит явно протестировать, что `setup` корректно определяет именно те агенты, что реально стоят на машинах сотрудников (Cursor, Claude Code, Copilot, aider и т.д.), а не только «топовые».

## Проверка update / integrity

```bash
rolecraft list
rolecraft check
rolecraft update poc-alpha
rolecraft verify
```

Дополнительно, чего нет в базовом наборе `npx skills`:

```bash
rolecraft doctor
rolecraft doctor --deep
```

`doctor` — общая диагностика: проверяет директории агентов, lockfile, целостность скиллов. Флаг `--deep` добавляет **обнаружение конфликтов** — например, если один и тот же скилл или MCP-сервер установлен дважды из разных источников с разными версиями. Для корпоративного сценария с несколькими репозиториями (security/developer/sales) это прямая проверка на «а не сломали ли мы друг другу конфигурацию».

После V2 проверить содержимое установленного skill.

## Rollback

```bash
rolecraft rollback poc-alpha
```

Проверить возврат `ALPHA-V1`.

Это отдельная фича RoleCraft (добавлена в релизе v2.2.0), которой **нет** у `npx skills` вообще — там просто нет механизма отката к предыдущей версии установленного скилла. Стоит протестировать сценарий: поставили V2, скилл повёл себя плохо, откатились на V1 командой `rollback` — и явно проверить, что откатились файлы скилла, а не просто изменилась запись в манифесте.

## Bundle из нескольких sources

```bash
rolecraft bundle --help
rolecraft bundle create --help
```

Установка сразу из нескольких источников одной командой (то, чего у `npx skills` нет вообще — там `install` принимает только один источник за раз):

```bash
rolecraft bundle owner/security-skills owner/developer-skills owner/sales-skills --dry-run
rolecraft bundle owner/security-skills owner/developer-skills owner/sales-skills --cursor
```

Создать тестовый bundle из security/developer/sales repositories и проверить одним запуском установку согласованного корпоративного набора.

Второй режим — установка из файла-манифеста, что удобно для распространения "утверждённого набора" внутри компании:

```bash
rolecraft bundle create company-baseline    # создаёт company-baseline.json
```

Сгенерированный файл выглядит так:

```json
{
  "name": "company-baseline",
  "skills": [
    "owner/security-skills",
    "owner/developer-skills",
    "owner/sales-skills"
  ]
}
```

Отредактируйте `skills`, закоммитьте файл в GitLab-репозиторий рядом со скиллами — и любой сотрудник ставит весь согласованный набор одной командой:

```bash
rolecraft bundle company-baseline.json
```

Поддерживаются также plain-text манифесты (`skills.txt`, построчно, с `#`-комментариями) и JSON-массив без обёртки `{name, skills}`. Полезные флаги: `--dry-run` (превью без установки) и `--no-mcp` (пропустить установку MCP-серверов, объявленных внутри скиллов).

Это один из главных критериев, по которому RoleCraft может оказаться удобнее `npx skills`.

## CI restore

```bash
rolecraft ci
```

Проверить восстановление skill set из lockfile на чистой runner-машине. Есть готовый GitHub Action для этого сценария:

```yaml
# .github/workflows/skills.yml
- uses: rolecraft-sh/rolecraft-action@v1
  with:
    command: ci --yes
```

## Дополнительные команды, отсутствующие у `npx skills`

Эти возможности стоит включить в PoC отдельным пунктом, так как именно они формируют разницу в пользу RoleCraft (или, если окажутся не нужны — аргумент в пользу `npx skills` как более простого инструмента).

### MCP-серверы в одной команде со скиллом
```shell
rolecraft install ./company-skills/skills/poc-alpha --cursor   # ставит скилл И его MCP-сервер разом
rolecraft mcp search postgres
rolecraft mcp check
```
Скилл может декларировать нужный MCP-сервер прямо в frontmatter `SKILL.md` (`mcp_servers:`), и `install`/`bundle` поставят и то, и другое одной командой. У `npx skills` MCP-поддержки нет вообще — это отдельная категория различий, а не просто "ещё одна фича".

### Тестирование качества скилла (assertions)
```shell
rolecraft test ./company-skills/skills/poc-alpha
```
Позволяет прогнать скилл через набор проверок/assertion-ов перед тем, как публиковать его для всей компании — полезно встроить в CI-пайплайн репозитория со скиллами как gate перед мержем в main.

### Diff и Compose
```shell
rolecraft diff --help
rolecraft compose --help
```
Команды добавлены в релизе v2.0.0. `diff`, судя по системе профилей, используется для сравнения текущего состояния установленных скиллов с сохранённым профилем (см. `profileDiff` в Node.js API) — то есть можно проверить, что реально стоит на машине сотрудника, отличается ли от корпоративного baseline. Точный синтаксис `compose` стоит уточнить через `--help`, документация по нему в README менее подробная, чем по `bundle`.

### Просмотр без установки
```shell
rolecraft use owner/security-skills
```
Показывает содержимое скилла (файлы) без реальной установки — удобно для ревью нового скилла из чужого репозитория перед тем, как одобрить его для company-baseline.

### Публикация и поиск через GitHub-реестр
```shell
rolecraft search react --registry
rolecraft search react-rules          # поиск по GitHub напрямую, без реестра
rolecraft publish ./my-skill/ --repo user/my-skill
```
Опциональный community-реестр (полностью необязателен, всё остальное работает и без него) — если решите не публиковать корпоративные скиллы публично, просто не используйте `--registry` и `publish`.

### Профили: сохранить и переиспользовать конфигурацию
```
rolecraft profile save team-baseline
rolecraft profile apply team-baseline
rolecraft profile list
rolecraft profile show team-baseline
rolecraft profile diff team-baseline
rolecraft profile delete team-baseline
rolecraft profile import <file>
```
В отличие от `bundle` (который просто устанавливает список источников), `profile` фиксирует **фактическое состояние** — что уже стоит на машине для скольких агентов — и позволяет сравнить (`diff`) или воспроизвести это состояние на другой машине.

### Генерация AGENTS.md
```shell
rolecraft agents-xml --write
```
Генерирует XML-описание скиллов, совместимое с Claude Code, прямо в `AGENTS.md` — полезно, если в компании уже есть конвенция документировать доступные агенту инструкции в этом файле.

### Shell-автодополнение
```shell
rolecraft completions bash
rolecraft completions zsh
rolecraft completions fish
```
Мелочь, но снижает трение при ежедневном использовании CLI большим количеством сотрудников.

## Решение

Выбрать RoleCraft вместо `npx skills` только если следующие возможности реально важны и компенсируют добавление ещё одного third-party слоя:

- `bundle` — установка/распространение согласованного набора из нескольких репозиториев одной командой
- `rollback` — быстрый откат к предыдущей версии скилла
- `verify` / `doctor --deep` — проверка целостности и конфликтов
- security-скан на каждый `install` (специфика RoleCraft, а не общая практика всех installer-ов)
- MCP-поддержка "из коробки" вместе со скиллами
- `test` — assertion-based проверка качества скилла перед публикацией

Сам центральный backend от этого не меняется: им остаётся GitLab. RoleCraft — это только consumer-layer поверх него.