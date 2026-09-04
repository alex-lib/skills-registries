# registry-skills-github-npx-skills

Создание централизованного хранилища скиллов по схеме: GitLab/GitHub + `npx skills`.

## Базовая архитектура: GitLab/GitHub + `npx skills`

### Из чего состоит

Архитектура состоит из двух обычных компонентов:

- **GitLab/GitHub** — централизованное хранилище исходников skills, история, ветки, Merge Requests, CODEOWNERS, permissions, tags/releases.

- `**skills**` **от Vercel** — open-source CLI для поиска skills в git-источнике и установки их в локальные директории AI-агентов ( `**npx skills add <repository>**`).

Пример команд CLI-инструмента `skills`:

```
npx skills add git@gitlab.company.local:ai/company-skills.git --list
npx skills add git@gitlab.company.local:ai/company-skills.git --skill code-review
```

Запускается через `npx`, то есть без предварительной установки — npx скачает и выполнит пакет на лету.

**Общий смысл `skills add <репозиторий>`:**  
Команда добавляет скилы из указанного git-репозитория. В данном случае репозиторий — это `ai/company-skills.git`, лежащий на приватном GitLab-сервере (`gitlab.company.local`), путь указан в формате SSH (`git@gitlab.company.local:...`) — то есть подключение идёт через SSH-ключи, а не HTTPS.

**Разбор каждой команды:**

1. **`npx skills add git@gitlab.company.local:ai/company-skills.git --list`**  
    Флаг `--list` означает "только показать список", ничего не устанавливая. То есть команда:
    - Подключается к репозиторию,
    - Смотрит, какие скилы там есть,
    - Выводит пользователю их список, чтобы он мог выбрать, что установить.
2. **`npx skills add git@gitlab.company.local:ai/company-skills.git --skill code-review`**  
    Флаг `--skill code-review` указывает **конкретный** скил, который нужно установить из этого репозитория — в данном случае с именем `code-review`.  
    Команда:
    - Клонирует/скачивает репозиторий (или нужную его часть),
    - Находит внутри скил с именем `code-review`,
    - Устанавливает его — то есть кладёт файлы в canonical-директорию (`.agents/skills/code-review` или `~/.agents/skills/code-review`, в зависимости от scope) и создаёт симлинки/junction'ы в нужных местах под конкретных агентов.

Поддерживаются GitHub shorthand/URL, GitLab URL, любой git URL, SSH и локальная папка.

### Где физически хранится skill

Никакой отдельной инфраструктуры не требуется: скилы — это просто файлы в git-репозитории (GitLab/GitHub).

Структура:

```
company-skills/
├── README.md
├── skills/
│   ├── code-review/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── security-review/
│   │   └── SKILL.md
│   └── sales-account-research/
│       └── SKILL.md
└── .gitlab-ci.yml
```

На компьютере пользователя реальные файлы скила лежат в одном месте — `.agents/skills/<skill>` (для уровня проекта) или `~/.agents/skills/<skill>` (для глобального уровня) — это и есть canonical-копия, источник истины.  

А в директориях, которые ожидают конкретные агенты/инструменты (у каждого может быть свой формат и своё расположение файлов), создаются не отдельные полные копии, а симлинки (символические ссылки), указывающие на эту canonical-копию.

### Symlink или копирование

По умолчанию installer использует режим **symlink**:

1. skill копируется в canonical directory;
2. в директории выбранных агентов создаются symbolic links / junctions;
3. все агенты смотрят на одну локальную canonical-копию.

Обновление не создает несколько расходящихся копий одного skill.

Если symlink не нужен или ОС/политика безопасности его ограничивает:

```
npx skills add <repository> --skill code-review --copy
```

В исходном коде installer предусмотрен fallback: если symlink создать не удалось, он переходит к копированию. На Windows используются directory junctions.

Создание настоящих symlink на Windows часто упирается в проблемы с правами доступа — обычному пользователю без прав администратора система может просто не дать создать symlink. 

