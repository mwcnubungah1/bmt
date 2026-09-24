import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')

  return {
  envDir: process.cwd(),
  appType: 'spa',
  build: {
    rolldownOptions: {
      output: {
        codeSplitting: {
          groups: [{ name: 'supabase', test: /node_modules[\\/]@supabase/ }],
        },
      },
    },
  },
  server: {
    host: '127.0.0.1',
    port: 5173,
  },
  define: {
    'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(env.VITE_SUPABASE_URL),
    'import.meta.env.VITE_SUPABASE_ANON_KEY': JSON.stringify(env.VITE_SUPABASE_ANON_KEY),
  },
  plugins: [
    react(),
    tailwindcss(),
  ],
  }
})
