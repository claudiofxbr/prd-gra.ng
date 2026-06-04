-- Índice composto para a query mais frequente: listar PRDs por usuário ordenado por data
-- Substitui o índice simples idx_prds_user_id (que permanece via este índice composto)
DROP INDEX IF EXISTS idx_prds_user_id;
CREATE INDEX idx_prds_user_updated ON prds(user_id, updated_at DESC);

-- Índice de status mantido separado (usado em queries futuras de admin/filtro)
-- idx_prds_status já existe do V1, não recriar

-- Trigger para garantir updated_at via banco (proteção contra updates diretos sem ORM)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW() AT TIME ZONE 'UTC';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prds_updated_at
  BEFORE UPDATE ON prds
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();