Junction — это способ обойти это ограничение: он даёт похожую функциональность (ссылка на директорию вместо копирования), но не требует повышенных прав.

Поэтому логика installer может быть такая:

1. Попробовать создать обычный symlink (кроссплатформенное решение).
2. Если не получилось (без Developer Mode и без прав администратора — попытка создать symlink завершится ошибкой доступа) — попробовать directory junction.
3. Если и это не сработало — просто скопировать файлы (fallback последней инстанции, при котором теряется связь с canonical-копией, и придётся синхронизировать копии вручную).

### Как installer понимает, куда ставить skill

В `skills` есть таблица поддерживаемых agents и известных путей. Например, installer проверяет наличие стандартных директорий агента (`~/.cursor`, `~/.claude`, `~/.codex` и т.п.), после чего предлагает найденные агенты или позволяет указать их явно.

```
# конкретный агент
npx skills add <repository> --skill code-review --agent cursor

# несколько агентов
npx skills add <repository> --skill code-review \
  --agent claude-code --agent cursor

# все поддерживаемые агенты
npx skills add <repository> --skill code-review --agent '*'
```

Для CI и управляемых установок лучше **не полагаться только на autodetect**, а передавать `--agent` явно.

### Как installer находит skills внутри repository

Он ищет каталоги с `SKILL.md` в типовых layout, в том числе `skills/`, `.agents/skills/` и agent-specific directories. Поэтому для корпоративного репозитория лучше принять единый простой convention:

```
skills/<skill-name>/SKILL.md
```

Это упрощает поиск, ревью и автоматическую валидацию.

### Установка конкретного skill или нескольких skills

```
# показать, что есть в репозитории
npx skills add <repository> --list

# один skill
npx skills add <repository> --skill code-review

# несколько skills из одного repository
npx skills add <repository> \
  --skill code-review \
  --skill security-review \
  --skill api-design

# все skills
npx skills add <repository> --skill '*'
```

### Может ли он устанавливать несколько библиотек параллельно

**Несколько skills из одного repository — да, одной командой.**

**Несколько разных repositories одной командой — нет как базовая модель** `**skills add**`**.** Каждый source добавляется отдельным вызовом:

```
npx skills add git@gitlab.company.local:ai/security-skills.git --skill threat-model -y
npx skills add git@gitlab.company.local:ai/dev-skills.git --skill code-review -y
npx skills add git@gitlab.company.local:sales/sales-skills.git --skill account-research -y
```

Раз сам CLI-инструмент не умеет ставить скилы из нескольких репозиториев одной командой "из коробки" — то можно **самому** написать простой bash/shell-скрипт, который содержит все нужные команды (как в примере выше — для security, dev, sales), и хранить этот скрипт **в отдельном git-репозитории** (например, `ai/bootstrap-scripts.git`).

Если именно «bundle из нескольких sources» является обязательным требованием CLI, это сильная сторона **RoleCraft**, у которого есть `rolecraft bundle <sources>`.

### Как обновляется skill у пользователя

CLI имеет отдельную команду:

```
npx skills update
npx skills update code-review
npx skills update code-review security-review
```

Также доступны scope-флаги:

```
npx skills update -p    # project
npx skills update -g    # global
```

Installer хранит метаданные установки/lock, чтобы понимать source и проверять новые версии/содержимое.

### Workflow разработчика skill

В GitLab/GitHub-варианте никакой отдельной публикационной платформы не требуется.

```
1. git clone company-skills
2. создать skills/my-skill/SKILL.md
3. локально проверить skill
4. git checkout -b feature/my-skill
5. commit + push
6. Merge Request
7. CI: schema / security / install smoke-test
8. review CODEOWNERS
9. merge в main
10. при необходимости tag/release
11. пользователи выполняют npx skills update или устанавливают новый skill
```

