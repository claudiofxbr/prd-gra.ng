'use client'

import { useEffect } from 'react'
import { getSavedTheme, applyTheme } from '@/lib/theme'

// Componente sem UI — apenas restaura o tema salvo no cookie ao montar no cliente.
// Roda antes do primeiro paint visível para evitar flash de tema incorreto.
export default function ThemeBootstrap() {
  useEffect(() => {
    applyTheme(getSavedTheme())
  }, [])

  return null
}
