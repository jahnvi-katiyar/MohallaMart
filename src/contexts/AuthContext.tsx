import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { isSupabaseConfigured, supabase } from '../lib/supabase'
import type { Profile } from '../types/database'
import { AuthContext } from './AuthContextValue'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [profile, setProfile] = useState<Profile | null>(null)
  const [loading, setLoading] = useState(Boolean(supabase))
  const [error, setError] = useState<string | null>(null)
  const currentUserId = useRef<string | null>(null)

  const refreshProfile = useCallback(async () => {
    const client = supabase
    if (!client) { setProfile(null); return null }
    const { data: userData, error: userError } = await client.auth.getUser()
    if (userError || !userData.user) { setProfile(null); if (userError) setError(userError.message); return null }
    const { data, error: queryError } = await client.from('profiles').select('*').eq('id', userData.user.id).maybeSingle()
    if (queryError) { setError(queryError.message); setProfile(null); return null }
    setError(null)
    const next = data as Profile | null
    setProfile(next)
    return next
  }, [])

  useEffect(() => {
    const client = supabase
    if (!client) return
    let alive = true
    const acceptSession = (next: Session | null) => {
      const previousUserId = currentUserId.current
      currentUserId.current = next?.user.id ?? null
      setSession(next)
      if (!next) { setProfile(null); setError(null); setLoading(false) }
      else if (previousUserId !== next.user.id) { setProfile(null); setLoading(true) }
    }
    client.auth.getSession().then(({ data, error: sessionError }) => {
      if (!alive) return
      if (sessionError) setError(sessionError.message)
      acceptSession(data.session)
    }).catch(reason => {
      if (!alive) return
      setError(reason instanceof Error ? reason.message : 'Unable to restore your session.')
      setLoading(false)
    })
    const { data: listener } = client.auth.onAuthStateChange((_event, value) => acceptSession(value))
    return () => { alive = false; listener.subscription.unsubscribe() }
  }, [])

  useEffect(() => {
    const client = supabase
    const userId = session?.user.id
    if (!userId || !client) return
    let alive = true
    const load = async () => {
      const { data, error: queryError } = await client.from('profiles').select('*').eq('id', userId).maybeSingle()
      if (!alive) return
      if (queryError) { setError(queryError.message); setProfile(null) }
      else { setError(null); setProfile(data as Profile | null) }
      setLoading(false)
    }
    void load()
    return () => { alive = false }
  }, [session?.user.id])

  const value = useMemo(() => ({ session, profile, loading, error: isSupabaseConfigured ? error : 'Add Supabase URL and publishable key to .env.local.', refreshProfile }), [session, profile, loading, error, refreshProfile])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
