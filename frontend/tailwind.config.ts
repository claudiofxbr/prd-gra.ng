import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: 'class',
  content: [
    './app/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50:  '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        },
        // Tokens semânticos — valores injetados por CSS custom properties por tema
        surface: {
          base:    'var(--surface-base)',
          raised:  'var(--surface-raised)',
          overlay: 'var(--surface-overlay)',
          border:  'var(--surface-border)',
        },
        content: {
          primary:   'var(--content-primary)',
          secondary: 'var(--content-secondary)',
          muted:     'var(--content-muted)',
          inverse:   'var(--content-inverse)',
        },
        accent: {
          DEFAULT: 'var(--accent)',
          hover:   'var(--accent-hover)',
          muted:   'var(--accent-muted)',
          text:    'var(--accent-text)',
        },
      },
    },
  },
  plugins: [],
}

export default config
