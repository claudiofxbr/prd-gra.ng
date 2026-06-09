export type PrdStatus = 'DRAFT' | 'REVIEW' | 'APPROVED'

export interface PageResponse<T> {
  content: T[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export interface PrdResponse {
  id: string
  title: string
  description: string | null
  stack: string[]
  objectives: string[]
  status: PrdStatus
  createdAt: string
  updatedAt: string
}

export interface PrdRequest {
  title: string
  description?: string
  stack: string[]
  objectives: string[]
  status?: PrdStatus
}

// Resposta dos endpoints /auth/login e /auth/register.
// O token JWT não é retornado no body — vai no Set-Cookie HttpOnly do backend.
export interface UserResponse {
  name: string
  email: string
  role: string
}

export interface AuthUser {
  name: string
  email: string
  role: string
}

export interface PrdSummaryStackEntry {
  name: string
  count: number
}

export interface PrdSummaryRecentEntry {
  id: string
  title: string
  status: PrdStatus
  updatedAt: string
}

export interface PrdSummaryResponse {
  total: number
  byStatus: Record<PrdStatus, number>
  topStack: PrdSummaryStackEntry[]
  recent: PrdSummaryRecentEntry[]
}
