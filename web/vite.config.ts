import tailwindcss from '@tailwindcss/vite'
import { tanstackRouter } from '@tanstack/router-plugin/vite'
import react from '@vitejs/plugin-react'
import type { ProxyOptions } from 'vite'
import { defineConfig } from 'vitest/config'

const api = process.env.VITE_API_TARGET ?? 'http://localhost:4000'

// Como um proxy reverso: o site público vai em X-Forwarded-Host (o servidor confere o Origin com ele).
const forward = (target: string): ProxyOptions => ({
  target,
  configure: (proxy) => {
    proxy.on('proxyReq', (proxyReq, req) => {
      if (req.headers.host) proxyReq.setHeader('X-Forwarded-Host', req.headers.host)
    })
  },
})

export default defineConfig({
  plugins: [
    tanstackRouter({
      target: 'react',
      autoCodeSplitting: true,
      routeFileIgnorePattern: '\\.test\\.',
    }),
    react(),
    tailwindcss(),
  ],
  server: {
    host: true,
    proxy: {
      '/api': forward(api),
      '/auth': forward(api),
      '/cable': { ...forward(api), ws: true },
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    globals: false,
  },
})
