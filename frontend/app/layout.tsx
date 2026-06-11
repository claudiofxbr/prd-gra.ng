import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import ThemeBootstrap from '@/components/ThemeBootstrap'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'PRD-GRA | Gerador de Requisitos',
  description: 'Crie e gerencie seus documentos de requisitos de software com facilidade.',
  icons: {
    icon: '/favicon.svg',
    shortcut: '/favicon.svg',
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR" className="theme-dark">
      <body className={inter.className}>
        {/* Restaura o tema salvo no cookie antes do primeiro render visível */}
        <ThemeBootstrap />
        {children}
      </body>
    </html>
  )
}
