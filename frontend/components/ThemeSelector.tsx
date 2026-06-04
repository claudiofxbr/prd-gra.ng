'use client'

import { useEffect, useState } from 'react'
import { ALL_THEMES, THEME_LABELS, applyTheme, getSavedTheme, type Theme } from '@/lib/theme'

const THEME_ICONS: Record<Theme, string> = {
  dark:  '🌑',
  blue:  '🌊',
  green: '🌿',
}

export default function ThemeSelector() {
  const [current, setCurrent] = useState<Theme>('dark')
  const [open, setOpen] = useState(false)

  useEffect(() => {
    const saved = getSavedTheme()
    setCurrent(saved)
    applyTheme(saved)
  }, [])

  function select(theme: Theme) {
    setCurrent(theme)
    applyTheme(theme)
    setOpen(false)
  }

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((v) => !v)}
        onBlur={() => setTimeout(() => setOpen(false), 150)}
        className="btn-ghost text-xs px-2.5 py-1.5 gap-1.5"
        aria-label="Selecionar tema"
        title={`Tema: ${THEME_LABELS[current]}`}
      >
        <span>{THEME_ICONS[current]}</span>
        <span className="hidden sm:inline" style={{ color: 'var(--content-secondary)' }}>
          {THEME_LABELS[current]}
        </span>
        <svg
          className="w-3 h-3 transition-transform"
          style={{ transform: open ? 'rotate(180deg)' : 'rotate(0deg)', color: 'var(--content-muted)' }}
          fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}
        >
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      {open && (
        <div
          className="absolute right-0 mt-1 w-44 rounded-xl overflow-hidden shadow-xl z-50"
          style={{
            backgroundColor: 'var(--surface-overlay)',
            border: '1px solid var(--surface-border)',
          }}
        >
          {ALL_THEMES.map((theme) => (
            <button
              key={theme}
              onClick={() => select(theme)}
              className="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-left transition-all duration-100"
              style={{
                backgroundColor: current === theme ? 'var(--accent-muted)' : 'transparent',
                color: current === theme ? 'var(--accent-text)' : 'var(--content-secondary)',
              }}
              onMouseEnter={(e) => {
                if (current !== theme)
                  (e.currentTarget as HTMLButtonElement).style.backgroundColor = 'var(--surface-raised)'
              }}
              onMouseLeave={(e) => {
                if (current !== theme)
                  (e.currentTarget as HTMLButtonElement).style.backgroundColor = 'transparent'
              }}
            >
              <span className="text-base">{THEME_ICONS[theme]}</span>
              <span className="font-medium">{THEME_LABELS[theme]}</span>
              {current === theme && (
                <svg className="w-3.5 h-3.5 ml-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
