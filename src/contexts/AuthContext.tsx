import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { formatUserError } from '../lib/errors'
import type { AuthProfile } from '../types/auth'
import { AuthContext } from './auth-context'

interface Props {
  children: ReactNode
}

export function AuthProvider({ children }: Props) {
  const profileRequest = useRef(0)
  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [profile, setProfile] = useState<AuthProfile | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadProfile = useCallback(async (userId: string) => {
    const requestId = ++profileRequest.current
    setError(null)

    const {
      data: profileRow,
      error: profileError,
    } = await supabase
      .from('user_profiles')
      .select('id, employee_no, full_name, email, is_active')
      .eq('id', userId)
      .maybeSingle()

    if (profileError) {
      throw new Error(
        formatUserError(profileError),
      )
    }

    if (!profileRow) {
      setProfile(null)
      await supabase.auth.signOut()
      throw new Error('Sesi login tidak terdaftar pada database BMT. Silakan login ulang melalui instance BMT.')
    }

    const [roleResult, branchResult] = await Promise.all([
      supabase
        .from('user_roles')
        .select('branch_id, roles (code, name)')
        .eq('user_id', userId)
        .eq('is_active', true),
      supabase
        .from('user_branches')
        .select('branches (id, code, name)')
        .eq('user_id', userId),
    ])

    if (roleResult.error) throw new Error(formatUserError(roleResult.error))
    if (branchResult.error) throw new Error(formatUserError(branchResult.error))

    const roles = (roleResult.data ?? []).flatMap((row) => {
      const role = Array.isArray(row.roles)
        ? row.roles[0]
        : row.roles

      if (!role) return []

      return [{
        code: role.code,
        name: role.name,
        branchId: row.branch_id,
      }]
    })

    const branches = (branchResult.data ?? []).flatMap((row) => {
      const branch = Array.isArray(row.branches)
        ? row.branches[0]
        : row.branches

      if (!branch) return []

      return [{
        id: branch.id,
        code: branch.code,
        name: branch.name,
      }]
    })

    if (requestId !== profileRequest.current) return
    setProfile({
      id: profileRow.id,
      employeeNo: profileRow.employee_no,
      fullName: profileRow.full_name,
      email: profileRow.email,
      isActive: profileRow.is_active,
      roles,
      branches,
    })

    setError(null)
  }, [])

  const refreshProfile = useCallback(async () => {
    if (!user) return

    try {
      await loadProfile(user.id)
    } catch (err) {
      setProfile(null)
      setError(formatUserError(err))
    }
  }, [user, loadProfile])

  useEffect(() => {
    let mounted = true

    const initialize = async () => {
      try {
        const {
          data: { session: initialSession },
          error: sessionError,
        } = await supabase.auth.getSession()

        if (sessionError) throw sessionError
        if (!mounted) return

        setSession(initialSession)
        setUser(initialSession?.user ?? null)

        if (initialSession?.user) {
          await loadProfile(initialSession.user.id)
        } else {
          setProfile(null)
        }
      } catch (err) {
        if (!mounted) return

        setProfile(null)
        setError(formatUserError(err))
      } finally {
        if (mounted) {
          setLoading(false)
        }
      }
    }

    void initialize()

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(
      (_event, nextSession) => {
        if (!mounted) return

        setSession(nextSession)
        setUser(nextSession?.user ?? null)

        if (!nextSession?.user) {
          profileRequest.current += 1
          setProfile(null)
          setError(null)
          setLoading(false)
          return
        }

        setError(null)

        void loadProfile(nextSession.user.id)
          .catch((err) => {
            if (!mounted) return

            setProfile(null)
            setError(formatUserError(err))
          })
          .finally(() => {
            if (mounted) {
              setLoading(false)
            }
          })
      },
    )

    return () => {
      mounted = false
      profileRequest.current += 1
      subscription.unsubscribe()
    }
  }, [loadProfile])

  const signIn = useCallback(
    async (email: string, password: string) => {
      setLoading(true)
      setError(null)

      try {
        const {
          data,
          error: signInError,
        } = await supabase.auth.signInWithPassword({
          email,
          password,
        })

        if (signInError) throw signInError
        if (!data.user) {
          throw new Error('User tidak ditemukan')
        }

        setSession(data.session)
        setUser(data.user)

        await loadProfile(data.user.id)
      } catch (err) {
        setProfile(null)
        setError(formatUserError(err))
        throw err
      } finally {
        setLoading(false)
      }
    },
    [loadProfile],
  )

  const signUp = useCallback(
    async ({ email, password, fullName, phone }: { email: string; password: string; fullName: string; phone: string }) => {
      setLoading(true)
      setError(null)

      try {
        const { data, error: signUpError } = await supabase.auth.signUp({
          email,
          password,
          options: { data: { full_name: fullName, phone } },
        })

        if (signUpError) throw signUpError
        if (data.session) await supabase.auth.signOut()
      } catch (err) {
        setError(formatUserError(err))
        throw err
      } finally {
        setLoading(false)
      }
    },
    [],
  )

  const signOut = useCallback(async () => {
    setLoading(true)

    try {
      const { error: signOutError } =
        await supabase.auth.signOut()

      if (signOutError) throw signOutError

      setSession(null)
      setUser(null)
      setProfile(null)
      setError(null)
    } finally {
      setLoading(false)
    }
  }, [])

  const value = useMemo(
    () => ({
      user,
      session,
      profile,
      loading,
      error,
      signIn,
      signUp,
      signOut,
      refreshProfile,
    }),
    [
      user,
      session,
      profile,
      loading,
      error,
      signIn,
      signUp,
      signOut,
      refreshProfile,
    ],
  )

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}
