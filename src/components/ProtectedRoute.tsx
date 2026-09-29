import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContextValue'
import type { UserRole } from '../types/database'

export function ProtectedRoute({ roles }: { roles: UserRole[] }) {
  const { session, profile, loading, error, refreshProfile } = useAuth()
  const location = useLocation()
  if (loading) return <div className="page-state" role="status" aria-live="polite">Checking your session…</div>
  if (!session) return <Navigate to="/login" state={{ from: location }} replace />
  if (!profile) return <div className="page-state" role="alert"><h2>We couldn’t load your profile.</h2><p>{error || 'Check your connection, then try again.'}</p><button className="button secondary" onClick={() => void refreshProfile()}>Try again</button></div>
  return roles.includes(profile.role) ? <Outlet /> : <Navigate to={profile.role === 'shopkeeper' ? '/seller' : profile.role === 'admin' ? '/admin' : '/activity'} replace />
}