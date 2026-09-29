import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { KeyRound, UserRound } from 'lucide-react'
import { useAuth } from '../contexts/AuthContextValue'
import { supabase } from '../lib/supabase'
import { ErrorState, SuccessState } from '../components/CustomerComponents'

export function CustomerProfilePage() {
  const { profile, session, refreshProfile } = useAuth()
  const [name, setName] = useState(profile?.full_name ?? '')
  const [phone, setPhone] = useState(profile?.phone ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  async function save(event: FormEvent) {
    event.preventDefault()
    if (!supabase || !session) { setError('Please sign in again to update your profile.'); return }
    const fullName = name.trim()
    if (fullName.length < 2 || fullName.length > 100) { setError('Name must be between 2 and 100 characters.'); return }
    setBusy(true); setError(''); setSuccess('')
    const { error: updateError } = await supabase.from('profiles').update({ full_name: fullName, phone: phone.trim() || null }).eq('id', session.user.id)
    setBusy(false)
    if (updateError) { setError(updateError.message); return }
    await refreshProfile()
    setSuccess('Your profile has been updated.')
  }

  return <section className="content-page profile-page">
    <div className="eyebrow">YOUR ACCOUNT</div><h1>Profile</h1><p className="page-intro">Manage the contact details shops use when you make an inquiry or reservation.</p>
    <div className="profile-card"><span className="profile-icon"><UserRound size={23} aria-hidden="true" /></span>
      <form className="auth-form" onSubmit={event => void save(event)}>
        <label htmlFor="profile-name">Full name</label><input id="profile-name" autoComplete="name" required minLength={2} maxLength={100} value={name} onChange={event => setName(event.target.value)} />
        <label htmlFor="profile-email">Email address</label><input id="profile-email" type="email" value={session?.user.email ?? ''} readOnly aria-describedby="email-note" /><small id="email-note">Email is managed by your sign-in provider.</small>
        <label htmlFor="profile-phone">Phone (optional)</label><input id="profile-phone" type="tel" autoComplete="tel" maxLength={25} value={phone} onChange={event => setPhone(event.target.value)} />
        {error && <ErrorState message={error} />}{success && <SuccessState message={success} />}
        <button className="button primary" type="submit" disabled={busy}>{busy ? 'Saving…' : 'Save profile'}</button>
      </form>
      <Link className="profile-password-link" to="/forgot-password"><KeyRound size={16} aria-hidden="true" /> Change password</Link>
      <p className="profile-role">Account type: <b>{profile?.role ?? 'Customer'}</b></p>
    </div>
  </section>
}