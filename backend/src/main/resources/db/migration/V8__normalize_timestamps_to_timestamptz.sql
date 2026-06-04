-- Normaliza created_at e updated_at para TIMESTAMP WITH TIME ZONE, alinhando com deleted_at (V6).
-- Valores existentes são interpretados como UTC (timezone da aplicação).
ALTER TABLE prds
    ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE USING created_at AT TIME ZONE 'UTC',
    ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE USING updated_at AT TIME ZONE 'UTC';

ALTER TABLE users
    ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE USING created_at AT TIME ZONE 'UTC';
