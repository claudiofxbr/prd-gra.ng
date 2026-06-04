-- Soft delete: PRDs excluídos ficam marcados em vez de deletados fisicamente
ALTER TABLE prds
    ADD COLUMN deleted_at  TIMESTAMP WITH TIME ZONE,
    ADD COLUMN deleted_by  UUID REFERENCES users(id) ON DELETE SET NULL;

-- Índice parcial cobre apenas registros ativos (deleted_at IS NULL) —
-- a query de listagem mais frequente se beneficia diretamente
DROP INDEX IF EXISTS idx_prds_user_updated;
CREATE INDEX idx_prds_active_user_updated
    ON prds(user_id, updated_at DESC)
    WHERE deleted_at IS NULL;

-- Índice de status também filtrado por ativos
DROP INDEX IF EXISTS idx_prds_status;
CREATE INDEX idx_prds_active_status
    ON prds(status)
    WHERE deleted_at IS NULL;

-- Audit: registra quem criou e quem fez a última modificação
ALTER TABLE prds
    ADD COLUMN created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    ADD COLUMN modified_by UUID REFERENCES users(id) ON DELETE SET NULL;

-- Preenche created_by com user_id nos registros existentes (retroativo)
UPDATE prds SET created_by = user_id WHERE created_by IS NULL;
