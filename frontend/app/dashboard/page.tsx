'use client'

import { useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import type { Route } from 'next'
import Navbar from '@/components/Navbar'
import { api } from '@/lib/api'
import { getAuth, isAuthenticated } from '@/lib/auth'
import type { PrdResponse, PrdStatus } from '@/types'

// ─── Tipos locais ────────────────────────────────────────────────────────────

interface StatusCount { DRAFT: number; REVIEW: number; APPROVED: number }
interface StackEntry  { name: string; count: number }

// ─── Helpers ─────────────────────────────────────────────────────────────────

function calcStatusCounts(prds: PrdResponse[]): StatusCount {
  return prds.reduce<StatusCount>(
    (acc, p) => { acc[p.status]++; return acc },
    { DRAFT: 0, REVIEW: 0, APPROVED: 0 },
  )
}

function calcTopStack(prds: PrdResponse[], limit = 6): StackEntry[] {
  const map: Record<string, number> = {}
  prds.forEach((p) => p.stack.forEach((s) => { map[s] = (map[s] ?? 0) + 1 }))
  return Object.entries(map)
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([name, count]) => ({ name, count }))
}

function calcRecentActivity(prds: PrdResponse[], limit = 5): PrdResponse[] {
  return [...prds]
    .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime())
    .slice(0, limit)
}

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1)  return 'agora mesmo'
  if (m < 60) return `há ${m} min`
  const h = Math.floor(m / 60)
  if (h < 24) return `há ${h}h`
  const d = Math.floor(h / 24)
  if (d < 30) return `há ${d}d`
  return new Date(iso).toLocaleDateString('pt-BR')
}

// ─── Sub-componentes ─────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: PrdStatus }) {
  const cls: Record<PrdStatus, string> = {
    DRAFT:    'badge-draft',
    REVIEW:   'badge-review',
    APPROVED: 'badge-approved',
  }
  const label: Record<PrdStatus, string> = {
    DRAFT: 'Rascunho', REVIEW: 'Em Revisão', APPROVED: 'Aprovado',
  }
  return <span className={cls[status]}>{label[status]}</span>
}

function StatCard({
  label, value, sub, accent = false, icon,
}: {
  label: string
  value: number | string
  sub?: string
  accent?: boolean
  icon: string
}) {
  return (
    <div className={accent ? 'stat-card-accent' : 'stat-card'}>
      <div className="flex items-center justify-between mb-3">
        <span className="text-2xl">{icon}</span>
        {sub && (
          <span className="text-xs rounded-full px-2 py-0.5"
            style={{ backgroundColor: 'var(--surface-overlay)', color: 'var(--content-muted)' }}>
            {sub}
          </span>
        )}
      </div>
      <p className="text-3xl font-bold" style={{ color: accent ? 'var(--accent-text)' : 'var(--content-primary)' }}>
        {value}
      </p>
      <p className="text-sm mt-1" style={{ color: 'var(--content-muted)' }}>{label}</p>
    </div>
  )
}

function StatusBar({ label, count, total, badgeClass }: {
  label: string; count: number; total: number; badgeClass: string
}) {
  const pct = total > 0 ? Math.round((count / total) * 100) : 0
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between text-sm">
        <span className={badgeClass}>{label}</span>
        <span style={{ color: 'var(--content-muted)' }}>{count} ({pct}%)</span>
      </div>
      <div className="progress-track">
        <div className="progress-fill" style={{ width: `${pct}%` }} />
      </div>
    </div>
  )
}

// ─── Página principal ─────────────────────────────────────────────────────────

