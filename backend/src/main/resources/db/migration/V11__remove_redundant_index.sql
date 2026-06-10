-- idx_prds_user_not_deleted (V10) é idêntico a idx_prds_active_user_updated (V6):
-- ambos cobrem (user_id, updated_at DESC) WHERE deleted_at IS NULL.
-- Manter dois índices iguais consome espaço extra e degrada INSERT/UPDATE sem benefício.
DROP INDEX IF EXISTS idx_prds_user_not_deleted;
