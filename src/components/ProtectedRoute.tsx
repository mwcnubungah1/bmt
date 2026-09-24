import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../contexts/auth-context'

interface Props {
  children: ReactNode
}

export function ProtectedRoute({ children }: Props) {
  const { user, profile, error, loading, refreshProfile, signOut } = useAuth()

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-950 text-slate-200">
        Memuat BMT Core Banking...
      </div>
    )
  }

  if (!user) {
    return <Navigate to="/login" replace />
  }

  if (error || !profile || !profile.isActive) {
    return <main className="mx-auto max-w-lg space-y-4 p-6" role="alert">
      <h1 className="text-xl font-bold">Akses belum tersedia</h1>
      <p>{error ?? 'Profil Anda belum aktif. Hubungi petugas BMT.'}</p>
      <button onClick={() => void refreshProfile()} className="rounded-xl bg-green-700 px-4 text-white">Coba lagi</button>
      <button onClick={() => void signOut()} className="ml-3 px-4">Keluar</button>
    </main>
  }

  return <>{children}</>
}