export default function DashboardPage() {
  const router = useRouter()
  const [prds, setPrds]       = useState<PrdResponse[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError]     = useState('')
  const userName = getAuth()?.name ?? 'Usuário'

  useEffect(() => {
    if (!isAuthenticated()) { router.replace('/login'); return }
    let cancelled = false
    ;(async () => {
      try {
        const all = await api.prds.listAll()
        if (!cancelled) setPrds(all)
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : 'Erro ao carregar dados')
      } finally {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [router])

  const total    = prds.length
  const counts   = useMemo(() => calcStatusCounts(prds), [prds])
  const topStack = useMemo(() => calcTopStack(prds), [prds])
  const recent   = useMemo(() => calcRecentActivity(prds), [prds])
  const maxStack = topStack[0]?.count ?? 1

  return (
    <>
      <Navbar />

      <main className="max-w-6xl mx-auto px-4 py-8 space-y-8">

        {/* ── Cabeçalho ── */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold" style={{ color: 'var(--content-primary)' }}>
              Dashboard
            </h1>
            <p className="text-sm mt-0.5" style={{ color: 'var(--content-muted)' }}>
              Bem-vindo, {userName}. Aqui está uma visão geral dos seus PRDs.
            </p>
          </div>
          <Link href="/prd/new" className="btn-primary text-sm px-5 py-2.5 self-start sm:self-auto">
            + Novo PRD
          </Link>
        </div>

        {/* ── Erro ── */}
        {error && <div className="alert-error">{error}</div>}

        {/* ── Skeleton de loading ── */}
        {loading && (
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="skeleton h-28 rounded-xl" />
            ))}
          </div>
        )}

        {!loading && (
          <>
            {/* ── KPI Cards ── */}
            <section>
              <h2 className="text-xs font-semibold uppercase tracking-wider mb-4"
                style={{ color: 'var(--content-muted)' }}>
                Visão Geral
              </h2>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <StatCard icon="📄" label="Total de PRDs"   value={total}            accent={total > 0} />
                <StatCard icon="✏️" label="Rascunhos"       value={counts.DRAFT}     sub={total > 0 ? `${Math.round(counts.DRAFT/total*100)}%` : '0%'} />
                <StatCard icon="🔍" label="Em Revisão"      value={counts.REVIEW}    sub={total > 0 ? `${Math.round(counts.REVIEW/total*100)}%` : '0%'} />
                <StatCard icon="✅" label="Aprovados"        value={counts.APPROVED}  sub={total > 0 ? `${Math.round(counts.APPROVED/total*100)}%` : '0%'} />
              </div>
            </section>

            {total === 0 ? (
              /* ── Estado vazio ── */
              <div className="card text-center py-16 space-y-4">
                <div className="text-5xl">📋</div>
                <p className="text-lg font-semibold" style={{ color: 'var(--content-primary)' }}>
                  Nenhum PRD ainda
                </p>
                <p style={{ color: 'var(--content-muted)' }}>
                  Crie seu primeiro documento de requisitos para ver as métricas aqui.
                </p>
                <Link href="/prd/new" className="btn-primary inline-flex mt-2">
                  Criar Primeiro PRD
                </Link>
              </div>
            ) : (
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

                {/* ── Coluna esquerda: status + stack ── */}
                <div className="lg:col-span-2 space-y-6">

                  {/* Status breakdown */}
                  <div className="card space-y-5">
                    <h2 className="font-semibold text-sm" style={{ color: 'var(--content-primary)' }}>
                      Distribuição por Status
                    </h2>
                    <StatusBar label="Rascunho"   count={counts.DRAFT}    total={total} badgeClass="badge-draft" />
                    <StatusBar label="Em Revisão" count={counts.REVIEW}   total={total} badgeClass="badge-review" />
                    <StatusBar label="Aprovado"   count={counts.APPROVED} total={total} badgeClass="badge-approved" />
                  </div>

                  {/* Stack mais usada */}
                  {topStack.length > 0 && (
                    <div className="card">
                      <h2 className="font-semibold text-sm mb-5" style={{ color: 'var(--content-primary)' }}>
                        Stack Mais Usada
                      </h2>
                      <div className="space-y-3">
                        {topStack.map(({ name, count }) => (
                          <div key={name} className="space-y-1">
                            <div className="flex justify-between text-sm">
                              <span style={{ color: 'var(--content-secondary)' }}>{name}</span>
                              <span style={{ color: 'var(--content-muted)' }}>{count} PRD{count > 1 ? 's' : ''}</span>
                            </div>
                            <div className="progress-track">
                              <div className="progress-fill" style={{ width: `${Math.round((count / maxStack) * 100)}%` }} />
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                {/* ── Coluna direita: atividade recente ── */}
                <div className="card">
                  <div className="flex items-center justify-between mb-5">
                    <h2 className="font-semibold text-sm" style={{ color: 'var(--content-primary)' }}>
                      Atividade Recente
                    </h2>
                    <Link href="/prd" className="link-accent text-xs">Ver todos</Link>
                  </div>

                  <div className="space-y-1">
                    {recent.map((prd) => (
                      <Link
                        key={prd.id}
                        href={`/prd/${prd.id}`}
                        className="flex flex-col gap-1.5 px-3 py-3 rounded-lg transition-all duration-150"
                        style={{ color: 'inherit' }}
                        onMouseEnter={(e) => {
                          (e.currentTarget as HTMLAnchorElement).style.backgroundColor = 'var(--surface-overlay)'
                        }}
                        onMouseLeave={(e) => {
                          (e.currentTarget as HTMLAnchorElement).style.backgroundColor = 'transparent'
                        }}
                      >
                        <div className="flex items-center justify-between gap-2">
                          <span className="text-sm font-medium line-clamp-1" style={{ color: 'var(--content-primary)' }}>
                            {prd.title}
                          </span>
                          <StatusBadge status={prd.status} />
                        </div>
                        <div className="flex items-center justify-between">
                          <div className="flex flex-wrap gap-1">
                            {prd.stack.slice(0, 2).map((s) => (
                              <span key={s} className="text-xs px-1.5 py-0.5 rounded"
                                style={{ backgroundColor: 'var(--surface-overlay)', color: 'var(--content-muted)' }}>
                                {s}
                              </span>
                            ))}
                            {prd.stack.length > 2 && (
                              <span className="text-xs" style={{ color: 'var(--content-muted)' }}>
                                +{prd.stack.length - 2}
                              </span>
                            )}
                          </div>
                          <span className="text-xs shrink-0" style={{ color: 'var(--content-muted)' }}>
                            {relativeTime(prd.updatedAt)}
                          </span>
                        </div>
                      </Link>
                    ))}
                  </div>

                  {recent.length < total && (
                    <>
                      <div className="divider" />
                      <Link href="/prd" className="btn-ghost w-full text-sm justify-center">
                        Ver mais {total - recent.length} PRD{total - recent.length > 1 ? 's' : ''}
                      </Link>
                    </>
                  )}
                </div>

              </div>
            )}

            {/* ── Ações rápidas ── */}
            <section>
              <h2 className="text-xs font-semibold uppercase tracking-wider mb-4"
                style={{ color: 'var(--content-muted)' }}>
                Ações Rápidas
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                {(([
                  { href: '/prd/new', icon: '✏️', label: 'Novo PRD',      desc: 'Criar documento de requisitos' },
                  { href: '/prd',     icon: '📋', label: 'Meus PRDs',     desc: 'Gerenciar todos os PRDs' },
                  { href: '/prd',     icon: '🔍', label: 'Em Revisão',    desc: `${counts.REVIEW} aguardando revisão` },
                ] as { href: Route; icon: string; label: string; desc: string }[])).map(({ href, icon, label, desc }) => (
                  <Link
                    key={label}
                    href={href}
                    className="card-hover flex items-center gap-4 group"
                  >
                    <span className="text-2xl">{icon}</span>
                    <div>
                      <p className="font-semibold text-sm" style={{ color: 'var(--content-primary)' }}>{label}</p>
                      <p className="text-xs mt-0.5" style={{ color: 'var(--content-muted)' }}>{desc}</p>
                    </div>
                    <svg className="w-4 h-4 ml-auto opacity-0 group-hover:opacity-100 transition-opacity"
                      style={{ color: 'var(--accent-text)' }}
                      fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
                    </svg>
                  </Link>
                ))}
              </div>
            </section>

          </>
        )}
      </main>
    </>
  )
}
