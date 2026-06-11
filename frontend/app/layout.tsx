import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import ThemeBootstrap from '@/components/ThemeBootstrap'

const inter = Inter({ subsets: ['latin'] })

// metadata.icons com path absoluto '/' não recebe o basePath automaticamente pelo Next.js.
// O favicon é servido via <link> manual no <head> usando o basePath explícito.
export const metadata: Metadata = {
  title: 'PRD-GRA | Gerador de Requisitos',
  description: 'Crie e gerencie seus documentos de requisitos de software com facilidade.',
}

const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH ?? ''

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className="theme-dark">
      <head>
        <link rel="icon" type="image/svg+xml" href={`${BASE_PATH}/favicon.svg`} />
        <link rel="shortcut icon" href={`${BASE_PATH}/favicon.svg`} />
      </head>
      <body className={inter.className}>
        {/* Restaura o tema salvo no cookie antes do primeiro render visível */}
        <ThemeBootstrap />
        {children}
      </body>
    </html>
  )
}
