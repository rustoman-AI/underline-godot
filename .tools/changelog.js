// Regenerates docs/CHANGELOG.md from git. Run: node .tools/changelog.js
// The milestones block is hand-written (edit MILESTONES below); the daily list is generated.
const { execSync } = require('child_process');
const fs = require('fs');

const MILESTONES = [
  ['2026-10-02', 'Старт: симуляция станции, разрез, экономика, GDD v2'],
  ['2026-10-10', 'Карта сети (стол надзирателя), проверки событий, меню и сохранения, экспорт'],
  ['2026-10-11', 'Лидеры и аудиенции, озвучка 112 + 110 строк, сюжетный костяк (осколки, бункеры, 8 концовок), первая закрытая сборка'],
  ['2026-10-12', 'Ночной QA, портреты по полу и досье, вторая и третья сборки (0.1.0-playtest2, 3, 4), первый внешний отзыв']
];

const raw = execSync('git log --reverse --format=%ad%x09%h%x09%s --date=short', { encoding: 'utf8', cwd: __dirname + '/..' });
const rows = raw.trim().split('\n').map(l => l.split('\t'));
const byDay = {};
for (const [d, h, ...s] of rows) (byDay[d] = byDay[d] || []).push([h, s.join('\t')]);

let out = '# Журнал изменений Underline\n\n';
out += 'Генерируется из git командой `node .tools/changelog.js`. Блок «Этапы» правится вручную в этом скрипте.\n\n';
out += `Коммитов: ${rows.length}. Первый: ${rows[0][0]}. Последний: ${rows[rows.length - 1][0]} ${rows[rows.length - 1][1]}.\n\n`;
out += '## Этапы\n\n';
for (const [d, t] of MILESTONES) out += `- **${d}.** ${t}\n`;
out += '\n## Сборки для плейтеста\n\n';
const builds = rows.filter(r => /Playtest build/i.test(r[2]));
for (const [d, h, s] of builds) out += `- ${d} \`${h}\` ${s}\n`;
out += '\n## По дням (новое сверху)\n\n';
for (const d of Object.keys(byDay).sort().reverse()) {
  out += `### ${d} (${byDay[d].length})\n\n`;
  for (const [h, s] of byDay[d].slice().reverse()) out += `- \`${h}\` ${s}\n`;
  out += '\n';
}
fs.writeFileSync(__dirname + '/../docs/CHANGELOG.md', out);
console.log('docs/CHANGELOG.md', rows.length, 'commits,', Object.keys(byDay).length, 'days');
