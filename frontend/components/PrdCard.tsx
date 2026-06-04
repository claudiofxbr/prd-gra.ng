'use client'

import { useState } from 'react'
import Link from 'next/link'
import type { PrdResponse, PrdStatus } from '@/types'

const statusClass: Record<PrdStatus, string> = {
  DRAFT:    'badge-draft',
  REVIEW:   'badge-review',
  APPROVED: 'badge-approved',
}

const statusLabel: Record<PrdStatus, string> = {
  DRAFT: 'Rascunho', REVIEW: 'Em Revisão', APPROVED: 'Aprovado',
}

interface Props {
  prd: PrdResponse
  onDelete: (id: string) => void
  deleting?: boolean
}

export default function PrdCard({ prd, onDelete, deleting = false }: Props) {
  const [confirming, setConfirming] = useState(false)

  function handleDeleteClick() {
    if (!confirming) { setConfirming(true); return }
    setConfirming(false)
    onDelete(prd.id)
  }

  return (
    <div className="card-hover">
      {/* Título + badge */}
      <div className="flex items-start justify-between mb-3 gap-2">
        <Link
          href={`/prd/${prd.id}`}
          className="font-semibold text-base line-clamp-1 transition-colors"
          style={{ color: 'var(--content-primary)' }}
          onMouseEnter={(e) => { (e.currentTarget as HTMLAnchorElement).style.color = 'var(--accent-text)' }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLAnchorElement).style.color = 'var(--content-primary)' }}
        >
          {prd.title}
        </Link>
        <span className={`${statusClass[prd.status]} shrink-0`}>
          {statusLabel[prd.status]}
        </span>
      </div>

      {/* Descrição */}
      {prd.description && (
        <p className="text-sm line-clamp-2 mb-3" style={{ color: 'var(--content-muted)' }}>
          {prd.description}
        </p>
      )}

      {/* Stack */}
      {prd.stack.length > 0 && (
        <div className="flex flex-wrap gap-1 mb-3">
          {prd.stack.slice(0, 4).map((s) => (
            <span key={s} className="text-xs px-2 py-0.5 rounded"
              style={{ backgroundColor: 'var(--surface-overlay)', color: 'var(--content-secondary)' }}>
              {s}
            </span>
          ))}
          {prd.stack.length > 4 && (
            <span className="text-xs px-2 py-0.5 rounded"
              style={{ backgroundColor: 'var(--surface-overlay)', color: 'var(--content-muted)' }}>
              +{prd.stack.length - 4}
            </span>
          )}
        </div>
      )}

      {/* Footer */}
      <div className="flex items-center justify-between mt-4 pt-3"
        style={{ borderTop: '1px solid var(--surface-border)' }}>
        <span className="text-xs" style={{ color: 'var(--content-muted)' }}>
          {new Date(prd.updatedAt).toLocaleDateString('pt-BR')}
        </span>
        <div className="flex gap-3 items-center">
          <Link href={`/prd/${prd.id}`} className="text-sm link-accent">Editar</Link>
          <button
            onClick={handleDeleteClick}
            onBlur={() => setConfirming(false)}
            disabled={deleting}
            className="text-sm transition-colors disabled:opacity-40"
            style={{ color: confirming ? '#fca5a5' : '#f87171', fontWeight: confirming ? 600 : 400 }}
          >
            {deleting ? 'Excluindo...' : confirming ? 'Confirmar?' : 'Excluir'}
          </button>
        </div>
      </div>
    </div>
  )
}
