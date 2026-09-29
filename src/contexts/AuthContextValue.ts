import { createContext, useContext } from 'react'
import type { Session } from '@supabase/supabase-js'
import type { Profile } from '../types/database'

export type AuthValue = { session: Session | null; profile: Profile | null; loading: boolean; error: string | null; refreshProfile: () => Promise<Profile | null> }
export const AuthContext = createContext<AuthValue | null>(null)
export function useAuth() {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth must be used inside AuthProvider')
  return value
}