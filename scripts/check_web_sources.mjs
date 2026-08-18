import { spawnSync } from 'node:child_process';
import { readFile, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

async function source(kind) {
  const directory = resolve(ROOT, 'web', 'source', kind);
  const manifest = JSON.parse(await readFile(resolve(directory, 'manifest.json'), 'utf8'));
  return (await Promise.all(manifest.parts.map((name) => readFile(resolve(directory, name), 'utf8')))).join('');
}

const directory = await mkdtemp(resolve(tmpdir(), 'ironwright-check-'));
try {
  const simPath = resolve(directory, 'sim.mjs');
  const gamePath = resolve(directory, 'game.mjs');
  await writeFile(simPath, await source('sim'));
  await writeFile(gamePath, await source('game'));
  for (const file of [simPath, gamePath]) {
    const result = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
    if (result.status !== 0) {
      process.stderr.write(result.stderr || result.stdout);
      process.exit(result.status || 1);
    }
  }
  console.log('Segmented browser sources parse successfully.');
} finally {
  await rm(directory, { recursive: true, force: true });
}
