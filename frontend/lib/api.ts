const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8080/api'
const TIMEOUT_MS = 15_000

// Garante que apenas uma tentativa de refresh ocorre por vez (evita loop em race conditions)
let refreshing: Promise<boolean> | null = null

async function tryRefresh(): Promise<boolean> {
  if (refreshing) return refreshing
  refreshing = (async () => {
    try {
      const res = await fetch(`${API_URL}/auth/refresh`, {
        method: 'POST',
        credentials: 'include',
      })
      return res.ok
    } catch {
      return false
    } finally {
      refreshing = null
    }
  })()
  return refreshing
}

async function apiFetch<T>(path: string, options?: RequestInit, isRetry = false): Promise<T> {
  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...options?.headers,
  }

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)

  let res: Response
  try {
    res = await fetch(`${API_URL}${path}`, {
      ...options,
      headers,
      credentials: 'include',
      signal: controller.signal,
    })
  } catch (e) {
    clearTimeout(timer)
    if (e instanceof DOMException && e.name === 'AbortError') {
      throw new Error('Tempo limite da requisição esgotado')
    }
    throw e
  } finally {
    clearTimeout(timer)
  }

  if (res.status === 401 && !isRetry) {
    // Access token expirado — tenta renovar via refresh token (cookie HttpOnly)
    const refreshed = await tryRefresh()
    if (refreshed) {
      return apiFetch<T>(path, options, true)
    }
    // Refresh também falhou — sessão encerrada
    if (typeof window !== 'undefined') {
      const { clearAuth } = await import('@/lib/auth')
      clearAuth()
      // basePath '/prd-gra.ng' e aplicado pelo Next.js no lado do servidor,
      // mas window.location.href e navegacao direta — precisa do prefixo completo.
      const base = process.env.NEXT_PUBLIC_BASE_PATH ?? ''
      window.location.href = `${base}/login`
    }
    return undefined as T
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }))
    throw new Error(err.detail ?? 'Erro na requisição')
  }
  if (res.status === 204) return undefined as T
  return res.json()
}

export const api = {
  auth: {
    register: (body: { name: string; email: string; password: string }) =>
      apiFetch<import('@/types').UserResponse>('/auth/register', {
        method: 'POST',
        body: JSON.stringify(body),
      }),
    login: (body: { email: string; password: string }) =>
      apiFetch<import('@/types').UserResponse>('/auth/login', {
        method: 'POST',
        body: JSON.stringify(body),
      }),
    refresh: () =>
      apiFetch<import('@/types').UserResponse>('/auth/refresh', { method: 'POST' }),
    logout: () =>
      apiFetch<void>('/auth/logout', { method: 'POST' }),
  },
  prds: {
    list: (page = 0, size = 20) =>
      apiFetch<import('@/types').PageResponse<import('@/types').PrdResponse>>(
        `/prds?page=${page}&size=${size}`
      ),
    summary: () =>
      apiFetch<import('@/types').PrdSummaryResponse>('/prds/summary'),
    get: (id: string) => apiFetch<import('@/types').PrdResponse>(`/prds/${id}`),
    create: (body: import('@/types').PrdRequest) =>
      apiFetch<import('@/types').PrdResponse>('/prds', {
        method: 'POST',
        body: JSON.stringify(body),
      }),
    update: (id: string, body: import('@/types').PrdRequest) =>
      apiFetch<import('@/types').PrdResponse>(`/prds/${id}`, {
        method: 'PUT',
        body: JSON.stringify(body),
      }),
    delete: (id: string) =>
      apiFetch<void>(`/prds/${id}`, { method: 'DELETE' }),
  },
}
