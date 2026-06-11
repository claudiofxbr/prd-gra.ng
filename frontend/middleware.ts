import { NextRequest, NextResponse } from 'next/server'

const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? ''
const PROTECTED_PREFIXES = ['/prd', '/dashboard'].map((p) => BASE_PATH + p)
const AUTH_ROUTES = ['/login', '/register'].map((p) => BASE_PATH + p)
const TOKEN_COOKIE = 'prdgra_token'
const IS_PROD = process.env.NODE_ENV === 'production'

// Headers de segurança aplicados via middleware (funciona em dev e prod, App Router e Pages Router)
// O next.config.mjs headers() só é aplicado em prod — o middleware garante consistência em dev também.
const BASE_SECURITY_HEADERS: Record<string, string> = {
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'X-DNS-Prefetch-Control': 'on',
}

// 'unsafe-inline' obrigatório: Next.js 15 SSR injeta __NEXT_DATA__ e chunks
// de hydration inline — sem ele o React não inicializa e a página fica em branco.
// connect-src: API relativa (/api) já é coberta por 'self' — não adicionar origem.
const CSP_PROD =
  "default-src 'self'; " +
  "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' 'inline-speculation-rules'; " +
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; " +
  "font-src 'self' data: https://fonts.gstatic.com; " +
  "img-src 'self' data:; " +
  "connect-src 'self'; " +
  "frame-ancestors 'none'"

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

  // Aplicar headers de segurança em todas as respostas
  for (const [key, value] of Object.entries(BASE_SECURITY_HEADERS)) {
    response.headers.set(key, value)
  }
  if (IS_PROD) {
    response.headers.set('Content-Security-Policy', CSP_PROD)
  }

  return response
}

export const config = {
  matcher: [
    // '/' (home) precisa ser listada explicitamente — o padrão de negação não casa com path vazio
    '/',
    // Todas as rotas não-estáticas: /login, /register, /prd/..., /dashboard/..., etc.
    '/((?!_next/static|_next/image|favicon\\.ico).+)',
  ],
}
