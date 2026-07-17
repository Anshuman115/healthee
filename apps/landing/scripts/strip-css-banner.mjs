// Post-build: strip the Tailwind license banner (a `/*! … https://tailwindcss.com */`
// legal comment) from the minified CSS. It is a same-origin comment, not a network
// load — but removing it keeps dist/ honest: the only external URLs that remain are
// the two cited competitor links and the SVG namespace. Fails loudly if it can't run.
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const cssDir = new URL('../dist/_astro/', import.meta.url);
const banner = /\/\*![^*]*\*+([^/*][^*]*\*+)*\//g; // /*! … */ legal comments

const files = (await readdir(cssDir)).filter((f) => f.endsWith('.css'));
let stripped = 0;
for (const f of files) {
  const path = join(cssDir.pathname, f);
  const before = await readFile(path, 'utf8');
  const after = before.replace(banner, '');
  if (after !== before) {
    await writeFile(path, after);
    stripped += 1;
  }
}
console.log(`strip-css-banner: cleaned ${stripped}/${files.length} css file(s)`);
