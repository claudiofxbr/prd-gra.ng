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

// connect-src: apenas para uso no CSP de prod (dev não recebe CSP)
const connectSrc = `connect-src 'self' ${apiOrigin}`

// CSP só é aplicado em produção — em dev bloqueia extensões do browser e chunks HMR
// sem oferecer nenhuma proteção real (ambiente local, sem dados reais em risco).
// Next.js 14 App Router com standalone output serve chunks externos (não inline), por
// isso 'unsafe-inline' em script-src pode ser omitido em prod com segurança.
const cspDirectives = [
  "default-src 'self'",
  "script-src 'self' 'wasm-unsafe-eval' 'inline-speculation-rules'",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' data: https://fonts.gstatic.com",
  "img-src 'self' data:",
  connectSrc,
  "frame-ancestors 'none'",
]

// Headers aplicados em todos os ambientes exceto o CSP (dev não recebe CSP)
const baseHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
]

const securityHeaders = isDev
  ? baseHeaders
  : [
      ...baseHeaders,
      { key: 'Content-Security-Policy', value: cspDirectives.join('; ') },
    ]

const BASE_PATH = '/prd-gra.ng'

const nextConfig = {
  output: isDev ? undefined : 'standalone',
  basePath: BASE_PATH,
  skipTrailingSlashRedirect: true,
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
