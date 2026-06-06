'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { api } from '@/lib/api'
import { isAuthenticated } from '@/lib/auth'
import PrdCard from '@/components/PrdCard'
import Navbar from '@/components/Navbar'
import type { PrdResponse } from '@/types'

const PAGE_SIZE = 20

export default function PrdListPage() {
  const router = useRouter()
  const [prds, setPrds]               = useState<PrdResponse[]>([])
  const [loading, setLoading]         = useState(true)
  const [error, setError]             = useState('')
  const [deleteError, setDeleteError] = useState('')
  const [deletingId, setDeletingId]   = useState<string | null>(null)
  const [page, setPage]               = useState(0)
  const [totalPages, setTotalPages]   = useState(1)
  const [total, setTotal]             = useState(0)

  useEffect(() => {
    if (!isAuthenticated()) { router.replace('/login'); return }
    let cancelled = false
    setLoading(true)
    setError('')
    ;(async () => {
      try {
        const res = await api.prds.list(page, PAGE_SIZE)
        if (!cancelled) {
          setPrds(res?.content ?? [])
          setTotalPages(res?.totalPages ?? 1)
          setTotal(res?.totalElements ?? 0)
        }
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : 'Erro ao carregar PRDs')
      } finally {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [router, page])

  async function handleDelete(id: string) {
    setDeleteError('')
    setDeletingId(id)
    try {
      await api.prds.delete(id)
      const newPrds = prds.filter((p) => p.id !== id)
      setPrds(newPrds)
      setTotal((t) => t - 1)
      // Se a página ficou vazia e não é a primeira, volta uma página
      if (newPrds.length === 0 && page > 0) {
        setPage((p) => p - 1)
      }
    } catch (e) {
      setDeleteError(e instanceof Error ? e.message : 'Erro ao excluir')
    } finally {
      setDeletingId(null)
    }
  }

  return (
    <>
      <Navbar />
      <main className="max-w-5xl mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold" style={{ color: 'var(--content-primary)' }}>
              Meus PRDs
            </h1>
            {!loading && (
              <p className="text-sm mt-0.5" style={{ color: 'var(--content-muted)' }}>
                {total} documento{total !== 1 ? 's' : ''}
              </p>
            )}
          </div>
          <Link href="/prd/new" className="btn-primary">+ Novo PRD</Link>
        </div>

        {loading && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {[...Array(3)].map((_, i) => <div key={i} className="skeleton h-40 rounded-xl" />)}
          </div>
        )}

        {error    && <div className="alert-error">{error}</div>}
        {deleteError && <div className="alert-error mb-4">{deleteError}</div>}

        {!loading && !error && prds.length === 0 && (
          <div className="card text-center py-16 space-y-4">
            <div className="text-5xl">📋</div>
            <p className="text-lg" style={{ color: 'var(--content-muted)' }}>
              Você ainda não criou nenhum PRD.
            </p>
            <Link href="/prd/new" className="btn-primary inline-flex">
              Criar meu primeiro PRD
            </Link>
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {prds.map((prd) => (
            <PrdCard key={prd.id} prd={prd} onDelete={handleDelete} deleting={deletingId === prd.id} />
          ))}
        </div>

        {totalPages > 1 && (
          <div className="flex items-center justify-center gap-4 mt-8">
            <button
              onClick={() => setPage((p) => Math.max(0, p - 1))}
              disabled={page === 0 || loading}
              className="btn-ghost px-4 py-2 disabled:opacity-40 disabled:cursor-not-allowed"
            >
              ← Anterior
            </button>
            <span className="text-sm" style={{ color: 'var(--content-muted)' }}>
              Página {page + 1} de {totalPages}
            </span>
            <button
              onClick={() => setPage((p) => Math.min(totalPages - 1, p + 1))}
              disabled={page >= totalPages - 1 || loading}
              className="btn-ghost px-4 py-2 disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Próxima →
            </button>
          </div>
        )}
      </main>
    </>
  )
}
