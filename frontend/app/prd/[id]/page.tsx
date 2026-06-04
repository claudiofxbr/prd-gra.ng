'use client'

import { useEffect, useState } from 'react'
import { useRouter, useParams } from 'next/navigation'
import Navbar from '@/components/Navbar'
import PrdForm from '@/components/PrdForm'
import { api } from '@/lib/api'
import { isAuthenticated } from '@/lib/auth'
import type { PrdRequest, PrdResponse } from '@/types'

export default function EditPrdPage() {
  const router = useRouter()
  const { id } = useParams<{ id: string }>()
  const [prd, setPrd]           = useState<PrdResponse | null>(null)
  const [loading, setLoading]   = useState(false)
  const [fetching, setFetching] = useState(true)
  const [fetchError, setFetchError]   = useState('')
  const [submitError, setSubmitError] = useState('')

  useEffect(() => {
    if (!isAuthenticated()) { router.replace('/login'); return }
    if (!id) return
    api.prds.get(id)
      .then(setPrd)
      .catch((e: Error) => setFetchError(e.message))
      .finally(() => setFetching(false))
  }, [id, router])

  async function handleSubmit(data: PrdRequest) {
    if (!id) return
    setSubmitError('')
    setLoading(true)
    try {
      const updated = await api.prds.update(id, data)
      setPrd(updated)
      router.push('/prd')
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : 'Erro ao salvar PRD')
    } finally {
      setLoading(false)
    }
  }

  return (
    <>
      <Navbar />
      <main className="max-w-2xl mx-auto px-4 py-8">
        <div className="mb-6">
          <h1 className="text-2xl font-bold" style={{ color: 'var(--content-primary)' }}>
            Editar PRD
          </h1>
          <p className="text-sm mt-1" style={{ color: 'var(--content-muted)' }}>
            Atualize os dados do documento de requisitos.
          </p>
        </div>

        {fetching && (
          <div className="space-y-4">
            <div className="skeleton h-10 rounded-lg" />
            <div className="skeleton h-24 rounded-lg" />
            <div className="skeleton h-10 rounded-lg" />
          </div>
        )}

        {fetchError  && <div className="alert-error">{fetchError}</div>}
        {submitError && <div className="alert-error mb-4">{submitError}</div>}

        {prd && (
          <div className="card">
            <PrdForm initial={prd} onSubmit={handleSubmit} loading={loading} />
          </div>
        )}
      </main>
    </>
  )
}
