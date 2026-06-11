import type { AuthUser } from '@/types'

const COOKIE_USER = 'prdgra_user'
const MAX_AGE     = 60 * 60 * 24 * 30 // 30 dias — alinhado com o refresh token do backend

// Apenas o cookie de perfil do usuário (não-sensível) é gerenciado pelo JS.
// O token JWT é gerenciado exclusivamente pelo backend via Set-Cookie HttpOnly.

function setCookie(name: string, value: string): void {
  const secure = location.protocol === 'https:' ? '; Secure' : ''
  document.cookie = `${name}=${encodeURIComponent(value)}; Max-Age=${MAX_AGE}; Path=/; SameSite=Strict${secure}`
}

function getCookie(name: string): string | null {
  if (typeof document === 'undefined') return null
  const match = document.cookie
    .split('; ')
    .find((row) => row.startsWith(`${name}=`))
  return match ? decodeURIComponent(match.split('=').slice(1).join('=')) : null
}

function deleteCookie(name: string): void {
  document.cookie = `${name}=; Max-Age=0; Path=/; SameSite=Strict`
}

export function saveAuth(user: AuthUser): void {
  // Salva apenas o perfil (nome, email, role) — token vai no cookie HttpOnly do backend
  setCookie(COOKIE_USER, JSON.stringify(user))
}

export function getAuth(): AuthUser | null {
  if (typeof window === 'undefined') return null
  try {
    const raw = getCookie(COOKIE_USER)
    return raw ? (JSON.parse(raw) as AuthUser) : null
  } catch {
    clearAuth()
    return null
  }
}

export function clearAuth(): void {
  deleteCookie(COOKIE_USER)
  // O cookie HttpOnly prdgra_token é expirado pelo endpoint POST /auth/logout no backend
}

// Verifica apenas o cookie de perfil (JS-readable).
// prdgra_token é HttpOnly — cookies HttpOnly são completamente invisíveis ao JavaScript por spec.
// A proteção real da sessão é feita pelo middleware Next.js (server-side) que lê o cookie HttpOnly.
// Esta função serve apenas para evitar flash de conteúdo protegido antes do middleware atuar.
export function isAuthenticated(): boolean {
  return getAuth() !== null
}