То есть **публикация = merge в разрешенную ветку**, а контроль качества строится обычными GitLab/GitHub-механизмами.

### Что будет при 1000 skills

Технически `--list` и `--skill <name>` позволяют выбрать один skill из большого repository. Но один repository на 1000 skills имеет два отдельных ограничения.

**1. Производительность доставки.** Текущая реализация использует shallow clone, но open issue проекта прямо указывает, что sparse-checkout для больших monorepo пока нужен как отдельная доработка. Значит, выбор одного skill не гарантирует, что по сети будет получена только его папка.

**2. Discovery.** GitLab tree и code search — это не специализированный каталог. На 20–100 skills этого достаточно; на 1000 поиск по папкам становится плохим UX для обычного сотрудника.

Поэтому для GitLab-варианта рекомендуемая схема при росте:

```
GitLab group: ai-skills/
├── engineering-skills     (например, 50–150)
├── security-skills        (50–150)
├── data-skills
├── sales-skills
├── marketing-skills
└── skills-catalog         (README/site/index.json)
```

Не нужно делать один гигантский repository только потому, что CLI умеет выбрать `--skill`.

### Плюсы и минусы GitLab/GitHub + `npx skills`

**Плюсы**

- использует уже знакомую Git-инфраструктуру;
    
- source code и review остаются в Git;
    
- просто запуск/создание;
    
- private SSH/HTTPS access;
    
- выбор одного или нескольких skills;
    
- много поддерживаемых AI agents;
    
- cross-platform;
    
- минимальный vendor lock-in: обычный `SKILL.md` + git.


**Минусы**

- нет полноценного registry UI;
- нет отдельного granular RBAC на skill, права обычно repository/group-level;
- нет native install analytics;
- 1000 skills в одном monorepo — плохая архитектура;

Важно понимать, что каталог придется поддерживать самим. Именно здесь специализированные registries начинают давать реальное преимущество.

## 0. Что проверяем

Базовый и наиболее дешёвый вариант:

```
GitHub = centralized storage + permissions + review
npx skills = discovery inside repo + install/update into agents
```

### Требования на workstation

```
node --version
npm --version
git --version
```

Рекомендуется Node.js 20+.

Команды `npx` одинаковы на macOS/Linux и в PowerShell Windows.

---

## 1. Подготовка хранилища на GitHub (личный аккаунт)

### 1.1 Настроить SSH-доступ

Проверить, есть ли уже ключи:

```
ls -la ~/.ssh
```

Если для GitHub ещё нет отдельного ключа — создать новый (не переиспользовать рабочие/deploy-ключи, чтобы не путать окружения):

```
ssh-keygen -t ed25519 -C "github-personal" -f ~/.ssh/id_ed25519_personal
```

Скопировать публичный ключ:

```
pbcopy < ~/.ssh/id_ed25519_personal.pub
```

Добавить его в GitHub: **Settings → SSH and GPG keys → New SSH key** → вставить → **Add SSH key**.

Прописать, чтобы SSH использовал именно этот ключ для github.com:

```
cat >> ~/.ssh/config << 'EOF'

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_personal
  IdentitiesOnly yes
EOF
```

> Если на этом же GitHub-аккаунте уже есть другие ключи (для других ваших репозиториев) — конфликта не будет: любой ключ, добавленный в Settings аккаунта, даёт доступ ко всем репозиториям этого аккаунта. Правило `Host github.com` влияет только на подключения к github.com и не трогает SSH-настройки для других хостов (GitLab, серверы и т.д.).

Проверить:

```
ssh -T git@github.com
```

Ожидается:

```
Hi <ваш_логин>! You've successfully authenticated, but GitHub does not provide shell access.
```

### 1.2 Создать репозиторий на GitHub

1. github.com → **+** → **New repository**.
2. Repository name: `registry-skills-github-npx-skills` (или как вам удобно).
3. **Private**.
4. Можно сразу поставить галочку **Add a README file** — так репозиторий не будет пустым и его сразу можно клонировать.
5. **Create repository**.

