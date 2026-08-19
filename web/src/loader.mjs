async function loadSource(manifestPath) {
  const manifestUrl = new URL(manifestPath, import.meta.url);
  const response = await fetch(manifestUrl);
  if (!response.ok) throw new Error(`Unable to load ${manifestUrl.pathname}`);
  const manifest = await response.json();
  if (!Array.isArray(manifest.parts) || manifest.parts.length === 0) {
    throw new Error(`Invalid source manifest: ${manifestUrl.pathname}`);
  }
  const directory = new URL('./', manifestUrl);
  const parts = [];
  for (const name of manifest.parts) {
    const partUrl = new URL(name, directory);
    const partResponse = await fetch(partUrl);
    if (!partResponse.ok) throw new Error(`Unable to load ${partUrl.pathname}`);
    parts.push(await partResponse.text());
  }
  return parts.join('');
}

const simSource = await loadSource('../source/sim/manifest.json');
const simUrl = URL.createObjectURL(new Blob([simSource], { type: 'text/javascript' }));
const gameSource = (await loadSource('../source/game/manifest.json'))
  .replace("from './sim.mjs';", `from '${simUrl}';`);
const gameUrl = URL.createObjectURL(new Blob([gameSource], { type: 'text/javascript' }));

try {
  await import(gameUrl);
} catch (error) {
  console.error(error);
  const loading = document.querySelector('#loading');
  if (loading) loading.textContent = `Prototype failed to start: ${error.message}`;
  throw error;
}
