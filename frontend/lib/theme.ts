export type Theme = 'dark' | 'blue' | 'green'

const COOKIE_THEME = 'prdgra_theme'
const DEFAULT_THEME: Theme = 'dark'

const THEME_CLASSES: Record<Theme, string> = {
  dark:  'theme-dark',
  blue:  'theme-blue',
  green: 'theme-green',
}

export const THEME_LABELS: Record<Theme, string> = {
  dark:  'Escuro',
  blue:  'Azul Escuro',
  green: 'Verde Escuro',
}

export const ALL_THEMES: Theme[] = ['dark', 'blue', 'green']

function setCookie(name: string, value: string): void {
  if (typeof document === 'undefined') return
  document.cookie = `${name}=${value}; Max-Age=${60 * 60 * 24 * 365}; Path=/; SameSite=Strict`
}

function getCookie(name: string): string | null {
  if (typeof document === 'undefined') return null
  const match = document.cookie.split('; ').find((r) => r.startsWith(`${name}=`))
  return match ? match.split('=').slice(1).join('=') : null
}

export function getSavedTheme(): Theme {
  const saved = getCookie(COOKIE_THEME)
  if (saved && saved in THEME_CLASSES) return saved as Theme
  return DEFAULT_THEME
}

export function applyTheme(theme: Theme): void {
  if (typeof document === 'undefined') return
  const html = document.documentElement
  Object.values(THEME_CLASSES).forEach((cls) => html.classList.remove(cls))
  html.classList.add(THEME_CLASSES[theme])
  setCookie(COOKIE_THEME, theme)
}

export function getThemeClass(theme: Theme): string {
  return THEME_CLASSES[theme]
}