### 1.3 Склонировать репозиторий локально

```
git clone git@github.com:ВАШ_ЛОГИН/registry-skills-github-npx-skills.git
cd registry-skills-github-npx-skills
```

Проверить, что репозиторий доступен по git:

```
git ls-remote git@github.com:ВАШ_ЛОГИН/registry-skills-github-npx-skills.git
```

Если команда отработала без ошибок — доступ настроен верно.

### 1.4 Создать структуру скилов

```
mkdir -p skills/poc-alpha skills/poc-beta skills/poc-gamma
```

В каждую папку — файл `SKILL.md`, например `skills/poc-alpha/SKILL.md`:

```
---
name: poc-alpha
description: Тестовый скил для проверки установки
---
# poc-alpha

Тело скила — инструкции для агента.
```

Аналогично для `poc-beta` и `poc-gamma` (с соответствующими именами и маркерами).

### 1.5 Закоммитить и запушить

```
git add .
git commit -m "Initial PoC skills"
git push -u origin main
```

### 1.6 Настроить права и review (аналог "permissions + review")

- **Settings → Collaborators and teams** — выдать нужным людям доступ (Write — для публикации скилов, Read — только для установки).
- **Settings → Branches → Add branch protection rule** для `main`:
    - Require a pull request before merging
    - Require approvals (минимум 1)

Так никто не пушит в `main` напрямую — изменения скилов идут через Pull Request.

---

## 2. Тестирование без агентов на компьютере

> Важно: `npx skills` не проверяет, реально ли установлен агент (Claude Code, Cursor и т.д.) — он просто кладёт файлы по стандартному пути для этого агента (`.claude/skills`, `.cursor/skills` и т.п.). Поэтому весь механизм установки/симлинков/обновления можно полностью протестировать **без единого установленного агента** — результат проверяется просмотром файловой системы (`ls`, `find`).

---

## 3. Сначала протестировать без GitHub — на локальной папке

Это позволяет проверить installer отдельно от сети и auth.

```
cd /path/to/company-skills
npx skills add . --list
```

Ожидается список `poc-alpha`, `poc-beta`, `poc-gamma`.

### Установка одного

```
npx skills add . --skill poc-alpha --agent claude-code -y
```

### Нескольких

```
npx skills add . \
  --skill poc-alpha \
  --skill poc-beta \
  --agent claude-code \
  --agent cursor \
  -y
```

В PowerShell перенос строки — backtick:

```
npx skills add . `
  --skill poc-alpha `
  --skill poc-beta `
  --agent claude-code `
  --agent cursor `
  -y
```

### Важно

Используйте:

```
--skill poc-alpha
```

а не:

```
--skill=poc-alpha
```

В актуальном upstream есть открытый bug на equals-вариант.

---

## 4. Проверить symlink-механизм

По умолчанию:

```
npx skills add . --skill poc-alpha --agent claude-code -y
```

Проверка macOS/Linux:

```
find .agents/skills -maxdepth 2 -type f -o -type l
ls -la .claude/skills
```

Проверка PowerShell:

```
Get-ChildItem .agents\skills -Recurse
Get-ChildItem .claude\skills -Force
```

Ожидаемая идея:

```
.agents/skills/poc-alpha/      ← canonical copy
.claude/skills/poc-alpha       ← link/junction или доступ через agent path
```

### Принудительно проверить copy mode

```
npx skills add . --skill poc-alpha --agent claude-code --copy -y
```

Сравните filesystem до/после.

На Windows это особенно важно: если политика устройства не позволяет symlink/junction, нужно подтвердить корректный fallback или стандартно использовать `--copy`.

---

## 5. Проверить autodetect agents

Запустите интерактивно:

```
npx skills add . --skill poc-alpha
```

Сравните найденные agents с реально установленными Cursor / Claude Code / Codex.

Затем повторите с явным target:

```
npx skills add . --skill poc-alpha -a cursor -y
```

**Критерий:** в production bootstrap/CI лучше использовать явный `--agent`, чтобы результат не зависел от локального autodetect.

---

## 6. Установка из private GitHub

### Список

```
npx skills add \
  git@github.com:ВАШ_ЛОГИН/registry-skills-github-npx-skills.git \
  --list
