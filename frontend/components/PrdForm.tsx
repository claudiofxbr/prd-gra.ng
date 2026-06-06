'use client'

import { useFieldArray, useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import type { PrdRequest, PrdResponse, PrdStatus } from '@/types'

const schema = z.object({
  title:       z.string().trim().min(1, 'Título obrigatório').max(255),
  description: z.string().trim().optional(),
  stack:       z.array(z.object({ value: z.string().trim().min(1, 'Tecnologia não pode ser vazia') })).min(1, 'Adicione ao menos uma tecnologia'),
  objectives:  z.array(z.object({ value: z.string().trim().min(1, 'Objetivo não pode ser vazio') })).min(1, 'Adicione ao menos um objetivo'),
  status:      z.enum(['DRAFT', 'REVIEW', 'APPROVED']).optional(),
})

type FormValues = z.infer<typeof schema>

interface Props {
  initial?: PrdResponse
  onSubmit: (data: PrdRequest) => Promise<void>
  loading?: boolean
}

export default function PrdForm({ initial, onSubmit, loading }: Props) {
  const { register, control, handleSubmit, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      title:       initial?.title ?? '',
      description: initial?.description ?? '',
      stack:       (initial?.stack ?? ['']).map((v) => ({ value: v })),
      objectives:  (initial?.objectives ?? ['']).map((v) => ({ value: v })),
      status:      (initial?.status as PrdStatus | undefined) ?? 'DRAFT',
    },
  })

  const stackFields = useFieldArray({ control, name: 'stack' })
  const objFields   = useFieldArray({ control, name: 'objectives' })

  async function handleFormSubmit(values: FormValues) {
    await onSubmit({
      title:       values.title,
      description: values.description,
      stack:       values.stack.map((s) => s.value),
      objectives:  values.objectives.map((o) => o.value),
      status:      values.status,
    })
  }

  const errMsg = (msg?: string) =>
    msg ? <p className="text-xs mt-1" style={{ color: '#f87171' }}>{msg}</p> : null

  return (
    <form onSubmit={handleSubmit(handleFormSubmit)} className="space-y-6">

      <div>
        <label className="block text-sm font-medium mb-1" style={{ color: 'var(--content-secondary)' }}>
          Título *
        </label>
        <input {...register('title')} className="input-field"
          placeholder="Ex: Sistema de Gestão de Usuários" />
        {errMsg(errors.title?.message)}
      </div>

      <div>
        <label className="block text-sm font-medium mb-1" style={{ color: 'var(--content-secondary)' }}>
          Descrição
        </label>
        <textarea {...register('description')} rows={3} className="input-field resize-none"
          placeholder="Descreva o objetivo e escopo do projeto..." />
      </div>

      <div>
        <label className="block text-sm font-medium mb-2" style={{ color: 'var(--content-secondary)' }}>
          Stack Tecnológica *
        </label>
        {stackFields.fields.map((field, i) => (
          <div key={field.id} className="flex gap-2 mb-2">
            <input {...register(`stack.${i}.value`)} className="input-field"
              placeholder="Ex: Next.js, Java, PostgreSQL" />
            <button type="button" onClick={() => stackFields.remove(i)}
              disabled={stackFields.fields.length === 1}
              className="text-xl leading-none transition-colors px-2 disabled:opacity-30 disabled:cursor-not-allowed"
              style={{ color: '#f87171' }}
              onMouseEnter={(e) => { if (!e.currentTarget.disabled) (e.currentTarget as HTMLButtonElement).style.color = '#fca5a5' }}
              onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = '#f87171' }}
            >×</button>
          </div>
        ))}
        <button type="button" onClick={() => stackFields.append({ value: '' })}
          className="text-sm link-accent">
          + Adicionar tecnologia
        </button>
        {errMsg(errors.stack?.message as string | undefined)}
      </div>

      <div>
        <label className="block text-sm font-medium mb-2" style={{ color: 'var(--content-secondary)' }}>
          Objetivos *
        </label>
        {objFields.fields.map((field, i) => (
          <div key={field.id} className="flex gap-2 mb-2">
            <input {...register(`objectives.${i}.value`)} className="input-field"
              placeholder="Ex: Reduzir tempo de onboarding em 50%" />
            <button type="button" onClick={() => objFields.remove(i)}
              disabled={objFields.fields.length === 1}
              className="text-xl leading-none transition-colors px-2 disabled:opacity-30 disabled:cursor-not-allowed"
              style={{ color: '#f87171' }}
              onMouseEnter={(e) => { if (!e.currentTarget.disabled) (e.currentTarget as HTMLButtonElement).style.color = '#fca5a5' }}
              onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.color = '#f87171' }}
            >×</button>
          </div>
        ))}
        <button type="button" onClick={() => objFields.append({ value: '' })}
          className="text-sm link-accent">
          + Adicionar objetivo
        </button>
        {errMsg(errors.objectives?.message as string | undefined)}
      </div>

      {initial && (
        <div>
          <label className="block text-sm font-medium mb-1" style={{ color: 'var(--content-secondary)' }}>
            Status
          </label>
          <select {...register('status')} className="input-field">
            <option value="DRAFT">Rascunho</option>
            <option value="REVIEW">Em Revisão</option>
            <option value="APPROVED">Aprovado</option>
          </select>
        </div>
      )}

      <button type="submit" disabled={loading} className="btn-primary w-full py-3">
        {loading ? 'Salvando...' : initial ? 'Salvar Alterações' : 'Criar PRD'}
      </button>
    </form>
  )
}
