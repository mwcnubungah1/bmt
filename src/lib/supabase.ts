import { createClient } from '@supabase/supabase-js'
import type { Database } from '../types/database'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Supabase environment variables are not configured')
}

if (supabaseAnonKey.startsWith('sb_secret_')) {
  throw new Error('Frontend requires a publishable or anon Supabase key')
}
if (supabaseAnonKey.split('.').length === 3) {
  const payload = JSON.parse(atob(supabaseAnonKey.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')))
  if (payload.role !== 'anon') throw new Error('Frontend requires an anon Supabase key')
}

export const supabase = createClient<Database, 'bmt_db'>(
  supabaseUrl,
  supabaseAnonKey,
  {
    db: {
      schema: 'bmt_db',
    },
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
    },
  },
)
