'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Navbar from '@/components/Navbar'
import PrdForm from '@/components/PrdForm'
import { api } from '@/lib/api'
import { isAuthenticated } from '@/lib/auth'
import type { PrdRequest } from '@/types'

export default function NewPrdPage() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [error, setError]     = useState('')

  useEffect(() => {
    if (!isAuthenticated()) router.replace('/login')
  }, [router])

  async function handleSubmit(data: PrdRequest) {
    setError('')
    setLoading(true)
    try {
      const prd = await api.prds.create(data)
      if (prd?.id) router.push(`/prd/${prd.id}`)
      else router.push('/prd')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao criar PRD')
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
            Novo PRD
          </h1>
          <p className="text-sm mt-1" style={{ color: 'var(--content-muted)' }}>
            Preencha os dados do seu documento de requisitos.
          </p>
        </div>
        {error && <div className="alert-error mb-4">{error}</div>}
        <div className="card">
          <PrdForm onSubmit={handleSubmit} loading={loading} />
        </div>
      </main>
    </>
  )
}
