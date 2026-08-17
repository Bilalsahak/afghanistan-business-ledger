import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import { sites } from '@openai/sites-vite-plugin'

export default defineConfig(async () => {
  const { cloudflare } = await import('@cloudflare/vite-plugin')
  return { plugins: [react(), sites(), VitePWA({
    registerType: 'autoUpdate',
    includeAssets: ['icon.svg'],
    manifest: {
      name: 'Afghanistan Business Ledger', short_name: 'Business Ledger',
      description: 'Daily business entries and protected reports',
      theme_color: '#155e4b', background_color: '#f5f3ec', display: 'standalone',
      start_url: '/', scope: '/',
      icons: [{ src: '/icon.svg', sizes: 'any', type: 'image/svg+xml', purpose: 'any maskable' }]
    }
  }), cloudflare()]
  }
})
