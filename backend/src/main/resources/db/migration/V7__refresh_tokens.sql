CREATE TABLE refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash  VARCHAR(64) NOT NULL UNIQUE,   -- SHA-256 hex do token gerado
    expires_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at  TIMESTAMP WITH TIME ZONE,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user    ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_hash    ON refresh_tokens(token_hash);
-- Indice parcial para tokens nao revogados (IMMUTABLE-safe: revoked_at IS NULL e condicao estatica)
-- NOW() nao pode ser usado em predicado de indice pois e VOLATILE. A filtragem por expires_at
-- e feita na query, nao no predicado do indice.
CREATE INDEX idx_refresh_tokens_active  ON refresh_tokens(token_hash)
    WHERE revoked_at IS NULL;
