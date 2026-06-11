/** @type {import('next').NextConfig} */
const isDev = process.env.NODE_ENV !== 'production'

// Extrair apenas a origem (scheme://host:port) da variavel de ambiente.
// NEXT_PUBLIC_API_URL pode ser "http://localhost:8080/api" ou "/api" (relativa).
// O CSP connect-src precisa da ORIGEM, nao do path — o browser valida por origem, nao por prefixo de path.
function extractOrigin(urlWithPath) {
  try {
    const u = new URL(urlWithPath)
    return u.origin  // ex: "http://localhost:8080"
  } catch {
    return urlWithPath
  }
}

const rawApiUrl  = process.env.NEXT_PUBLIC_API_URL ?? ''
// Se a URL for relativa ("/api") ou vazia, 'self' no connect-src já cobre — não adicionar origem extra.
const apiOrigin  = rawApiUrl.startsWith('http') ? extractOrigin(rawApiUrl) : ''

// connect-src: 'self' cobre APIs relativas; adiciona origem explícita só quando é cross-origin.
const connectSrc = apiOrigin
  ? `connect-src 'self' ${apiOrigin}`
  : "connect-src 'self'"

// CSP aplicado em todos os ambientes (dev e prod).
// Next.js 15 App Router com SSR injeta __NEXT_DATA__ e scripts de hydration inline —
// 'unsafe-inline' é obrigatório em script-src sem middleware de nonce.
const cspDirectives = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' 'inline-speculation-rules'",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' data: https://fonts.gstatic.com",
  "img-src 'self' data:",
  connectSrc,
  "frame-ancestors 'none'",
]

const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
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
