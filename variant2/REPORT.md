# Практическая работа — Вариант 2

## 1. Вариант и цель исследования

- **Вариант:** 2
- **Проект:** [mozilla/pdf.js](https://github.com/mozilla/pdf.js/tree/v3.7.107), версия **v3.7.107**
- **ОС:** Linux
- **Инструмент генерации SBOM:** `@cyclonedx/cyclonedx-npm` (CycloneDX Node.js NPM)
- **Инструмент анализа:** Trivy v0.69.3

---

## 2. Установка инструментов

### 2.1 Установка Node.js и npm

```bash
node --version   # v18.19.1
npm --version    # 9.2.0
```

### 2.2 Установка cyclonedx-npm

```bash
npm install -g @cyclonedx/cyclonedx-npm
cyclonedx-npm --version   # 4.2.1
```

Инструмент `cyclonedx-npm` предназначен для генерации SBOM из npm-проектов в формате CycloneDX JSON или XML.

### 2.3 Установка Trivy

```bash
TRIVY_VER=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4)
wget -q "https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VER}/trivy_${TRIVY_VER#v}_Linux-64bit.tar.gz" \
  -O /tmp/trivy.tar.gz
tar xzf /tmp/trivy.tar.gz -C /tmp
cp /tmp/trivy /usr/local/bin/trivy
chmod +x /usr/local/bin/trivy
trivy --version   # Version: 0.69.3
```

---

## 3. Подготовка проекта

### 3.1 Клонирование репозитория

```bash
git clone --depth 1 --branch v3.7.107 https://github.com/mozilla/pdf.js.git pdfjs
cd pdfjs
```

Флаги:
- `--depth 1` — поверхностное клонирование для экономии места
- `--branch v3.7.107` — конкретная версия проекта

### 3.2 Установка зависимостей

```bash
npm ci --ignore-scripts
```

- `npm ci` — устанавливает точные версии из `package-lock.json`
- `--ignore-scripts` — не выполняет lifecycle-скрипты для безопасности

Результат: установлено **740 пакетов** в `node_modules/`.

---

## 4. Генерация SBOM

```bash
cyclonedx-npm --output-format json --output-file sbom.json
```

Параметры:
- `--output-format json` — формат CycloneDX JSON
- `--output-file sbom.json` — выходной файл

### Результат:

```
bomFormat:    CycloneDX
specVersion:  1.6
components:   893
```

Файл `sbom.json` содержит полный список зависимостей проекта pdf.js v3.7.107 со всеми транзитивными зависимостями. Фрагмент структуры файла:

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.6",
  "serialNumber": "urn:uuid:...",
  "version": 1,
  "metadata": {
    "component": {
      "type": "library",
      "name": "pdfjs-dist",
      "version": "3.7.107"
    }
  },
  "components": [ ... ]
}
```

---

## 5. Анализ SBOM через Trivy

```bash
trivy sbom sbom.json --format table 2>&1 | tee trivy-report.txt
```

Параметры:
- `sbom` — режим анализа SBOM-файла
- `--format table` — табличный вывод результатов
- `tee trivy-report.txt` — сохранение результата в файл

### Итоговая сводка Trivy (первичный скан):

```
Total: 41 (UNKNOWN: 0, LOW: 4, MEDIUM: 17, HIGH: 19, CRITICAL: 1)
```

| Severity | Count |
|----------|-------|
| CRITICAL | 1     |
| HIGH     | 19    |
| MEDIUM   | 17    |
| LOW      | 4     |
| UNKNOWN  | 0     |

---

## 6. Выбор уязвимости CVE и оценка CVSS

### Выбранная уязвимость: CVE-2023-45133

| Параметр           | Значение                          |
|--------------------|-----------------------------------|
| **Компонент**      | `@babel/traverse`                 |
| **Версия**         | 7.22.1                            |
| **Severity**       | **CRITICAL**                      |
| **Исправлена в**   | 7.23.2, 8.0.0-alpha.4             |
| **CVSS v3 Score**  | **9.8**                           |
| **Vector**         | AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H |

### Интерпретация вектора CVSS:

| Метрика | Значение | Описание |
|---------|----------|----------|
| AV:N    | Network  | Атака через сеть |
| AC:L    | Low      | Низкая сложность атаки |
| PR:N    | None     | Не требуются привилегии |
| UI:N    | None     | Не требуется взаимодействие пользователя |
| S:U     | Unchanged| Область воздействия не изменяется |
| C:H     | High     | Высокое воздействие на конфиденциальность |
| I:H     | High     | Высокое воздействие на целостность |
| A:H     | High     | Высокое воздействие на доступность |

### Описание уязвимости

`@babel/traverse` до версии 7.23.2 содержит уязвимость, позволяющую выполнить произвольный код при обработке специально сформированного AST (Abstract Syntax Tree). Злоумышленник может внедрить вредоносный код через свойства объекта, которые `@babel/traverse` обходит во время преобразования. Данная уязвимость влияет на системы, в которых ненадёжные данные передаются в Babel для компиляции.

### Бизнес-риски:

- **Выполнение произвольного кода** на стороне сервера/CI
- Компрометация build-пайплайна
- Возможность захвата системы при использовании Babel в production-окружении
- Не требует аутентификации для эксплуатации

---

## 7. План исправления зависимости

**Цель:** устранить CVE-2023-45133 путём обновления `@babel/traverse`.

| Текущая версия | Уязвимая | Безопасная версия |
|----------------|----------|-------------------|
| 7.22.1         | да       | 7.23.2            |

### Шаги:

**Шаг 1 — Обновление зависимости**
```bash
npm install @babel/traverse@7.23.2 --save-dev
```

**Шаг 2 — Проверка установленной версии**
```bash
node -e "const p=require('./node_modules/@babel/traverse/package.json'); console.log(p.version)"
# 7.23.2
```

**Шаг 3 — Регрессионное тестирование**
```bash
npm test
```

**Шаг 4 — Фиксация изменений (в рамках проекта)**
```bash
git add package.json package-lock.json
git commit -m "fix: update @babel/traverse to 7.23.2 to fix CVE-2023-45133"
```

### Дорожная карта обновления

| Этап         | Действие                         | Срок   |
|--------------|----------------------------------|--------|
| Анализ       | Выявление CVE через Trivy        | День 1 |
| Планирование | Определение безопасной версии    | День 1 |
| Обновление   | `npm install @babel/traverse@7.23.2` | День 1 |
| Тестирование | Проверка сборки и тестов         | День 1 |
| Валидация    | Повторный Trivy scan             | День 1 |
| Деплой       | Выкатка в production             | День 2 |

### Риски обновления

- Несовместимость API `@babel/traverse` между мажорными версиями
- Влияние на другие Babel-плагины, зависящие от `traverse`
- Возможное изменение поведения AST-трансформаций

---

## 8. Тестирование обновления

### 8.1 Проверка обновлённой версии

```bash
node -e "const p=require('./node_modules/@babel/traverse/package.json'); console.log(p.version)"
# Результат: 7.23.2
```

### 8.2 Повторная генерация SBOM

```bash
cyclonedx-npm --output-format json --output-file sbom-updated.json
```

Результат: `sbom-updated.json`, 893 компонента.

### 8.3 Повторный анализ через Trivy

```bash
trivy sbom sbom-updated.json --format table 2>&1 | tee trivy-report-updated.txt
```

### 8.4 Результат повторного сканирования

```
Total: 40 (UNKNOWN: 0, LOW: 4, MEDIUM: 17, HIGH: 19, CRITICAL: 0)
```

| Метрика | До исправления | После исправления |
|---------|---------------|-------------------|
| CRITICAL | **1**        | **0**             |
| HIGH     | 19           | 19                |
| MEDIUM   | 17           | 17                |
| LOW      | 4            | 4                 |
| **Всего**| **41**       | **40**            |

**CVE-2023-45133 — УСТРАНЕНА.** Уязвимость отсутствует в обновлённом SBOM.

---

## 9. Артефакты

| Файл                     | Описание                                      |
|--------------------------|-----------------------------------------------|
| `sbom.json`              | SBOM pdf.js v3.7.107 (исходный)               |
| `trivy-report.txt`       | Отчёт Trivy по исходному SBOM (41 уязвимость) |
| `sbom-updated.json`      | SBOM после обновления @babel/traverse         |
| `trivy-report-updated.txt` | Отчёт Trivy после исправления (40, CRITICAL: 0) |
| `run_analysis.sh`        | Скрипт воспроизведения всего процесса         |
