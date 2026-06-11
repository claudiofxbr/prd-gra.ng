import { NextRequest, NextResponse } from 'next/server'

const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? ''
const PROTECTED_PREFIXES = ['/prd', '/dashboard'].map((p) => BASE_PATH + p)
const AUTH_ROUTES = ['/login', '/register'].map((p) => BASE_PATH + p)
const TOKEN_COOKIE = 'prdgra_token'
const IS_PROD = process.env.NODE_ENV === 'production'

// Headers de segurança aplicados via middleware (funciona em dev e prod, App Router e Pages Router)
const BASE_SECURITY_HEADERS: Record<string, string> = {
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'X-DNS-Prefetch-Control': 'on',
}

// HSTS instrui browsers a usar HTTPS por 1 ano após a primeira visita.
// Aplicado apenas em prod — em dev http://localhost o header é ignorado pelo browser.
const HSTS_PROD = 'max-age=31536000; includeSubDomains'

// Em dev, o HMR/React Fast Refresh usa eval() — 'unsafe-eval' obrigatório.
// Em prod o bundle é pré-compilado e não usa eval — removido por segurança.
// 'unsafe-inline' obrigatório: Next.js 15 SSR injeta __NEXT_DATA__ e chunks de hydration inline.
// connect-src 'self' cobre tanto a API relativa (/api) quanto o proxy de dev do next.config.mjs.
const scriptSrc = IS_PROD
  ? "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' 'inline-speculation-rules'"
  : "script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' 'inline-speculation-rules'"

const CSP = [
  "default-src 'self'",
  scriptSrc,
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' data: https://fonts.gstatic.com",
  "img-src 'self' data:",
  "connect-src 'self'",
  "frame-ancestors 'none'",
].join('; ')

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  const token = request.cookies.get(TOKEN_COOKIE)?.value

  const isProtected = PROTECTED_PREFIXES.some((p) => pathname.startsWith(p))
  const isAuthRoute = AUTH_ROUTES.some((p) => pathname.startsWith(p))

  let response: NextResponse

  if (isProtected && !token) {
    const loginUrl = request.nextUrl.clone()
    loginUrl.pathname = BASE_PATH + '/login'
    loginUrl.searchParams.set('from', pathname)
    response = NextResponse.redirect(loginUrl)
  } else if (isAuthRoute && token) {
    const prdUrl = request.nextUrl.clone()
    prdUrl.pathname = BASE_PATH + '/prd'
    prdUrl.search = ''
    response = NextResponse.redirect(prdUrl)
  } else {
    response = NextResponse.next()
  }

  // Aplicar headers de segurança em todas as respostas (dev e prod)
  for (const [key, value] of Object.entries(BASE_SECURITY_HEADERS)) {
    response.headers.set(key, value)
  }
  response.headers.set('Content-Security-Policy', CSP)
  if (IS_PROD) {
    response.headers.set('Strict-Transport-Security', HSTS_PROD)
  }

  return response
}

export const config = {
  matcher: [
    // '/' (home) precisa ser listada explicitamente — o padrão de negação não casa com path vazio
    '/',
    // Todas as rotas não-estáticas — exclui assets estáticos e favicons
    '/((?!_next/static|_next/image|favicon\\.ico|favicon\\.svg).+)',
  ],
}
