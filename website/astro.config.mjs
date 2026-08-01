import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import mermaid from 'astro-mermaid';

export default defineConfig({
  site: 'https://larsboes.github.io/mach-mono',
  base: '/mach-mono',
  integrations: [
    mermaid(),
    starlight({
      title: 'mach',
      description: 'Focused macOS utilities — built on a plugin-first architecture.',
      disable404Route: true,
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/larsboes/mach-mono' },
      ],
      customCss: ['./src/styles/starlight.css'],
      sidebar: [
        {
          label: 'Architecture',
          collapsed: true,
          items: [
            { label: 'Overview', link: '/architecture' },
          ],
        },
        {
          label: 'Project',
          items: [
            { label: 'Roadmap', link: '/roadmap' },
            { label: 'Changelog', link: '/changelog' },
          ],
        },
      ],
    }),
  ],
  vite: {
    server: {
      fs: {
        // Allow serving files from the monorepo root (CHANGELOG.md, ROADMAP.md, docs/*)
        allow: ['..'],
      },
    },
    build: {
      chunkSizeWarningLimit: 700,
    },
  },
});
