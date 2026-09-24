import {
  BrowserRouter,
  Navigate,
  Route,
  Routes,
} from 'react-router-dom'
import { lazy, Suspense } from 'react'
import { ProtectedRoute } from './components/ProtectedRoute'
import { AuthProvider } from './contexts/AuthContext'
import { useAuth } from './contexts/auth-context'
const DashboardPage = lazy(() => import('./pages/DashboardPage').then((module) => ({ default: module.DashboardPage })))
import { LoginPage } from './pages/LoginPage'
import { RegisterPage } from './pages/RegisterPage'
const OnboardingPage = lazy(() => import('./pages/OnboardingPage').then((module) => ({ default: module.OnboardingPage })))
import { LoadingState } from './components/DashboardStates'
import { AppErrorBoundary } from './components/AppErrorBoundary'
import { LandingPage } from './pages/LandingPage'

function RoleDashboard() {
  const { profile } = useAuth()
  const role = profile?.roles[0]?.code?.toLowerCase() ?? ''
  const staff = ['superadmin', 'manager', 'marketing', 'teller']
    .some((name) => role.includes(name))

  return <DashboardPage staff={staff} role={role} />
}

function StaffRoute({ role }: { role: string }) {
  const { profile } = useAuth()
  if (!profile?.roles.some((item) => item.code.toLowerCase() === role)) return <Navigate to="/" replace />
  return <DashboardPage staff role={role} />
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppErrorBoundary><Suspense fallback={<LoadingState />}><Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/daftar" element={<RegisterPage />} />
          <Route path="/nasabah/formulir" element={<ProtectedRoute><OnboardingPage /></ProtectedRoute>} />

          <Route path="/" element={<LandingPage />} />

          {['nasabah', 'teller', 'marketing', 'manager', 'superadmin'].map((role) => (
            <Route
              key={role}
              path={`/${role}`}
              element={
              <ProtectedRoute>
                {role === 'nasabah' ? <RoleDashboard /> : <StaffRoute role={role} />}
              </ProtectedRoute>
              }
            />
          ))}

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes></Suspense></AppErrorBoundary>
      </AuthProvider>
    </BrowserRouter>
  )
}
