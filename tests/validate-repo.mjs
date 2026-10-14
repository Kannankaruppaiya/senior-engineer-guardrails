import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(import.meta.dirname, '..');
const skill = path.join(root, 'skills/senior-engineer-guardrails');
const text = fs.readFileSync(path.join(skill, 'SKILL.md'), 'utf8');
assert.match(text, /^---\r?\nname: senior-engineer-guardrails\r?\n/);
const description = text.match(/^description: (.+)$/m)?.[1];
assert.ok(description && description.length <= 1024, 'description length');
assert.ok(text.split('\n').length < 200, 'concise skill entrypoint');
assert.ok(!text.includes('TODO:') && !text.includes('[INSERT'), 'no scaffolding');

function files(directory) {
  return fs.readdirSync(directory, {withFileTypes: true}).flatMap(entry => {
    const p = path.join(directory, entry.name);
    return entry.isDirectory() ? files(p) : [p];
  });
}
for (const file of files(skill).filter(p => p.endsWith('.md'))) {
  const body = fs.readFileSync(file, 'utf8');
  for (const match of body.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const target = match[1];
    if (/^(https?:|#)/.test(target)) continue;
    const destination = path.resolve(path.dirname(file), target.split('#')[0]);
    assert.ok(destination.startsWith(`${root}${path.sep}`), `link escapes repository: ${target}`);
    assert.ok(fs.existsSync(destination), `missing reference in ${file}: ${target}`);
  }
}
for (const directory of ['.claude-plugin', 'tests']) {
  for (const file of fs.readdirSync(path.join(root, directory)).filter(p => p.endsWith('.json'))) {
    JSON.parse(fs.readFileSync(path.join(root, directory, file), 'utf8'));
  }
}
const plugin = JSON.parse(fs.readFileSync(path.join(root, '.claude-plugin/plugin.json'), 'utf8'));
const market = JSON.parse(fs.readFileSync(path.join(root, '.claude-plugin/marketplace.json'), 'utf8'));
assert.equal(plugin.name, 'senior-engineer-guardrails');
assert.match(plugin.version, /^\d+\.\d+\.\d+$/);
assert.equal(market.plugins[0].name, plugin.name);
assert.equal(market.plugins[0].source, './');
const evals = JSON.parse(fs.readFileSync(path.join(root, 'tests/skill-evals.json'), 'utf8'));
assert.equal(new Set(evals.evals.map(e => e.id)).size, evals.evals.length);
for (const evaluation of evals.evals) {
  assert.ok(evaluation.prompt && evaluation.expected_output);
  assert.ok(evaluation.assertions.length > 0);
  for (const assertion of evaluation.assertions) assert.equal(typeof assertion, 'string');
}
console.log('Repository JSON, manifests, frontmatter, reference links and evaluation catalog validated.');
