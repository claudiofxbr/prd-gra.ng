-- Garante integridade do campo status no banco, não apenas no ORM
ALTER TABLE prds ADD CONSTRAINT chk_prd_status
  CHECK (status IN ('DRAFT', 'REVIEW', 'APPROVED'));
