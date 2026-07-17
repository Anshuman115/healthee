// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// Self-contained static site: no adapter, no telemetry, no external assets.
// Tailwind v4 is wired through its Vite plugin (no @astrojs/tailwind needed).
export default defineConfig({
  vite: {
    plugins: [tailwindcss()],
  },
});
