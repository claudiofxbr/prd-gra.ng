'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { api } from '@/lib/api'
import { isAuthenticated } from '@/lib/auth'
import PrdCard from '@/components/PrdCard'
import Navbar from '@/components/Navbar'
import type { PrdResponse } from '@/types'

export default function PrdListPage() {
  const router = useRouter()
  const [prds, setPrds]             = useState<PrdResponse[]>([])
  const [loading, setLoading]       = useState(true)
  const [error, setError]           = useState('')
  const [deleteError, setDeleteError] = useState('')
  const [deletingId, setDeletingId] = useState<string | null>(null)

  useEffect(() => {
    if (!isAuthenticated()) { router.replace('/login'); return }
    api.prds.list()
      .then((res) => setPrds(res?.content ?? []))
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false))
  }, [router])

  async function handleDelete(id: string) {
    setDeleteError('')
    setDeletingId(id)
    try {
      await api.prds.delete(id)
      setPrds((prev) => prev.filter((p) => p.id !== id))
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
                {prds.length} documento{prds.length !== 1 ? 's' : ''}
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
      </main>
    </>
  )
}
