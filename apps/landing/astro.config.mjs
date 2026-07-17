// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// Self-contained static site: no adapter, no telemetry, no external assets.
// Tailwind v4 is wired through its Vite plugin (no @astrojs/tailwind needed).
// compressHTML must stay OFF: it strips whitespace-only text nodes at inline
// element boundaries, gluing words to <span>/<sup> citations ("or itdoesn't").
export default defineConfig({
  compressHTML: false,
  vite: {
    plugins: [tailwindcss()],
  },
});
