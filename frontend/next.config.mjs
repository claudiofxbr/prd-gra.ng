/** @type {import('next').NextConfig} */
const isDev = process.env.NODE_ENV !== 'production'

// CSP aplicado em todos os ambientes (dev e prod).
// connect-src 'self' cobre tanto a API relativa (/api) quanto o proxy de dev abaixo.
// 'unsafe-inline' é obrigatório: Next.js 15 SSR injeta __NEXT_DATA__ e scripts de hydration inline.
const cspDirectives = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' 'inline-speculation-rules'",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' data: https://fonts.gstatic.com",
  "img-src 'self' data:",
  "connect-src 'self'",
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

// Em dev, o backend roda em localhost:8080. Para que as chamadas à API sejam
// same-origin (e não violem o CSP connect-src 'self'), o Next.js redireciona
// /api/* → http://localhost:8080/api/* internamente no servidor.
// Em produção o nginx já faz esse proxy — rewrites não são necessários.
const DEV_API_BACKEND = process.env.DEV_API_URL ?? 'http://localhost:8080'

const nextConfig = {
  output: isDev ? undefined : 'standalone',
  basePath: BASE_PATH,
  skipTrailingSlashRedirect: true,
  env: {
    NEXT_PUBLIC_BASE_PATH: BASE_PATH,
  },
  // typedRoutes promovido para estável no Next.js 15 — saiu do bloco experimental
  ...(isDev ? {} : { typedRoutes: true }),
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: securityHeaders,
      },
    ]
  },
  // Proxy de desenvolvimento: /api/* → backend em localhost:8080/api/*
  // Isso torna a API same-origin em dev, sem precisar de CORS ou CSP cross-origin.
  // basePath: false é obrigatório — sem ele o Next.js exigiria /prd-gra.ng/api/:path*
  // no source, mas o browser envia fetch('/api/...') que resolve para origem raiz.
  async rewrites() {
    if (!isDev) return []
    return [
      {
        source: '/api/:path*',
        basePath: false,
        destination: `${DEV_API_BACKEND}/api/:path*`,
      },
    ]
  },
}

export default nextConfig
