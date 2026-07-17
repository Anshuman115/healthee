// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// Strip Tailwind's `/*! … https://tailwindcss.com */` legal banner from the
// emitted CSS. Every minifier preserves `/*!` bang-comments on purpose, so the
// only reliable way to keep dist/ free of any external URL but the two cited
// competitor links is to remove it after the bundle is generated. The site
// loads nothing external either way; this just keeps the self-containment audit
// (grep dist/ for http) honest.
function stripCssBanner() {
  return {
    name: 'strip-css-legal-banner',
    apply: 'build',
    generateBundle(_options, bundle) {
      for (const file of Object.values(bundle)) {
        if (file.type === 'asset' && file.fileName.endsWith('.css') && typeof file.source === 'string') {
          file.source = file.source.replace(/\/\*![^]*?\*\//g, '');
        }
      }
    },
  };
}

// Self-contained static site: no adapter, no telemetry, no external assets.
// Tailwind v4 is wired through its Vite plugin (no @astrojs/tailwind needed).
// compressHTML must stay OFF: it strips whitespace-only text nodes at inline
// element boundaries, gluing words to <span> tags ("or itdoesn't").
export default defineConfig({
  compressHTML: false,
  vite: {
    plugins: [tailwindcss(), stripCssBanner()],
  },
});
