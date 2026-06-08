-- Índice parcial para lookup por ID com filtro de soft-delete.
-- Usado em: findByIdAndUserEmail (GET /prds/{id}, PUT /prds/{id}, DELETE /prds/{id}).
-- WHERE deleted_at IS NULL elimina registros deletados do índice, reduzindo seu tamanho.
CREATE INDEX idx_prds_id_not_deleted ON prds(id) WHERE deleted_at IS NULL;

-- Índice parcial para listagem por usuário (query mais frequente da app).
-- Complementa idx_prds_user_updated cobrindo o filtro deleted_at IS NULL explicitamente.
-- O planejador pode escolher este índice quando deleted_at é seletivo (poucos deletados).
CREATE INDEX idx_prds_user_not_deleted ON prds(user_id, updated_at DESC) WHERE deleted_at IS NULL;
