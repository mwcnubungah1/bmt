import { createContext, useContext } from 'react'
import type { Session, User } from '@supabase/supabase-js'
import type { AuthProfile } from '../types/auth'

export interface AuthContextValue {
  user: User | null
  session: Session | null
  profile: AuthProfile | null
  loading: boolean
  error: string | null
  signIn: (email: string, password: string) => Promise<void>
  signUp: (input: { email: string; password: string; fullName: string; phone: string }) => Promise<void>
  signOut: () => Promise<void>
  refreshProfile: () => Promise<void>
}

export const AuthContext =
  createContext<AuthContextValue | undefined>(undefined)

export function useAuth() {
  const context = useContext(AuthContext)

  if (!context) {
    throw new Error('useAuth harus digunakan di dalam AuthProvider')
  }

  return context
}
