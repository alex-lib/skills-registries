const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const skillsDir = 'skills';
const catalog = [];

for (const dir of fs.readdirSync(skillsDir)) {
    const skillPath = path.join(skillsDir, dir, 'SKILL.md');
    if (!fs.existsSync(skillPath)) continue;

    const content = fs.readFileSync(skillPath, 'utf8');
    const match = content.match(/^---\n([\s\S]*?)\n---/);
    if (!match) continue;

    const frontmatter = yaml.load(match[1]);
    catalog.push({
        name: frontmatter.name,
        description: frontmatter.description,
        path: `skills/${dir}/SKILL.md`,
    });
}

fs.writeFileSync('catalog.json', JSON.stringify({ skills: catalog }, null, 2));
console.log(`Сгенерирован catalog.json с ${catalog.length} скилами`);