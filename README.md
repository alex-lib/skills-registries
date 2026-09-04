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
