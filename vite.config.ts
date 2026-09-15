import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import { sites } from '@openai/sites-vite-plugin'

export default defineConfig(async () => {
  const githubPages = process.env.GITHUB_PAGES === 'true'
  const base = githubPages ? '/afghanistan-business-ledger/' : '/'
  const hostingPlugins = githubPages ? [] : [sites(), (await import('@cloudflare/vite-plugin')).cloudflare()]
  return {
    base,
    plugins: [
      react(),
      ...hostingPlugins,
      VitePWA({
        registerType: 'autoUpdate',
        includeAssets: ['icon.svg', 'icon-192.png', 'icon-512.png', 'apple-touch-icon.png'],
        manifest: {
          name: 'Afghanistan Business Control',
          short_name: 'Business Control',
          description: 'Protected daily operations, cash control, inventory and financial reporting',
          theme_color: '#155e4b',
          background_color: '#f5f3ec',
          display: 'standalone',
          start_url: base,
          scope: base,
          icons: [
            { src: `${base}icon.svg`, sizes: 'any', type: 'image/svg+xml', purpose: 'any' },
            { src: `${base}icon-192.png`, sizes: '192x192', type: 'image/png', purpose: 'any' },
            { src: `${base}icon-512.png`, sizes: '512x512', type: 'image/png', purpose: 'any' },
            { src: `${base}icon-512.png`, sizes: '512x512', type: 'image/png', purpose: 'maskable' },
          ],
        },
      }),
    ],
  }
})
