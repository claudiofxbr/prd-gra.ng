'use client'

import Link from 'next/link'
import { usePathname, useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'
import { clearAuth, getAuth } from '@/lib/auth'
import { api } from '@/lib/api'
import ThemeSelector from '@/components/ThemeSelector'
import type { AuthUser } from '@/types'

export default function Navbar() {
  const router   = useRouter()
  const pathname = usePathname()
  const [user, setUser] = useState<AuthUser | null>(null)

  useEffect(() => { setUser(getAuth()) }, [])

  async function handleLogout() {
    try {
      await api.auth.logout() // expira o cookie HttpOnly no backend
    } catch {
      // ignora erros de rede — limpa sessão local de qualquer forma
    }
    clearAuth()
    router.replace('/login')
  }

  function activeStyle(href: string): React.CSSProperties {
    const on = pathname === href || pathname.startsWith(href + '/')
    return {
      color:      on ? 'var(--accent-text)' : 'var(--content-secondary)',
      fontWeight: on ? 600 : 400,
    }
  }

  return (
    <nav className="navbar">
      {/* Logo */}
      <Link href="/" className="font-bold text-xl" style={{ color: 'var(--accent)' }}>
        PRD-GRA
      </Link>

      {/* Links centrais — só quando autenticado */}
      {user && (
        <div className="hidden sm:flex items-center gap-1">
          <Link href="/dashboard" className="btn-ghost text-sm" style={activeStyle('/dashboard')}>
            Dashboard
          </Link>
          <Link href="/prd" className="btn-ghost text-sm" style={activeStyle('/prd')}>
            Meus PRDs
          </Link>
        </div>
      )}

      {/* Direita */}
      <div className="flex items-center gap-2">
        <ThemeSelector />

        {user ? (
          <>
            <Link href="/prd/new" className="btn-primary text-sm py-1.5 px-3 hidden sm:inline-flex">
              + Novo
            </Link>
            <div className="hidden sm:flex items-center gap-2 pl-2"
              style={{ borderLeft: '1px solid var(--surface-border)' }}>
              <span className="text-sm" style={{ color: 'var(--content-muted)' }}>{user.name}</span>
              <button onClick={handleLogout} className="btn-danger text-xs px-2 py-1">Sair</button>
            </div>
            {/* Mobile compacto */}
            <div className="sm:hidden flex items-center gap-1">
              <Link href="/dashboard" className="btn-ghost p-2" title="Dashboard">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round"
                    d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
              </Link>
              <button onClick={handleLogout} className="btn-ghost p-2" title="Sair">
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round"
                    d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
              </button>
            </div>
          </>
        ) : (
          <>
            <Link href="/login"    className="btn-ghost text-sm">Entrar</Link>
            <Link href="/register" className="btn-primary text-sm py-1.5 px-3">Criar Conta</Link>
          </>
        )}
      </div>
    </nav>
  )
}
