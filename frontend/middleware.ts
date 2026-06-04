import { NextRequest, NextResponse } from 'next/server'

const PROTECTED_PREFIXES = ['/prd', '/dashboard']
const AUTH_ROUTES = ['/login', '/register']
const TOKEN_COOKIE = 'prdgra_token'

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  const token = request.cookies.get(TOKEN_COOKIE)?.value

  const isProtected = PROTECTED_PREFIXES.some((p) => pathname.startsWith(p))
  const isAuthRoute = AUTH_ROUTES.some((p) => pathname.startsWith(p))

  if (isProtected && !token) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('from', pathname)
    return NextResponse.redirect(loginUrl)
  }

  if (isAuthRoute && token) {
    return NextResponse.redirect(new URL('/prd', request.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/prd/:path*', '/dashboard/:path*', '/login', '/register'],
}
