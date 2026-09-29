import { useEffect, useState } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'
import { Bell, ClipboardList, Home, LogOut, Package, Search, Store, UserRound } from 'lucide-react'
import { useAuth } from '../contexts/AuthContextValue'
import { supabase } from '../lib/supabase'

type Item = { to: string; label: string; icon: typeof Home; end?: boolean; query?: string }

export function Shell() {
  const { profile, session } = useAuth()
  const location = useLocation()
  const role = profile?.role
  const items: Item[] = role === 'customer'
    ? [{ to: '/', label: 'Home', icon: Home, end: true }, { to: '/search', label: 'Search', icon: Search }, { to: '/activity', label: 'Activity', icon: ClipboardList }, { to: '/notifications', label: 'Notifications', icon: Bell }, { to: '/profile', label: 'Profile', icon: UserRound }]
    : role === 'shopkeeper'
      ? [{ to: '/seller', label: 'Dashboard', icon: Home, end: true }, { to: '/seller/products', label: 'Products', icon: Package }, { to: '/seller/inquiries', label: 'Inquiries', icon: ClipboardList }, { to: '/seller/reservations', label: 'Reservations', icon: Bell }, { to: '/seller/shop', label: 'Shop', icon: Store }]
      : role === 'admin'
        ? [{ to: '/admin', label: 'Dashboard', icon: Home, end: true, query: 'overview' }, { to: '/admin?tab=users', label: 'Users', icon: UserRound, query: 'users' }, { to: '/admin?tab=shops', label: 'Shops', icon: Store, query: 'shops' }, { to: '/admin?tab=reports', label: 'Reports', icon: ClipboardList, query: 'reports' }]
        : [{ to: '/', label: 'Home', icon: Home, end: true }, { to: '/search', label: 'Search', icon: Search }]

  return <div className="app-shell">
    <header className="topbar">
      <Link to="/" className="brand" aria-label="Mohalla Mart home"><span className="brand-mark"><Store size={21} aria-hidden="true" /></span><span>mohalla<span className="brand-accent">mart</span><small>YOUR NEIGHBORHOOD, IN REACH</small></span></Link>
      <nav className="primary-nav" aria-label="Main navigation">
        {items.map(item => {
          const Icon = item.icon
          const selected = item.query ? (new URLSearchParams(location.search).get('tab') || 'overview') === item.query : undefined
          return <NavLink key={item.label} to={item.to} end={item.end} aria-current={selected ? 'page' : undefined} className={({ isActive }) => selected === undefined ? (isActive ? 'active' : '') : (selected ? 'active' : '')}>
            <Icon size={18} aria-hidden="true" /><span>{item.label}</span>{item.label === 'Notifications' && <NotificationCount />}
          </NavLink>
        })}
        {!session && <Link className="login-link" to="/login">Log in</Link>}
        {session && <button className="text-button logout-button" onClick={() => void supabase?.auth.signOut()}><LogOut size={16} aria-hidden="true" /><span>Log out</span></button>}
      </nav>
      {session && <button type="button" className="mobile-logout" aria-label="Log out" onClick={() => void supabase?.auth.signOut()}><LogOut size={19} aria-hidden="true" /></button>}
    </header>
    <main className="app-main"><Outlet /></main>
    <footer><Store size={15} aria-hidden="true" /> Shop small. Live local. <span>Discover Locally. Chat Directly. Buy Nearby.</span></footer>
  </div>
}

function NotificationCount() {
  const { session } = useAuth()
  const [unread, setUnread] = useState(0)
  useEffect(() => {
    const client = supabase
    if (!client || !session) return
    let alive = true
    const load = async () => {
      const { count } = await client.from('notifications').select('id', { count: 'exact', head: true }).eq('profile_id', session.user.id).is('read_at', null)
      if (alive) setUnread(count || 0)
    }
    void load()
    const channel = client.channel('header-notifications:' + session.user.id).on('postgres_changes', { event: '*', schema: 'public', table: 'notifications', filter: 'profile_id=eq.' + session.user.id }, () => void load()).subscribe()
    return () => { alive = false; void client.removeChannel(channel) }
  }, [session])
  return unread > 0 ? <b className="nav-unread" aria-label={unread + ' unread'}>{unread > 9 ? '9+' : unread}</b> : null
}