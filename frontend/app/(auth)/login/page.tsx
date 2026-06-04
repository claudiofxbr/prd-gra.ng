'use client'

import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { api } from '@/lib/api'
import { saveAuth } from '@/lib/auth'

const schema = z.object({
  email:    z.string().email('Email inválido'),
  password: z.string().min(1, 'Senha obrigatória'),
})

type FormValues = z.infer<typeof schema>

export default function LoginPage() {
  const router = useRouter()
  const [error, setError] = useState('')
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<FormValues>({
    resolver: zodResolver(schema),
  })

  async function onSubmit(values: FormValues) {
    setError('')
    try {
      const res = await api.auth.login(values)
      saveAuth(res)
      router.push('/dashboard')
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erro ao entrar')
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center px-4">
      <div className="card w-full max-w-md">
        <div className="text-center mb-8">
          <div className="text-4xl mb-3">📄</div>
          <h1 className="text-2xl font-bold" style={{ color: 'var(--content-primary)' }}>
            Entrar no PRD-GRA
          </h1>
          <p className="text-sm mt-1" style={{ color: 'var(--content-muted)' }}>
            Acesse seus documentos de requisitos
          </p>
        </div>

        {error && <div className="alert-error mb-4">{error}</div>}

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1" style={{ color: 'var(--content-secondary)' }}>
              Email
            </label>
            <input {...register('email')} type="email" className="input-field" placeholder="seu@email.com" />
            {errors.email && <p className="text-xs mt-1" style={{ color: '#f87171' }}>{errors.email.message}</p>}
          </div>
          <div>
            <label className="block text-sm font-medium mb-1" style={{ color: 'var(--content-secondary)' }}>
              Senha
            </label>
            <input {...register('password')} type="password" className="input-field" placeholder="••••••••" />
            {errors.password && <p className="text-xs mt-1" style={{ color: '#f87171' }}>{errors.password.message}</p>}
          </div>
          <button type="submit" disabled={isSubmitting} className="btn-primary w-full py-2.5">
            {isSubmitting ? 'Entrando...' : 'Entrar'}
          </button>
        </form>

        <p className="text-center text-sm mt-6" style={{ color: 'var(--content-muted)' }}>
          Não tem conta?{' '}
          <Link href="/register" className="link-accent font-medium">Criar conta</Link>
        </p>
      </div>
    </div>
  )
}
