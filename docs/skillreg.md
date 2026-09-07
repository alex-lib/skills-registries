# SkillReg

Создание централизованного хранилища через SkillReg.

## Prerequisites

- Node.js 18+

- SkillReg account / test organization


```
npm install -g @skillreg/cli
skillreg --version
skillreg setup
skillreg whoami
```

---

## Создание

```
skillreg init poc-alpha
```

Отредактировать `poc-alpha/SKILL.md`.

Publish V1:

```
skillreg push ./poc-alpha --org <your-org>
```

Проверить список:

```
skillreg list --org <your-org>
```

Search/info:

```
skillreg search "poc alpha"
skillreg info @<your-org>/poc-alpha
```

---

## Install latest

```
skillreg pull @<your-org>/poc-alpha \
  --agent cursor \
  --scope project
```

Все поддерживаемые agents:

```
skillreg pull @<your-org>/poc-alpha --agent all
```

Local inventory:

```
skillreg local
```

---

## Версии

Конкретная:

```
skillreg pull @<your-org>/poc-alpha@1.0.0
```

Semver range:

```
skillreg pull @<your-org>/poc-alpha@^1.0.0
```

Выпустить новую версию:

```
skillreg push ./poc-alpha --bump patch --org <your-org>
```

Обновить consumer до latest повторным pull:

```
skillreg pull @<your-org>/poc-alpha \
  --agent cursor \
  --scope project
```

Проверить, что содержимое V2 пришло локально.

---

## Mass install

```
skillreg pull-all \
  --org <your-org> \
  --agent all \
  --scope project
```

Это отдельный тест против GitLab-варианта: насколько удобно сотруднику поставить весь approved набор команды.

---

## Approval workflow

Включить approval в тестовой organization.

1. Developer публикует новую version.

2. До approve пользователь пытается pull.

3. Admin approve.

4. Пользователь повторяет pull.

5. Зафиксировать expected behavior и audit trail.


---

## CI token

```
skillreg token create --org <your-org>
skillreg token list --org <your-org>
```

Создать token с минимально достаточными scopes и проверить non-interactive `skillreg push` из CI.

После теста:

```
skillreg token revoke <id> --org <your-org>
```

---

## Desktop App

Поскольку одна из задач — дать доступ не только разработчикам, отдельно проверить на Windows/macOS/Linux:

- login;

- search;

- skill details/version history;

- install;

- update/reinstall;

- permissions;

- отображение approved vs pending.


---

## Что обязательно выяснить до production

Так как это SaaS:

- где физически хранятся данные;

- DPA / SLA;

- SSO/SCIM;

- export всей библиотеки;

- disaster recovery;

- audit retention;

- тариф на organization;

- есть ли self-hosted/enterprise option на момент закупки;

- ограничения API/CI;

- что происходит при прекращении подписки.
    