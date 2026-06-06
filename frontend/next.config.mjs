/** @type {import('next').NextConfig} */
const isDev = process.env.NODE_ENV !== 'production'

// Extrair apenas a origem (scheme://host:port) da variavel de ambiente.
// NEXT_PUBLIC_API_URL pode ser "http://localhost:8080/api" ou "https://api.exemplo.com/api"
// O CSP connect-src precisa da ORIGEM, nao do path — o browser valida por origem, nao por prefixo de path.
function extractOrigin(urlWithPath) {
  try {
    const u = new URL(urlWithPath)
    return u.origin  // ex: "http://localhost:8080"
  } catch {
    return urlWithPath
  }
}

const rawApiUrl  = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8080/api'
const apiOrigin  = extractOrigin(rawApiUrl)  // "http://localhost:8080"

// connect-src: origem da API + websocket HMR em dev
const connectSrc = isDev
  ? `connect-src 'self' ${apiOrigin} ws://localhost:3000 wss://localhost:3000`
  : `connect-src 'self' ${apiOrigin}`

// Em dev o CSP omite script-src para não bloquear chunks dinâmicos do webpack HMR
// e extensões do browser. Em prod aplica-se política restrita.
const cspDirectives = isDev
  ? [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' data: https://fonts.gstatic.com",
      "img-src 'self' data: blob:",
      connectSrc,
      "frame-ancestors 'none'",
    ]
  : [
      "default-src 'self'",
      // 'unsafe-inline' removido: Next.js 14 App Router emite scripts como chunks externos,
      // não como inline. Se quebrar em prod, adicionar nonce via middleware (ver CLAUDE.md).
      "script-src 'self'",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' data: https://fonts.gstatic.com",
      "img-src 'self' data:",
      connectSrc,
      "frame-ancestors 'none'",
    ]

const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  // DENY é consistente com frame-ancestors 'none' no CSP — SAMEORIGIN contradizia a política.
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  {
    key: 'Content-Security-Policy',
    value: cspDirectives.join('; '),
  },
]

const BASE_PATH = '/prd-gra.ng'

const nextConfig = {
  output: isDev ? undefined : 'standalone',
  basePath: BASE_PATH,
  env: {
    NEXT_PUBLIC_BASE_PATH: BASE_PATH,
  },
  // typedRoutes promovido para estavel no Next.js 15 — saiu do bloco experimental
  ...(isDev ? {} : { typedRoutes: true }),
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: securityHeaders,
      },
    ]
  },
}

export default nextConfig
