const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml'); // npm install js-yaml

const skillsDir = 'skills';
let hasError = false;

for (const dir of fs.readdirSync(skillsDir)) {
    const skillPath = path.join(skillsDir, dir, 'SKILL.md');
    if (!fs.existsSync(skillPath)) continue;

    const content = fs.readFileSync(skillPath, 'utf8');
    const match = content.match(/^---\n([\s\S]*?)\n---/);
    if (!match) {
        console.error(`❌ ${skillPath}: нет frontmatter`);
        hasError = true;
        continue;
    }

    const frontmatter = yaml.load(match[1]);
    if (!frontmatter.name) {
        console.error(`❌ ${skillPath}: отсутствует поле 'name'`);
        hasError = true;
    }
    if (!frontmatter.description) {
        console.error(`❌ ${skillPath}: отсутствует поле 'description'`);
        hasError = true;
    }
    if (frontmatter.name !== dir) {
        console.error(`❌ ${skillPath}: name '${frontmatter.name}' не совпадает с именем папки '${dir}'`);
        hasError = true;
    }
}

process.exit(hasError ? 1 : 0);