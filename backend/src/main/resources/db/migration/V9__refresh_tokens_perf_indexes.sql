-- Índices para otimizar purge periódico de tokens expirados/revogados.
-- A query em RefreshTokenRepository.deleteExpiredAndRevoked faz full scan sem estes índices.
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
CREATE INDEX idx_refresh_tokens_revoked_at ON refresh_tokens(revoked_at) WHERE revoked_at IS NOT NULL;
