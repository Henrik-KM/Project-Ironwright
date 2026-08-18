import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, '..', '..');

export async function readSegmentedSource(kind) {
  const directory = resolve(ROOT, 'web', 'source', kind);
  const manifest = JSON.parse(await readFile(resolve(directory, 'manifest.json'), 'utf8'));
  if (!Array.isArray(manifest.parts) || manifest.parts.length === 0) {
    throw new Error(`Invalid ${kind} source manifest`);
  }
  return (await Promise.all(manifest.parts.map((part) => readFile(resolve(directory, part), 'utf8')))).join('');
}

export async function loadSimulationModule() {
  const source = await readSegmentedSource('sim');
  return import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
}

export async function writeTemporarySources() {
  const directory = await mkdtemp(resolve(tmpdir(), 'ironwright-source-'));
  const simPath = resolve(directory, 'sim.mjs');
  const gamePath = resolve(directory, 'game.mjs');
  await writeFile(simPath, await readSegmentedSource('sim'));
  await writeFile(gamePath, await readSegmentedSource('game'));
  return {
    directory,
    simPath,
    gamePath,
    simUrl: pathToFileURL(simPath).href,
    cleanup: () => rm(directory, { recursive: true, force: true }),
  };
}
