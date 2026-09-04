const fs = require('fs');
const path = require('path');

const forbiddenPatterns = [
    { pattern: /eval\(/, message: 'Использование eval() запрещено' },
    { pattern: /curl\s+https?:\/\/(?!company\.local)/, message: 'Запрещены внешние curl-запросы' },
];

let hasError = false;
const skillsDir = 'skills';

for (const dir of fs.readdirSync(skillsDir)) {
    const skillPath = path.join(skillsDir, dir, 'SKILL.md');
    if (!fs.existsSync(skillPath)) continue;
    const content = fs.readFileSync(skillPath, 'utf8');

    for (const { pattern, message } of forbiddenPatterns) {
        if (pattern.test(content)) {
            console.error(`❌ ${skillPath}: ${message}`);
            hasError = true;
        }
    }
}

process.exit(hasError ? 1 : 0);