```

### Один skill

```
npx skills add \
  git@github.com:ВАШ_ЛОГИН/registry-skills-github-npx-skills.git \
  --skill poc-alpha \
  --agent cursor \
  -y
```

### Несколько выбранных

```
npx skills add \
  git@github.com:ВАШ_ЛОГИН/registry-skills-github-npx-skills.git \
  --skill poc-alpha \
  --skill poc-gamma \
  --agent claude-code \
  --agent cursor \
  -y
```

**PASS:** установились только alpha+gamma, beta отсутствует.

---

## 7. Проверить update lifecycle

### Шаг 1. Установить V1

```
npx skills add \
  git@github.com:ВАШ_ЛОГИН/registry-skills-github-npx-skills.git \
  --skill poc-alpha \
  --agent cursor \
  -y
```

Проверьте в установленном `SKILL.md`: `ALPHA-V1`.

### Шаг 2. Изменение и публикация V2

```
git checkout -b update/poc-alpha-v2
# изменить Тело скила — инструкции для агента. -> Тело скила — инструкции для агента V2. в skills/poc-alpha/SKILL.md
git add skills/poc-alpha/SKILL.md
git commit -m "Update poc-alpha to V2"
git push origin update/poc-alpha-v2
```

Создать Pull Request на GitHub → approve → merge в `main`.

### Шаг 3. Consumer обновляет

```
npx skills update poc-alpha -p
```

Если тестировали global scope:

```
npx skills update poc-alpha -g
```

Проверить, что локальный `SKILL.md` теперь содержит `ALPHA-V2`.

---

## 8. Проверить несколько библиотек

Создайте два репозитория на GitHub, например:

```text
security-skills
developer-skills
```

`npx skills` ставит их отдельными source-вызовами:

```text
npx skills add git@github.com:ВАШ_ЛОГИН/security-skills.git \
  --skill threat-model -a cursor -y

npx skills add git@github.com:ВАШ_ЛОГИН/developer-skills.git \
  --skill code-review -a cursor -y
```

Для сотрудников можно сделать `bootstrap-skills.sh` и `bootstrap-skills.ps1`.

Пример PowerShell:

```text
npx skills add git@github.com:ВАШ_ЛОГИН/security-skills.git --skill threat-model -a cursor -y
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

npx skills add git@github.com:ВАШ_ЛОГИН/developer-skills.git --skill code-review -a cursor -y
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
```

---

## 9. Тест 1000 skills

### Bash/macOS/Linux

```text
mkdir -p stress-skills/skills
for i in $(seq -w 1 1000); do
  d="stress-skills/skills/poc-$i"
  mkdir -p "$d"
  cat > "$d/SKILL.md" <<TXT
---
name: poc-$i
description: Stress test skill $i
---
# poc-$i
Return marker $i.
TXT
done
```

### PowerShell

```text
New-Item -ItemType Directory -Force stress-skills\skills | Out-Null
1..1000 | ForEach-Object {
  $i = $_.ToString('0000')
  $dir = "stress-skills\skills\poc-$i"
  New-Item -ItemType Directory -Force $dir | Out-Null
  @"
---
name: poc-$i
description: Stress test skill $i
---
# poc-$i
Return marker $i.
"@ | Set-Content "$dir\SKILL.md"
}
```

### Измерить локальный discovery

macOS/Linux:

```text
time npx skills add ./stress-skills --list
```

PowerShell:

```text
Measure-Command { npx skills add .\stress-skills --list }
```

### Выбор одного из 1000

```text
npx skills add ./stress-skills --skill poc-0777 -a cursor -y
```

Убедитесь, что другие 999 не установлены.

Важно:** `npx skills` использует shallow clone, но upstream пока имеет открытый запрос на sparse-checkout для больших monorepo. Поэтому 1000 маленьких skills и один тяжёлый monorepo могут вести себя по-разному.

---

## 10. Проверка workflow разработчика через CI (GitHub Actions)

Создать файл `.github/workflows/validate-skills.yml`:

```yaml
name: validate-skills
on: [pull_request]

