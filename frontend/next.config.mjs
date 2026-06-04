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

// Em dev: unsafe-eval necessario para webpack HMR / React Fast Refresh
// Em prod: removido — webpack usa modulos estaticos sem eval
const scriptSrc = isDev
  ? "script-src 'self' 'unsafe-inline' 'unsafe-eval'"
  : "script-src 'self' 'unsafe-inline'"

// connect-src: origem da API + websocket HMR em dev
const connectSrc = isDev
  ? `connect-src 'self' ${apiOrigin} ws://localhost:3000 wss://localhost:3000`
  : `connect-src 'self' ${apiOrigin}`

const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
  {
    key: 'Content-Security-Policy',
    value: [
      "default-src 'self'",
      scriptSrc,
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' data: https://fonts.gstatic.com",
      "img-src 'self' data:",
      connectSrc,
      "frame-ancestors 'none'",
    ].join('; '),
  },
]

const nextConfig = {
  output: isDev ? undefined : 'standalone',
  experimental: {
    typedRoutes: !isDev,
  },
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