jobs:
  validate-skills:
    runs-on: ubuntu-latest
    container: node:22
    steps:
      - uses: actions/checkout@v4
      - run: npx -y skills add . --list
      - run: npx -y skills add . --skill poc-alpha --agent claude-code --copy -y
      - run: test -f .claude/skills/poc-alpha/SKILL.md || test -f .agents/skills/poc-alpha/SKILL.md
```

Дальше добавить:

- `SKILL.md` schema validation - автоматическая проверка, что каждый SKILL.md содержит обязательные поля (name, description) в правильном формате (YAML frontmatter), а не просто "какой-то текстовый файл с любым содержимым".
- secret scan - проверка, что в файлах скилов (или во всём репозитории) нет случайно попавших паролей, API-ключей, токенов (можно использовать готовый open-source инструмент, не писать свой. Самый популярный — Gitleaks).
- custom policy scan - в отличие от secret scan (ищет конкретно секреты), это ваши собственные правила, специфичные для компании — например: "скилы не должны содержать вызовы curl/wget к внешним доменам", "запрещено использовать eval()", "скилы должны быть только на русском/английском", "запрещённые слова/темы" и т.п.
- PR approval/CODEOWNERS - обязательное ревью перед мержем

Что это: не столько CI-шаг, сколько настройка репозитория, гарантирующая, что merge в main невозможен без одобрения нужного человека/команды.

Как сделать:

a) Branch protection (это вы уже частично настраивали ранее): Settings → Branches → Add rule для main → включить Require a pull request before merging и Require approvals (минимум 1).

b) CODEOWNERS — файл, который автоматически назначает нужных ревьюеров в зависимости от того, какие файлы затронуты в PR. Создать в репозитории:

```text
# .github/CODEOWNERS
skills/security-* @security-team
skills/dev-*       @dev-team
*                  @platform-team
```

- generated `catalog.json` - файл-сводка со списком всех скилов в репозитории (имя, описание, путь) — чтобы не листать вручную папки, а быстро посмотреть, что вообще есть, программно или в UI.

Синтаксис: путь (можно с wildcard) → кто должен одобрить изменения в этом пути. Например, если PR меняет skills/threat-model/SKILL.md, GitHub автоматически запросит ревью у @security-team.

Чтобы CODEOWNERS реально блокировал merge без их одобрения, в branch protection нужно дополнительно включить: Require review from Code Owners.

Пример
```yaml
name: validate-skills
on: [pull_request]

jobs:
  validate-skills:
    runs-on: ubuntu-latest
    container: node:22
    steps:
      - uses: actions/checkout@v4
      - run: npm install js-yaml

      - name: Basic install test
      - run: |
          npx -y skills add . --list
          npx -y skills add . --skill poc-alpha --agent claude-code --copy -y
          test -f .claude/skills/poc-alpha/SKILL.md || test -f .agents/skills/poc-alpha/SKILL.md

      - name: Validate SKILL.md schema
      - run: node scripts/validate-skills.js

      - name: Custom policy scan
      - run: node scripts/policy-scan.js

      - name: Secret scan
      - run: |
          curl -sSL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_8.18.0_linux_x64.tar.gz | tar -xz
          ./gitleaks detect --source . --verbose

      - name: Generate catalog
      - run: node scripts/generate-catalog.js
```

---
